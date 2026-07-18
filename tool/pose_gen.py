#!/usr/bin/env python3
"""포즈 실루엣 에셋 생성 (OpenAI gpt-image-1).

앱 매니페스트(assets/poses/poses.json)는 항상 갱신하고,
--images 를 주면 각 포즈 PNG를 assets/poses/{id}.png 로 생성한다(OPENAI_API_KEY 필요).

사용법:
  python3 tool/pose_gen.py                 # poses.json만 갱신(키 불필요)
  OPENAI_API_KEY=sk-... python3 tool/pose_gen.py --images   # 이미지까지 생성

--images 는 Pillow가 필요하다(번들 용량을 위해 512x768로 축소): pip install pillow
"""
import os
import sys
import io
import json
import base64
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "tool", "pose_manifest.json")
OUT_DIR = os.path.join(ROOT, "assets", "poses")
APP_MANIFEST = os.path.join(OUT_DIR, "poses.json")

STYLE = (
    "Solid flat single-color fill (pure black), smooth clean continuous edges, "
    "front view, the entire figure(s) from head to feet fully inside the frame with "
    "even margin, simple generic human body shapes, no faces, no facial features, "
    "no hair detail, no clothing texture, no props, no text, no shadow, "
    "no background scenery. Flat vector-like design. Transparent background."
)


def load_manifest():
    with open(MANIFEST, encoding="utf-8") as f:
        return json.load(f)


def write_app_manifest(entries):
    os.makedirs(OUT_DIR, exist_ok=True)
    app = [
        {"id": e["id"], "category": e["category"], "label": e["label"],
         "asset": f"assets/poses/{e['id']}.png"}
        for e in entries
    ]
    with open(APP_MANIFEST, "w", encoding="utf-8") as f:
        json.dump(app, f, ensure_ascii=False, indent=2)
    print("wrote", APP_MANIFEST, f"({len(app)} poses)")


def gen_image(api_key, prompt_pose, out_path):
    prompt = f"A minimalist full-body silhouette of {prompt_pose}. {STYLE}"
    req = urllib.request.Request(
        "https://api.openai.com/v1/images/generations",
        data=json.dumps({
            "model": "gpt-image-1",
            "prompt": prompt,
            "size": "1024x1536",
            "background": "transparent",
            "n": 1,
        }).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
    )
    resp = json.load(urllib.request.urlopen(req))
    png = base64.b64decode(resp["data"][0]["b64_json"])
    # 번들 용량을 위해 512x768(2:3)로 축소. 투명(RGBA) 유지.
    from PIL import Image
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    img = img.resize((512, 768), Image.LANCZOS)
    img.save(out_path, "PNG")
    print("saved", out_path)


def main():
    entries = load_manifest()
    write_app_manifest(entries)
    if "--images" in sys.argv:
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            sys.exit("이미지 생성에는 OPENAI_API_KEY가 필요합니다.")
        for e in entries:
            gen_image(api_key, e["promptPose"], os.path.join(OUT_DIR, f"{e['id']}.png"))


if __name__ == "__main__":
    main()
