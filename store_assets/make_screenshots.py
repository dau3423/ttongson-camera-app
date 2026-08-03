#!/usr/bin/env python3
"""스토어 스크린샷 합성기 — 브랜드 그라데이션 배경 + 한글 문구 + 기기 프레임.

원본 앱 화면 캡처(PNG)를 store_assets/raw/ 에 넣고 SHOTS에 (파일, 문구)를 채운 뒤
실행하면 Play·App Store 규격으로 각각 출력한다.

  python3 store_assets/make_screenshots.py          # SHOTS 사용(원본 있으면)
  python3 store_assets/make_screenshots.py --demo    # 플레이스홀더로 스타일 미리보기

의존성: Pillow. 폰트: assets/fonts/Pretendard-*.otf
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "store_assets" / "raw"
OUT = ROOT / "store_assets" / "out"
FONT_BOLD = ROOT / "assets/fonts/Pretendard-Bold.otf"
FONT_SEMI = ROOT / "assets/fonts/Pretendard-SemiBold.otf"

# 브랜드 색(앱 아이콘/스플래시에서 샘플): 위 핑크 → 아래 페리윙클.
GRAD_TOP = (0xFC, 0x83, 0xC2)
GRAD_BOTTOM = (0x8A, 0xB7, 0xFD)
CAPTION_RGB = (0xFF, 0xFF, 0xFF)
BEZEL_RGB = (0x1B, 0x1C, 0x22)

# 출력 규격: (라벨, 폭, 높이)
TARGETS = [
    ("play", 1080, 1920),           # Google Play 폰 9:16
    ("appstore-6.9", 1320, 2868),   # iPhone 16 Pro Max 6.9"
    ("appstore-6.5", 1242, 2688),   # iPhone 6.5"
]

# (원본파일명 in store_assets/raw/, 홍보 문구) — 실제 캡처 받은 뒤 채운다.
SHOTS = [
    # ("camera_guide.png", "실시간 구도·수평 가이드로\n똥손도 잘 찍어요"),
    # ("result_mood.png",  "AI 무드 필터로\n감성 한 스푼"),
    # ("community.png",    "다른 사람 사진에서\n구도 팁을 배워요"),
]


def gradient(w, h):
    base = Image.new("RGB", (1, h))
    px = base.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(GRAD_TOP, GRAD_BOTTOM))
    return base.resize((w, h))


def rounded(img, radius):
    """이미지에 둥근 모서리 알파를 적용(4x 슈퍼샘플 AA)."""
    ss = 4
    m = Image.new("L", (img.width * ss, img.height * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, img.width * ss - 1, img.height * ss - 1], radius=radius * ss, fill=255
    )
    m = m.resize(img.size, Image.LANCZOS)
    out = img.convert("RGBA")
    out.putalpha(m)
    return out


def wrap(draw, text, font, max_w):
    lines = []
    for para in text.split("\n"):
        words, cur = para.split(" "), ""
        for wd in words:
            trial = (cur + " " + wd).strip()
            if draw.textlength(trial, font=font) <= max_w or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = wd
        lines.append(cur)
    return lines


def compose(shot_path, caption, w, h):
    canvas = gradient(w, h).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # 1) 상단 문구
    cap_font = ImageFont.truetype(str(FONT_BOLD), size=round(w * 0.062))
    lines = wrap(draw, caption, cap_font, max_w=w * 0.86)
    line_h = round(w * 0.062 * 1.28)
    y = round(h * 0.06)
    for ln in lines:
        tw = draw.textlength(ln, font=cap_font)
        x = (w - tw) / 2
        draw.text((x + 2, y + 2), ln, font=cap_font, fill=(0, 0, 0, 60))  # 그림자
        draw.text((x, y), ln, font=cap_font, fill=CAPTION_RGB)
        y += line_h
    caption_bottom = y + round(h * 0.02)

    # 2) 기기 프레임 + 스크린샷
    shot = Image.open(shot_path).convert("RGB")
    frame_w = round(w * 0.76)                      # 프레임 가로
    scale = frame_w / shot.width
    frame_h = round(shot.height * scale)
    avail_h = h - caption_bottom - round(h * 0.05)
    if frame_h > avail_h:                          # 세로가 넘치면 맞춰 축소
        frame_h = avail_h
        frame_w = round(shot.width * (frame_h / shot.height))
    shot = shot.resize((frame_w, frame_h), Image.LANCZOS)

    bezel = round(w * 0.018)
    corner = round(w * 0.055)
    dev_w, dev_h = frame_w + bezel * 2, frame_h + bezel * 2
    dx = (w - dev_w) // 2
    dy = caption_bottom + (avail_h - dev_h) // 2

    # 그림자
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([dx, dy + round(h * 0.012), dx + dev_w, dy + dev_h + round(h * 0.012)],
                         radius=corner + bezel, fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(w * 0.02)))
    canvas.alpha_composite(shadow)

    # 베젤(둥근 검정)
    dev = Image.new("RGBA", (dev_w, dev_h), (0, 0, 0, 0))
    ImageDraw.Draw(dev).rounded_rectangle([0, 0, dev_w - 1, dev_h - 1],
                                          radius=corner + bezel, fill=BEZEL_RGB + (255,))
    dev.alpha_composite(rounded(shot, corner), (bezel, bezel))
    canvas.alpha_composite(dev, (dx, dy))

    return canvas.convert("RGB")


def make_demo_shot():
    """스타일 미리보기용 가짜 세로 화면(다크 + 안내 텍스트)."""
    w, h = 1080, 2340
    im = Image.new("RGB", (w, h), (0x0B, 0x0C, 0x0E))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(str(FONT_SEMI), size=64)
    msg = "여기에 실제\n앱 화면 캡처가\n들어갑니다"
    yy = h // 2 - 140
    for ln in msg.split("\n"):
        tw = d.textlength(ln, font=f)
        d.text(((w - tw) / 2, yy), ln, font=f, fill=(0xF4, 0xF1, 0xEA))
        yy += 96
    # 상단 앰버 바(브랜드 힌트)
    d.rectangle([0, 0, w, 120], fill=(0xFF, 0xC1, 0x07))
    p = RAW / "_demo_screen.png"
    RAW.mkdir(parents=True, exist_ok=True)
    im.save(p)
    return p


def main():
    demo = "--demo" in sys.argv
    if demo:
        shot = make_demo_shot()
        jobs = [(shot, "실시간 구도·수평 가이드로\n똥손도 잘 찍어요", "01_demo")]
    else:
        if not SHOTS:
            print("SHOTS가 비어 있습니다. store_assets/raw/에 캡처를 넣고 SHOTS를 채우거나 --demo로 실행하세요.")
            return
        jobs = [(RAW / fn, cap, f"{i+1:02d}_{Path(fn).stem}") for i, (fn, cap) in enumerate(SHOTS)]

    for label, w, h in TARGETS:
        d = OUT / label
        d.mkdir(parents=True, exist_ok=True)
        for shot, cap, name in jobs:
            img = compose(shot, cap, w, h)
            out = d / f"{name}.png"
            img.save(out)
            print(f"  {out.relative_to(ROOT)}  ({w}x{h})")


if __name__ == "__main__":
    main()
