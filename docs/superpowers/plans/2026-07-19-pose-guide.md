# 맞춤 포즈 추천 (실루엣 오버레이 + AI 추천) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카테고리별 포즈 실루엣을 카메라 프리뷰 위에 반투명 오버레이하고, 원하면 AI(OpenAI GPT-5 mini)가 현재 장면에 맞는 포즈를 추천해 자동으로 얹어 준다.

**Architecture:** 포즈 데이터 파싱은 순수 Dart(`lib/poses/pose.dart`)로 TDD하고, 에셋 로더·오버레이 렌더·서버 호출·피커 UI를 분리한다. 실루엣 PNG는 OpenAI로 오프라인 생성해 `assets/poses/`에 평면 구조로 번들한다(`poses.json` 매니페스트). AI 추천 서버 `suggestPose`는 기존 통일 헬퍼 `functions/src/openai.ts`의 `visionJson`(GPT-5 mini, 구조화 출력)을 재사용하며, 후보 pose id 집합을 enum으로 강제해 항상 유효한 id를 돌려받는다.

**Tech Stack:** Flutter/Dart, `image` ^4.9.1(다운사이즈 재사용), `cloud_functions`, `path_provider`, `shared_preferences`; Firebase Functions(TypeScript, nodejs22) + `openai` SDK(`gpt-5-mini`), vitest; 오프라인 생성은 Python + OpenAI Images(`gpt-image-1`).

## Global Constraints

- 카테고리 4종·키: `selfie`(셀카)·`fullbody`(전신)·`couple`(커플)·`friends`(우정). MVP 카테고리당 8개 ≈ **32 포즈**.
- 에셋은 **평면 구조** `assets/poses/{id}.png`(하위 디렉토리 없음), 매니페스트 `assets/poses/poses.json`.
- 오버레이는 **앰버 틴트(AppColors.accent) + 불투명도 0.35**, `BoxFit.contain`, **저장 사진에 미포함**(Flutter 위젯 레이어).
- AI 추천은 **OpenAI GPT-5 mini**를 `functions/src/openai.ts`의 `visionJson`으로 호출. **App Check·레이트리밋·auth·consent** 재사용. 후보는 **전체 카탈로그(32개)** 전송, `poseId`는 candidate id enum으로 강제.
- 순수 로직 파일(`lib/poses/pose.dart`, `functions/src/pose.ts`)은 Flutter/plugin/네트워크 import 금지.
- 정적 분석은 **`dart analyze lib test`**. 완료 게이트 **`tool/verify.sh`**. 서버 게이트 `cd functions && npm run build && npx vitest run`.
- 커밋은 Conventional Commits. Flutter SDK: `/Users/soonbok/flutter/bin`(PATH 추가).

---

### Task 1: 포즈 모델 + 매니페스트 파싱 (순수)

**Files:**
- Create: `lib/poses/pose.dart`
- Test: `test/poses/pose_test.dart`

**Interfaces:**
- Consumes: 없음.
- Produces:
  - `enum PoseCategory { selfie, fullbody, couple, friends }`
  - `extension PoseCategoryInfo on PoseCategory { String get label; String get wire; }`
  - `PoseCategory? poseCategoryFromWire(String wire)`
  - `class Pose { final String id; final PoseCategory category; final String label; final String asset; const Pose({required ...}); }`
  - `List<Pose> parsePoses(String jsonString)` — 방어적, 이상 항목은 건너뜀.
  - `Map<PoseCategory, List<Pose>> groupByCategory(List<Pose> poses)`

- [ ] **Step 1: 실패 테스트 작성**

`test/poses/pose_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/poses/pose.dart';

void main() {
  test('4개 카테고리, 라벨·wire 비어있지 않음', () {
    expect(PoseCategory.values.length, 4);
    for (final c in PoseCategory.values) {
      expect(c.label.isNotEmpty, isTrue);
      expect(c.wire.isNotEmpty, isTrue);
    }
  });

  test('poseCategoryFromWire: 유효값 매핑, 이상값 null', () {
    expect(poseCategoryFromWire('selfie'), PoseCategory.selfie);
    expect(poseCategoryFromWire('friends'), PoseCategory.friends);
    expect(poseCategoryFromWire('bogus'), isNull);
  });

  test('parsePoses: 유효 항목을 Pose로', () {
    const json =
        '[{"id":"selfie_01","category":"selfie","label":"턱 괴기","asset":"assets/poses/selfie_01.png"}]';
    final poses = parsePoses(json);
    expect(poses.length, 1);
    expect(poses.first.id, 'selfie_01');
    expect(poses.first.category, PoseCategory.selfie);
    expect(poses.first.asset, 'assets/poses/selfie_01.png');
  });

  test('parsePoses: 이상 항목(카테고리 불명/필드 누락)은 건너뜀', () {
    const json =
        '[{"id":"x","category":"nope","label":"a","asset":"p.png"},'
        '{"id":"y","category":"couple"},'
        '{"id":"ok","category":"couple","label":"어깨동무","asset":"assets/poses/couple_01.png"}]';
    final poses = parsePoses(json);
    expect(poses.length, 1);
    expect(poses.first.id, 'ok');
  });

  test('parsePoses: JSON이 아니면 빈 리스트', () {
    expect(parsePoses('not json'), isEmpty);
  });

  test('groupByCategory: 카테고리별로 묶음', () {
    final poses = [
      const Pose(id: 's1', category: PoseCategory.selfie, label: 'a', asset: 'a.png'),
      const Pose(id: 'c1', category: PoseCategory.couple, label: 'b', asset: 'b.png'),
      const Pose(id: 's2', category: PoseCategory.selfie, label: 'c', asset: 'c.png'),
    ];
    final grouped = groupByCategory(poses);
    expect(grouped[PoseCategory.selfie]!.length, 2);
    expect(grouped[PoseCategory.couple]!.length, 1);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/poses/pose_test.dart`
Expected: FAIL (`pose.dart` 없음).

- [ ] **Step 3: 최소 구현**

`lib/poses/pose.dart` (순수 Dart — Flutter/plugin import 금지):

```dart
// lib/poses/pose.dart
// 순수 Dart — 포즈 카탈로그 모델과 poses.json 파싱.
import 'dart:convert';

enum PoseCategory { selfie, fullbody, couple, friends }

extension PoseCategoryInfo on PoseCategory {
  String get label => switch (this) {
    PoseCategory.selfie => '셀카',
    PoseCategory.fullbody => '전신',
    PoseCategory.couple => '커플',
    PoseCategory.friends => '우정',
  };
  String get wire => name; // 'selfie','fullbody','couple','friends'
}

PoseCategory? poseCategoryFromWire(String wire) {
  for (final c in PoseCategory.values) {
    if (c.wire == wire) return c;
  }
  return null;
}

class Pose {
  final String id;
  final PoseCategory category;
  final String label;
  final String asset;
  const Pose({
    required this.id,
    required this.category,
    required this.label,
    required this.asset,
  });
}

/// poses.json(배열)을 Pose 리스트로. 이상 항목은 건너뛴다(비차단).
List<Pose> parsePoses(String jsonString) {
  final dynamic raw;
  try {
    raw = jsonDecode(jsonString);
  } catch (_) {
    return const [];
  }
  if (raw is! List) return const [];
  final out = <Pose>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final id = item['id'];
    final cat = item['category'];
    final label = item['label'];
    final asset = item['asset'];
    if (id is! String || cat is! String || label is! String || asset is! String) {
      continue;
    }
    final category = poseCategoryFromWire(cat);
    if (category == null) continue;
    out.add(Pose(id: id, category: category, label: label, asset: asset));
  }
  return out;
}

Map<PoseCategory, List<Pose>> groupByCategory(List<Pose> poses) {
  final map = <PoseCategory, List<Pose>>{for (final c in PoseCategory.values) c: []};
  for (final p in poses) {
    map[p.category]!.add(p);
  }
  return map;
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/poses/pose_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/poses/pose.dart test/poses/pose_test.dart
git commit -m "feat: 포즈 카탈로그 모델·poses.json 파싱(순수 TDD)"
```

---

### Task 2: 오프라인 생성 도구 + 매니페스트 + 에셋 등록

**Files:**
- Create: `tool/pose_manifest.json`
- Create: `tool/pose_gen.py`
- Create: `assets/poses/poses.json`
- Modify: `pubspec.yaml` (assets 등록)

**Interfaces:**
- Consumes: 없음(개발용 스크립트).
- Produces: `assets/poses/poses.json`(앱이 로드), `assets/poses/{id}.png`(사용자가 생성).

> 이미지 생성은 사용자의 OpenAI 키가 필요하다. 이 태스크는 **매니페스트·스크립트·앱용 poses.json·pubspec 등록**까지 만들고, 이미지 없이도 앱이 빌드/실행되게 한다(오버레이는 로드 실패 시 스킵 — Task 6).

- [ ] **Step 1: 포즈 매니페스트 작성 (32개)**

`tool/pose_manifest.json`:

```json
[
  {"id":"selfie_01","category":"selfie","label":"턱 괴기","promptPose":"an upper-body selfie pose, one hand resting under the chin, slight head tilt"},
  {"id":"selfie_02","category":"selfie","label":"폰 들기","promptPose":"an upper-body selfie pose, one arm raised holding a phone toward the camera"},
  {"id":"selfie_03","category":"selfie","label":"브이","promptPose":"an upper-body selfie pose making a V sign near the cheek"},
  {"id":"selfie_04","category":"selfie","label":"머리 넘기기","promptPose":"an upper-body selfie pose, one hand running through the hair"},
  {"id":"selfie_05","category":"selfie","label":"손 하트","promptPose":"an upper-body selfie pose making a small finger heart in front of the chest"},
  {"id":"selfie_06","category":"selfie","label":"볼 감싸기","promptPose":"an upper-body selfie pose, both hands gently framing the cheeks"},
  {"id":"selfie_07","category":"selfie","label":"어깨 너머","promptPose":"an upper-body pose looking back over one shoulder toward the camera"},
  {"id":"selfie_08","category":"selfie","label":"팔짱","promptPose":"an upper-body pose with arms crossed, confident stance"},
  {"id":"fullbody_01","category":"fullbody","label":"허리 손","promptPose":"a confident full-body standing pose, one hand on the hip, weight on one leg"},
  {"id":"fullbody_02","category":"fullbody","label":"걷기","promptPose":"a full-body candid walking pose, mid-stride, arms relaxed"},
  {"id":"fullbody_03","category":"fullbody","label":"기대기","promptPose":"a full-body pose leaning sideways against a wall, ankles crossed"},
  {"id":"fullbody_04","category":"fullbody","label":"뒤돌아보기","promptPose":"a full-body pose from behind, head turned back over the shoulder"},
  {"id":"fullbody_05","category":"fullbody","label":"양손 주머니","promptPose":"a full-body standing pose with both hands in pockets, relaxed"},
  {"id":"fullbody_06","category":"fullbody","label":"점프","promptPose":"a full-body dynamic jumping pose, both feet off the ground"},
  {"id":"fullbody_07","category":"fullbody","label":"쪼그려 앉기","promptPose":"a full-body crouching pose, squatting with arms resting on knees"},
  {"id":"fullbody_08","category":"fullbody","label":"한 발 앞","promptPose":"a full-body standing pose with one foot forward, hands clasped in front"},
  {"id":"couple_01","category":"couple","label":"어깨동무","promptPose":"two people standing side by side, one arm around the other's shoulder"},
  {"id":"couple_02","category":"couple","label":"마주보기","promptPose":"two people facing each other, holding both hands"},
  {"id":"couple_03","category":"couple","label":"백허그","promptPose":"two people, one gently hugging the other from behind"},
  {"id":"couple_04","category":"couple","label":"손잡고 걷기","promptPose":"two people walking side by side holding hands"},
  {"id":"couple_05","category":"couple","label":"이마 맞대기","promptPose":"two people facing each other, foreheads gently touching"},
  {"id":"couple_06","category":"couple","label":"업기","promptPose":"two people, one giving the other a piggyback ride"},
  {"id":"couple_07","category":"couple","label":"나란히 앉기","promptPose":"two people sitting side by side, shoulders leaning together"},
  {"id":"couple_08","category":"couple","label":"손 하트","promptPose":"two people together making a big heart shape with their arms"},
  {"id":"friends_01","category":"friends","label":"나란히","promptPose":"three friends standing side by side, arms around each other's shoulders"},
  {"id":"friends_02","category":"friends","label":"점프","promptPose":"three friends jumping together, arms up in the air"},
  {"id":"friends_03","category":"friends","label":"하이파이브","promptPose":"two friends giving each other a high five"},
  {"id":"friends_04","category":"friends","label":"어깨 기대기","promptPose":"three friends leaning shoulders together in a row"},
  {"id":"friends_05","category":"friends","label":"등 맞대기","promptPose":"two friends standing back to back with arms crossed"},
  {"id":"friends_06","category":"friends","label":"둥글게","promptPose":"a group of friends viewed from above, heads together in a circle"},
  {"id":"friends_07","category":"friends","label":"걷기","promptPose":"three friends walking together in a row toward the camera"},
  {"id":"friends_08","category":"friends","label":"단체 브이","promptPose":"a group of friends standing together, each making a V sign"}
]
```

- [ ] **Step 2: 생성 스크립트 작성**

`tool/pose_gen.py`:

```python
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
```

- [ ] **Step 3: 앱 매니페스트 생성 (이미지 없이)**

Run: `python3 tool/pose_gen.py`
Expected: `wrote .../assets/poses/poses.json (32 poses)`. `assets/poses/poses.json`이 32개 항목으로 생성됨.

- [ ] **Step 4: pubspec에 에셋 등록**

`pubspec.yaml`의 `flutter:` 섹션 `uses-material-design: true` 아래에 assets를 추가한다. 다음 블록을 찾아:

```yaml
flutter:

  # The following line ensures that the Material Icons font is
  # included with your application, so that you can use the icons in
  # the material Icons class.
  uses-material-design: true
```

바로 아래에 삽입:

```yaml

  # 포즈 실루엣 에셋(평면 구조). poses.json + 각 포즈 PNG.
  assets:
    - assets/poses/
```

- [ ] **Step 5: 등록 검증**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter pub get && dart analyze lib test`
Expected: pub get 성공, `No issues found!`(에셋 디렉토리 `assets/poses/`가 poses.json으로 비어있지 않아 오류 없음).

- [ ] **Step 6: 커밋**

```bash
git add tool/pose_manifest.json tool/pose_gen.py assets/poses/poses.json pubspec.yaml
git commit -m "feat: 포즈 오프라인 생성 도구·매니페스트·에셋 등록(이미지는 사용자 생성)"
```

---

### Task 3: 서버 포즈 추천 순수 로직 (pose.ts)

**Files:**
- Create: `functions/src/pose.ts`
- Create: `functions/test/pose.test.ts`

**Interfaces:**
- Consumes: 없음.
- Produces:
  - `type PoseCandidate = { id: string; label: string; category: string };`
  - `parseCandidates(raw: unknown): PoseCandidate[]` — 배열·필드 검증, 비거나 이상하면 throw.
  - `buildPoseSchema(candidateIds: string[]): { [key: string]: unknown }` — `{poseId: enum, reason}` strict 스키마.
  - `buildPoseSystem(): string`
  - `buildPoseUser(candidates: PoseCandidate[]): string`
  - `parsePoseResult(text: string, validIds: string[]): { poseId: string; reason: string }` — JSON 파싱, poseId가 validIds에 없으면 throw.

- [ ] **Step 1: 실패 테스트 작성**

`functions/test/pose.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import {
  parseCandidates, buildPoseSchema, parsePoseResult, buildPoseUser,
} from "../src/pose.js";

describe("parseCandidates", () => {
  it("유효 후보 배열을 파싱", () => {
    const c = parseCandidates([
      { id: "selfie_01", label: "턱 괴기", category: "selfie" },
    ]);
    expect(c).toHaveLength(1);
    expect(c[0].id).toBe("selfie_01");
  });
  it("빈 배열/비배열은 throw", () => {
    expect(() => parseCandidates([])).toThrow();
    expect(() => parseCandidates("x")).toThrow();
  });
  it("필드 누락 항목이 있으면 throw", () => {
    expect(() => parseCandidates([{ id: "a", label: "b" }])).toThrow();
  });
});

describe("buildPoseSchema", () => {
  it("poseId를 후보 id enum으로 제약", () => {
    const s = buildPoseSchema(["a", "b"]) as any;
    expect(s.properties.poseId.enum).toEqual(["a", "b"]);
    expect(s.required).toEqual(["poseId", "reason"]);
    expect(s.additionalProperties).toBe(false);
  });
});

describe("buildPoseUser", () => {
  it("후보 라벨과 카테고리를 프롬프트에 포함", () => {
    const t = buildPoseUser([{ id: "couple_01", label: "어깨동무", category: "couple" }]);
    expect(t).toContain("couple_01");
    expect(t).toContain("어깨동무");
  });
});

describe("parsePoseResult", () => {
  it("유효 poseId를 파싱", () => {
    const r = parsePoseResult(
      JSON.stringify({ poseId: "a", reason: "두 명이라 커플 포즈" }),
      ["a", "b"],
    );
    expect(r.poseId).toBe("a");
    expect(r.reason).toContain("커플");
  });
  it("validIds에 없는 poseId면 throw", () => {
    expect(() =>
      parsePoseResult(JSON.stringify({ poseId: "z", reason: "r" }), ["a"]),
    ).toThrow();
  });
  it("JSON이 아니면 throw", () => {
    expect(() => parsePoseResult("no", ["a"])).toThrow();
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd functions && npx vitest run test/pose.test.ts`
Expected: FAIL (`pose.js` 없음).

- [ ] **Step 3: 구현**

`functions/src/pose.ts`:

```ts
export type PoseCandidate = { id: string; label: string; category: string };

export function parseCandidates(raw: unknown): PoseCandidate[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new Error("candidates가 필요합니다");
  }
  return raw.map((c) => {
    const o = c as Record<string, unknown>;
    if (
      typeof o.id !== "string" ||
      typeof o.label !== "string" ||
      typeof o.category !== "string"
    ) {
      throw new Error("candidate 형식 오류");
    }
    return { id: o.id, label: o.label, category: o.category };
  });
}

export function buildPoseSchema(candidateIds: string[]): { [key: string]: unknown } {
  return {
    type: "object",
    properties: {
      poseId: { type: "string", enum: candidateIds },
      reason: { type: "string" },
    },
    required: ["poseId", "reason"],
    additionalProperties: false,
  };
}

export function buildPoseSystem(): string {
  return (
    "당신은 사진 포즈를 추천하는 코치입니다. 반드시 한국어로 답합니다. " +
    "입력 사진 속 인원수와 구도를 보고, 후보 목록 중 이 장면에 가장 어울리는 포즈 하나를 고릅니다. " +
    "예: 두 명이면 커플, 여러 명이면 우정, 상반신 위주면 셀카, 전신이 보이면 전신 포즈. " +
    "poseId는 반드시 후보 목록의 id 중 하나여야 하고, reason은 왜 그 포즈가 어울리는지 한 문장입니다."
  );
}

export function buildPoseUser(candidates: PoseCandidate[]): string {
  const list = candidates
    .map((c) => `- ${c.id} (${c.category}): ${c.label}`)
    .join("\n");
  return `이 사진에 어울리는 포즈를 아래 후보 중에서 하나 골라 주세요.\n${list}`;
}

export function parsePoseResult(
  text: string,
  validIds: string[],
): { poseId: string; reason: string } {
  const raw = JSON.parse(text);
  if (raw === null || typeof raw !== "object") {
    throw new Error("포즈 결과 JSON 형식 오류");
  }
  const poseId = (raw as Record<string, unknown>).poseId;
  const reason = (raw as Record<string, unknown>).reason;
  if (typeof poseId !== "string" || !validIds.includes(poseId)) {
    throw new Error("poseId가 후보에 없습니다");
  }
  return { poseId, reason: typeof reason === "string" ? reason : "" };
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd functions && npx vitest run test/pose.test.ts`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add functions/src/pose.ts functions/test/pose.test.ts
git commit -m "feat: 서버 포즈 추천 순수 로직(후보 검증·enum 스키마·결과 파싱)"
```

---

### Task 4: 서버 콜러블 `suggestPose` (OpenAI)

**Files:**
- Create: `functions/src/suggest_pose.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Consumes: `visionJson`, `OPENAI_MODEL` 필요 없음(헬퍼가 사용). `pose.ts`의 `parseCandidates`/`buildPoseSchema`/`buildPoseSystem`/`buildPoseUser`/`parsePoseResult`. 기존 `ratelimit.ts`·`auth_guard.ts`.
- Produces: `export const suggestPose`(onCall). 입력 `{imageBase64, mediaType, deviceId, candidates}`, 출력 `{poseId, reason}`.

- [ ] **Step 1: `suggest_pose.ts` 구현 (`enhance.ts` 패턴 미러)**

`functions/src/suggest_pose.ts`:

```ts
// functions/src/suggest_pose.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { visionJson } from "./openai.js";
import { requireAuthUid } from "./auth_guard.js";
import { windowStart, overLimit } from "./ratelimit.js";
import {
  parseCandidates, buildPoseSchema, buildPoseSystem, buildPoseUser, parsePoseResult,
} from "./pose.js";

if (getApps().length === 0) initializeApp();

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

const MAX_IMAGE_BYTES = 4 * 1024 * 1024;
const RATE_MAX = 30;
const RATE_WINDOW_MS = 60_000;

export const suggestPose = onCall(
  {
    region: "asia-northeast3",
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (request) => {
    requireAuthUid(request.auth);
    const data = request.data as {
      imageBase64?: string; mediaType?: string; deviceId?: string; candidates?: unknown;
    };

    if (typeof data.imageBase64 !== "string" || data.imageBase64.length === 0) {
      throw new HttpsError("invalid-argument", "imageBase64가 필요합니다");
    }
    if (data.imageBase64.length > MAX_IMAGE_BYTES) {
      throw new HttpsError("invalid-argument", "이미지가 너무 큽니다");
    }
    if (data.mediaType !== "image/jpeg") {
      throw new HttpsError("invalid-argument", "mediaType은 image/jpeg만 지원합니다");
    }
    const deviceId = data.deviceId;
    if (typeof deviceId !== "string" || deviceId.length === 0 || deviceId.length > 64) {
      throw new HttpsError("invalid-argument", "deviceId가 필요합니다");
    }

    let candidates;
    try {
      candidates = parseCandidates(data.candidates);
    } catch {
      throw new HttpsError("invalid-argument", "candidates가 필요합니다");
    }

    const now = Date.now();
    const win = windowStart(now, RATE_WINDOW_MS);
    const ref = getFirestore().collection("rate_limits").doc(`${deviceId}_${win}`);
    const count = await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = (snap.exists ? (snap.data()?.count as number) : 0) ?? 0;
      tx.set(ref, { count: current + 1, expiresAt: win + RATE_WINDOW_MS }, { merge: true });
      return current + 1;
    });
    if (overLimit(count, RATE_MAX)) {
      throw new HttpsError("resource-exhausted", "요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요.");
    }

    try {
      const ids = candidates.map((c) => c.id);
      const text = await visionJson({
        apiKey: OPENAI_API_KEY.value(),
        system: buildPoseSystem(),
        userText: buildPoseUser(candidates),
        imageBase64: data.imageBase64,
        schemaName: "pose_suggestion",
        schema: buildPoseSchema(ids),
      });
      return parsePoseResult(text, ids);
    } catch (err) {
      console.error("suggestPose failed", err);
      throw new HttpsError("internal", "포즈 추천 생성에 실패했습니다");
    }
  },
);
```

- [ ] **Step 2: export 추가**

`functions/src/index.ts` 마지막에 추가:

```ts
export { suggestPose } from "./suggest_pose.js";
```

- [ ] **Step 3: 빌드·전체 서버 테스트**

Run: `cd functions && npm run build && npx vitest run`
Expected: 타입 오류 없이 빌드, 모든 테스트 PASS.

- [ ] **Step 4: 커밋**

```bash
git add functions/src/suggest_pose.ts functions/src/index.ts
git commit -m "feat: 서버 suggestPose 콜러블 — OpenAI 포즈 추천(구조화 출력)"
```

---

### Task 5: 클라이언트 포즈 어드바이저 (호출 + 폴백)

**Files:**
- Create: `lib/poses/pose_advisor.dart`
- Test: `test/poses/pose_advisor_test.dart`

**Interfaces:**
- Consumes: `Pose`(Task 1), 기존 `lib/cloud/advice_image.dart`(`encodeDownsizedJpeg`, `fileToBase64`).
- Produces:
  - `class PoseAdviceException implements Exception { final String message; ... }`
  - `class PoseSuggestion { final String poseId; final String reason; const PoseSuggestion({...}); }`
  - `PoseSuggestion poseSuggestionFromResult(Map<String, dynamic> data)` — 방어적.
  - `class PoseAdvisor { PoseAdvisor({FirebaseFunctions? functions}); Future<PoseSuggestion> suggest({required String jpegPath, required List<Pose> candidates, required String deviceId}); }`

- [ ] **Step 1: 실패 테스트 작성**

`test/poses/pose_advisor_test.dart` (순수 파싱만; 네트워크는 기기 검증):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/poses/pose_advisor.dart';

void main() {
  test('서버 결과 맵을 PoseSuggestion으로 파싱', () {
    final s = poseSuggestionFromResult({'poseId': 'couple_01', 'reason': '두 명이라 커플'});
    expect(s.poseId, 'couple_01');
    expect(s.reason, '두 명이라 커플');
  });

  test('reason 누락 시 빈 문자열, poseId 누락 시 빈 문자열', () {
    final s = poseSuggestionFromResult({'poseId': 'x'});
    expect(s.poseId, 'x');
    expect(s.reason, '');
    final s2 = poseSuggestionFromResult({});
    expect(s2.poseId, '');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/poses/pose_advisor_test.dart`
Expected: FAIL (`pose_advisor.dart` 없음).

- [ ] **Step 3: 구현 (`lib/cloud/mood_advisor.dart` 패턴 미러)**

`lib/poses/pose_advisor.dart`:

```dart
// lib/poses/pose_advisor.dart
import 'package:cloud_functions/cloud_functions.dart';
import '../cloud/advice_image.dart';
import 'pose.dart';

class PoseAdviceException implements Exception {
  final String message;
  PoseAdviceException(this.message);
  @override
  String toString() => 'PoseAdviceException: $message';
}

class PoseSuggestion {
  final String poseId;
  final String reason;
  const PoseSuggestion({required this.poseId, required this.reason});
}

/// 서버 결과 맵 → PoseSuggestion (방어적).
PoseSuggestion poseSuggestionFromResult(Map<String, dynamic> data) {
  final id = data['poseId'];
  final reason = data['reason'];
  return PoseSuggestion(
    poseId: id is String ? id : '',
    reason: reason is String ? reason : '',
  );
}

/// 현재 프레임을 서버로 보내 어울리는 포즈 id를 받는다. 판단 없음(전송·파싱만).
class PoseAdvisor {
  final FirebaseFunctions _functions;
  PoseAdvisor({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<PoseSuggestion> suggest({
    required String jpegPath,
    required List<Pose> candidates,
    required String deviceId,
  }) async {
    try {
      final downsized = await encodeDownsizedJpeg(jpegPath);
      final base64 = await fileToBase64(downsized);
      final callable = _functions.httpsCallable(
        'suggestPose',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64,
        'mediaType': 'image/jpeg',
        'deviceId': deviceId,
        'candidates': [
          for (final p in candidates)
            {'id': p.id, 'label': p.label, 'category': p.category.wire},
        ],
      });
      return poseSuggestionFromResult(Map<String, dynamic>.from(result.data));
    } on FirebaseFunctionsException catch (e) {
      throw PoseAdviceException(e.message ?? '포즈 추천 실패');
    } catch (e) {
      throw PoseAdviceException('포즈 추천 실패: $e');
    }
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/poses/pose_advisor_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/poses/pose_advisor.dart test/poses/pose_advisor_test.dart
git commit -m "feat: 클라이언트 포즈 어드바이저(suggestPose 호출·파싱)"
```

---

### Task 6: 카탈로그 로더 + 오버레이 + 피커 + 카메라 연결 (기기 검증)

**Files:**
- Create: `lib/poses/pose_catalog.dart`
- Create: `lib/overlay/pose_overlay.dart`
- Create: `lib/poses/pose_picker.dart`
- Modify: `lib/screens/camera_screen.dart`

**Interfaces:**
- Consumes: `Pose`/`PoseCategory`/`parsePoses`/`groupByCategory`(Task 1), `PoseAdvisor`/`PoseSuggestion`(Task 5), 기존 `AppColors`, `DeviceId`, `AdviceConsentStore`, `showSignInSheet`, `AuthService`, `CameraService.captureFrameForAdvice`.
- Produces:
  - `class PoseCatalog { static Future<List<Pose>> load(); }`
  - `class PoseOverlay extends StatelessWidget { final String asset; const PoseOverlay({required this.asset}); }`
  - `Future<void> showPosePicker(BuildContext context, {required List<Pose> poses, required void Function(Pose?) onSelect, required VoidCallback onAiRecommend});`

> UI/플러그인 통합이라 단위 테스트 대신 **기기 수동 검증**한다.

- [ ] **Step 1: 카탈로그 로더**

`lib/poses/pose_catalog.dart`:

```dart
import 'package:flutter/services.dart' show rootBundle;
import 'pose.dart';

/// assets/poses/poses.json 을 로드해 Pose 리스트로. 실패 시 빈 리스트.
class PoseCatalog {
  static Future<List<Pose>> load() async {
    try {
      final json = await rootBundle.loadString('assets/poses/poses.json');
      return parsePoses(json);
    } catch (_) {
      return const [];
    }
  }
}
```

- [ ] **Step 2: 오버레이 위젯**

`lib/overlay/pose_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 선택 포즈 실루엣을 프리뷰 위에 앰버 틴트·반투명으로 얹는다(가이드 전용, 터치 통과).
class PoseOverlay extends StatelessWidget {
  final String asset;
  const PoseOverlay({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.35,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            color: AppColors.accent,
            colorBlendMode: BlendMode.srcIn,
            // 에셋이 아직 없으면(사용자 미생성) 조용히 숨김.
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 피커 (카테고리 탭 + 썸네일)**

`lib/poses/pose_picker.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'pose.dart';

/// 하단 시트: 카테고리 탭 + 가로 썸네일. 포즈 탭 시 onSelect(pose)+닫힘,
/// '끄기' 시 onSelect(null)+닫힘, 'AI 추천' 시 onAiRecommend()+닫힘.
Future<void> showPosePicker(
  BuildContext context, {
  required List<Pose> poses,
  required void Function(Pose?) onSelect,
  required VoidCallback onAiRecommend,
}) {
  final grouped = groupByCategory(poses);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceCard,
    builder: (ctx) => DefaultTabController(
      length: PoseCategory.values.length,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onSelect(null);
                  },
                  icon: const Icon(Icons.visibility_off, size: 18),
                  label: const Text('끄기'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onAiRecommend();
                  },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('AI 추천'),
                ),
              ],
            ),
            const TabBar(
              isScrollable: true,
              tabs: [Tab(text: '셀카'), Tab(text: '전신'), Tab(text: '커플'), Tab(text: '우정')],
            ),
            SizedBox(
              height: 140,
              child: TabBarView(
                children: [
                  for (final c in PoseCategory.values)
                    _PoseRow(
                      poses: grouped[c] ?? const [],
                      onTap: (p) {
                        Navigator.pop(ctx);
                        onSelect(p);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PoseRow extends StatelessWidget {
  final List<Pose> poses;
  final void Function(Pose) onTap;
  const _PoseRow({required this.poses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (poses.isEmpty) {
      return const Center(child: Text('포즈 준비 중'));
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      children: [
        for (final p in poses)
          GestureDetector(
            onTap: () => onTap(p),
            child: Container(
              width: 84,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: Image.asset(
                        p.asset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.accessibility_new, color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(p.label, style: const TextStyle(fontSize: 12), maxLines: 1),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: 카메라 화면 연결**

`lib/screens/camera_screen.dart` 를 수정한다.

(a) 파일 상단 import에 추가:

```dart
import '../poses/pose.dart';
import '../poses/pose_catalog.dart';
import '../poses/pose_advisor.dart';
import '../overlay/pose_overlay.dart';
import '../poses/pose_picker.dart';
```

(b) State 클래스 필드에 추가(기존 `_advice`/`_deviceId`/`_consent` 근처):

```dart
  List<Pose> _poses = const [];
  String? _poseAsset; // 선택된 포즈 실루엣 asset (null=꺼짐)
  final _poseAdvisor = PoseAdvisor();
```

(c) `initState()` 안에서 카탈로그를 로드(기존 initState 마지막에 추가):

```dart
    PoseCatalog.load().then((p) {
      if (mounted) setState(() => _poses = p);
    });
```

(d) 포즈 열기/추천 메서드 추가(클래스 내 아무 곳, 예: `_requestAdvice` 아래):

```dart
  void _openPosePicker() {
    if (_poses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포즈를 불러오지 못했어요')),
      );
      return;
    }
    showPosePicker(
      context,
      poses: _poses,
      onSelect: (p) => setState(() => _poseAsset = p?.asset),
      onAiRecommend: _recommendPose,
    );
  }

  Future<void> _recommendPose() async {
    if (!_auth.isSignedIn) {
      final ok = await showSignInSheet(context, _auth);
      if (!ok) return;
    }
    if (!await _consent.hasConsented()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI 추천 안내'),
          content: const Text('추천 시 현재 화면 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('동의')),
          ],
        ),
      );
      if (ok != true) return;
      await _consent.setConsented();
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final deviceId = await _deviceId.get();
      final framePath = await _camera.captureFrameForAdvice();
      final suggestion = await _poseAdvisor.suggest(
        jpegPath: framePath,
        candidates: _poses,
        deviceId: deviceId,
      );
      final match = _poses.where((p) => p.id == suggestion.poseId);
      if (match.isNotEmpty && mounted) {
        setState(() => _poseAsset = match.first.asset);
        if (suggestion.reason.isNotEmpty) {
          messenger.showSnackBar(SnackBar(content: Text(suggestion.reason)));
        }
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('추천을 못 받았어요. 다시 시도해 주세요.')));
    } finally {
      if (mounted) _camera.startStream(_onFrame);
    }
  }
```

> 참고: `_auth`·`_consent`·`_deviceId`·`_camera`·`_onFrame`·`showSignInSheet`는 `_requestAdvice`가 이미 쓰는 기존 필드/함수다. `captureFrameForAdvice()`는 스트림을 멈추므로 `finally`에서 `startStream`으로 재개한다.

(e) 하단 좌측 클러스터에 '포즈' 아이콘 추가. 갤러리/배경흐림 `Row`의 children에서 배경흐림 토글 다음(닫는 `],` 앞)에 삽입:

```dart
                                _bottomIcon(
                                  Icons.accessibility_new,
                                  _openPosePicker,
                                  box: 40,
                                  iconSize: 26,
                                  dim: _poseAsset == null,
                                ),
```

(f) 오버레이 Stack에 포즈 오버레이 추가. `if (_advice != null) AdviceOverlay(...)` 바로 위(또는 아래)에 삽입:

```dart
            if (_poseAsset != null) PoseOverlay(asset: _poseAsset!),
```

- [ ] **Step 5: 정적 분석**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && dart analyze lib test`
Expected: `No issues found!` (경고 있으면 수정).

- [ ] **Step 6: 기기 수동 검증**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter run`
확인(포즈 이미지가 생성돼 있어야 오버레이가 보임 — 없으면 오버레이는 조용히 숨김):
1. 하단 '포즈' 아이콘 → 피커 열림(카테고리 탭·썸네일).
2. 포즈 탭 → 프리뷰 위에 앰버 반투명 실루엣 오버레이, 촬영해도 사진엔 미포함.
3. '끄기' → 오버레이 사라짐, 아이콘 dim.
4. 'AI 추천'(동의 후) → 장면에 맞는 포즈 자동 오버레이 + 이유 스낵바.
5. 비행기모드에서 'AI 추천' → 에러 스낵바, 앱 정상.

- [ ] **Step 7: 커밋**

```bash
git add lib/poses/pose_catalog.dart lib/overlay/pose_overlay.dart lib/poses/pose_picker.dart lib/screens/camera_screen.dart
git commit -m "feat: 포즈 오버레이·피커·카메라 연결(선택 오버레이 + AI 추천)"
```

---

### Task 7: 완료 게이트 + 스토어/방침 확인

**Files:** (검증 전용)

- [ ] **Step 1: 전체 검증 게이트**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && tool/verify.sh`
Expected: format·`dart analyze`·`flutter test` 모두 통과.

- [ ] **Step 2: 서버 검증**

Run: `cd functions && npm run build && npx vitest run`
Expected: 빌드·테스트 통과.

- [ ] **Step 3: 배포·에셋 안내(출시 시)**

- 포즈 이미지 생성: `OPENAI_API_KEY=sk-... python3 tool/pose_gen.py --images` 후 `assets/poses/*.png` 커밋.
- `suggestPose` 배포: `firebase deploy --only functions`(기존 `OPENAI_API_KEY` 시크릿 재사용).
- 개인정보 처리방침은 이미 "OpenAI에 이미지 전송"을 포함하므로 수정 불필요(포즈 추천도 동일 범주 — 재확인만).
- 기능이 실기기 검증된 후에만 스토어 설명에 "맞춤 포즈 추천" 기재.

- [ ] **Step 4: 브랜치 마무리**

`superpowers:finishing-a-development-branch` 스킬로 병합/PR 여부 결정.
