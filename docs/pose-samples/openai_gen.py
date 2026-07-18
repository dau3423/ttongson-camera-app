#!/usr/bin/env python3
"""포즈 실루엣 샘플 생성 테스트 (OpenAI gpt-image-1).

사용법:
  OPENAI_API_KEY=sk-... python3 docs/pose-samples/openai_gen.py "포즈 설명(영어)" 출력파일.png

예:
  OPENAI_API_KEY=sk-... python3 docs/pose-samples/openai_gen.py \
    "a confident full-body standing pose, one hand on hip, weight on one leg" standing.png

  OPENAI_API_KEY=sk-... python3 docs/pose-samples/openai_gen.py \
    "an upper-body selfie pose, one arm raised holding a phone, slight head tilt" selfie.png

비고: gpt-image-1은 배경 투명(PNG)을 지원. 이미지당 대략 $0.02~0.19(품질/크기별).
      일부 계정은 OpenAI 조직 인증이 필요할 수 있음.
"""
import os
import sys
import json
import base64
import urllib.request

api_key = os.environ.get("OPENAI_API_KEY")
if not api_key:
    sys.exit("환경변수 OPENAI_API_KEY 를 설정하세요.")

pose = sys.argv[1] if len(sys.argv) > 1 else (
    "a confident full-body standing pose, one hand on hip, weight on one leg"
)
out = sys.argv[2] if len(sys.argv) > 2 else "pose_sample.png"

# 오버레이용 실루엣을 위한 고정 스타일 프롬프트. {pose}만 바뀐다.
prompt = (
    f"A minimalist full-body silhouette of a single person in {pose}. "
    "Solid flat single-color fill (pure black), smooth clean continuous edges, "
    "front view, the entire figure from head to feet fully inside the frame with "
    "even margin around it, simple generic human body shape, no face, no facial "
    "features, no hair detail, no clothing texture, no props, no text, no shadow, "
    "no background scenery. Flat vector-like design. Transparent background."
)

req = urllib.request.Request(
    "https://api.openai.com/v1/images/generations",
    data=json.dumps({
        "model": "gpt-image-1",
        "prompt": prompt,
        "size": "1024x1536",   # 세로 인물 비율
        "background": "transparent",
        "n": 1,
    }).encode(),
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    },
)

try:
    resp = json.load(urllib.request.urlopen(req))
except urllib.error.HTTPError as e:
    sys.exit(f"OpenAI 오류 {e.code}: {e.read().decode()}")

b64 = resp["data"][0]["b64_json"]
with open(out, "wb") as f:
    f.write(base64.b64decode(b64))
print("저장됨:", out)
