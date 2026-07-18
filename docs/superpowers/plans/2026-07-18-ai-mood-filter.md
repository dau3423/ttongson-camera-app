# 촬영 직후 AI 무드 보정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 촬영 결과 화면에서 "오늘의 무드"를 고르면 AI가 사진에 맞는 보정값을 산출해 기기에서 적용하고, 원본과 보정본을 함께 저장한다.

**Architecture:** 보정 파라미터 계산은 순수 Dart(`analysis/mood_adjust.dart`)로 TDD하고, 픽셀 적용(image 패키지)·서버 호출·화면은 분리한다. 서버 콜러블 `enhance`가 Claude 비전+구조화 출력으로 `MoodParams`를 반환하며, 기존 `advise` 인프라(다운사이즈·base64·deviceId·App Check·레이트리밋·consent)를 그대로 재사용한다. 무드 탭 시 온디바이스 프리셋으로 즉시 미리보기 → AI 값 도착 시 갱신 → (무드별) 캐시.

**Tech Stack:** Flutter/Dart, `image` ^4.9.1, `cloud_functions`, `gallery_saver_plus`, `path_provider`, `shared_preferences`; Firebase Functions(TypeScript, nodejs22) + `@anthropic-ai/sdk`(claude-sonnet-4-6), vitest.

## Global Constraints

- `lib/analysis/`의 파일은 **Flutter/plugin/`image` 패키지 import 금지**(순수 Dart). `mood_adjust.dart`도 이 규칙을 지킨다.
- 모든 보정 파라미터는 **-1.0 ~ 1.0** 로 클램프한다(`grayscale`만 bool). `temperature` 양수=웜(앰버), `tint` 양수=마젠타.
- 정적 분석은 **`dart analyze lib test`** 를 쓴다(`flutter analyze`는 한글 디렉토리명 때문에 크래시).
- 완료 게이트: **`tool/verify.sh`**(format+analyze+test) 통과.
- 커밋 메시지는 Conventional Commits(`feat:`/`test:`/`chore:`).
- 네트워크는 AI 호출에만 사용하며, 실패·오프라인·consent 미동의 시 온디바이스 프리셋으로 폴백한다.
- Flutter SDK 경로: `/Users/soonbok/flutter/bin` (PATH에 추가 필요).

---

### Task 1: 보정 파라미터 모델 + 픽셀 수학 (순수)

**Files:**
- Create: `lib/analysis/mood_adjust.dart`
- Test: `test/analysis/mood_adjust_test.dart`

**Interfaces:**
- Consumes: 없음.
- Produces:
  - `class MoodParams { final double brightness, contrast, saturation, temperature, tint; final bool grayscale; const MoodParams({...}); static const MoodParams identity; factory MoodParams.fromJson(Map<String, dynamic> json); }`
  - `(int, int, int) adjustRgb(int r, int g, int b, MoodParams p)` — 0~255로 클램프된 RGB 반환.

- [ ] **Step 1: 실패 테스트 작성**

`test/analysis/mood_adjust_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/mood_adjust.dart';

void main() {
  group('MoodParams.fromJson', () {
    test('범위를 벗어난 값은 -1~1로 클램프', () {
      final p = MoodParams.fromJson({
        'brightness': 5.0,
        'contrast': -9.0,
        'saturation': 0.3,
        'temperature': 2.0,
        'tint': -3.0,
        'grayscale': true,
      });
      expect(p.brightness, 1.0);
      expect(p.contrast, -1.0);
      expect(p.saturation, 0.3);
      expect(p.temperature, 1.0);
      expect(p.tint, -1.0);
      expect(p.grayscale, isTrue);
    });

    test('누락/이상 타입은 0 또는 false로 방어', () {
      final p = MoodParams.fromJson({'brightness': 'x'});
      expect(p.brightness, 0.0);
      expect(p.contrast, 0.0);
      expect(p.grayscale, isFalse);
    });
  });

  group('adjustRgb', () {
    test('identity 파라미터는 픽셀을 바꾸지 않음', () {
      final (r, g, b) = adjustRgb(100, 150, 200, MoodParams.identity);
      expect([r, g, b], [100, 150, 200]);
    });

    test('밝기 +1이면 밝아지고 0~255로 클램프', () {
      final (r, _, _) = adjustRgb(200, 200, 200,
          const MoodParams(brightness: 1.0));
      expect(r, 255);
    });

    test('밝기 -1이면 어두워지고 0 아래로 안 내려감', () {
      final (r, _, _) = adjustRgb(50, 50, 50,
          const MoodParams(brightness: -1.0));
      expect(r, 0);
    });

    test('채도 -1이면 회색(모든 채널이 luminance로 수렴)', () {
      final (r, g, b) = adjustRgb(200, 100, 0,
          const MoodParams(saturation: -1.0));
      expect(r, g);
      expect(g, b);
    });

    test('색온도 양수는 R을 올리고 B를 낮춤(웜)', () {
      final (r, _, b) = adjustRgb(120, 120, 120,
          const MoodParams(temperature: 0.5));
      expect(r, greaterThan(120));
      expect(b, lessThan(120));
    });

    test('grayscale=true면 R=G=B', () {
      final (r, g, b) = adjustRgb(200, 100, 0,
          const MoodParams(grayscale: true));
      expect(r, g);
      expect(g, b);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/analysis/mood_adjust_test.dart`
Expected: FAIL (`mood_adjust.dart` 없음 / 심볼 미정의).

- [ ] **Step 3: 최소 구현**

`lib/analysis/mood_adjust.dart` (⚠️ `image`/Flutter import 금지):

```dart
// lib/analysis/mood_adjust.dart
// 순수 Dart — Flutter/plugin/image 패키지 import 금지.

/// AI/프리셋 보정 파라미터. 모든 값 -1.0~1.0(grayscale 제외).
class MoodParams {
  final double brightness; // + 밝게
  final double contrast; // + 대비 강하게
  final double saturation; // + 채도 높게, -1 이면 회색
  final double temperature; // + 웜(앰버), - 쿨(블루)
  final double tint; // + 마젠타, - 그린
  final bool grayscale;

  const MoodParams({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.grayscale = false,
  });

  static const MoodParams identity = MoodParams();

  factory MoodParams.fromJson(Map<String, dynamic> json) {
    double c(dynamic v) => v is num ? v.toDouble().clamp(-1.0, 1.0) : 0.0;
    return MoodParams(
      brightness: c(json['brightness']),
      contrast: c(json['contrast']),
      saturation: c(json['saturation']),
      temperature: c(json['temperature']),
      tint: c(json['tint']),
      grayscale: json['grayscale'] == true,
    );
  }
}

int _clamp255(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());

/// RGB(0~255)에 보정을 적용해 클램프된 RGB를 반환.
/// 순서: 밝기 → 대비 → 색온도/틴트 → 채도 → 흑백.
(int, int, int) adjustRgb(int r, int g, int b, MoodParams p) {
  double rd = r.toDouble(), gd = g.toDouble(), bd = b.toDouble();

  // 밝기: -1~1 → -128~+128 이동
  final br = p.brightness * 128.0;
  rd += br; gd += br; bd += br;

  // 대비: f=1+contrast, 128 기준 스케일
  final f = 1.0 + p.contrast;
  rd = (rd - 128) * f + 128;
  gd = (gd - 128) * f + 128;
  bd = (bd - 128) * f + 128;

  // 색온도(웜=+R,-B) / 틴트(마젠타=-G)
  rd += p.temperature * 60.0;
  bd -= p.temperature * 60.0;
  gd -= p.tint * 60.0;

  // 채도: luminance 기준 확대/축소
  final lum = 0.299 * rd + 0.587 * gd + 0.114 * bd;
  final s = 1.0 + p.saturation;
  rd = lum + (rd - lum) * s;
  gd = lum + (gd - lum) * s;
  bd = lum + (bd - lum) * s;

  if (p.grayscale) {
    final gl = 0.299 * rd + 0.587 * gd + 0.114 * bd;
    rd = gl; gd = gl; bd = gl;
  }

  return (_clamp255(rd), _clamp255(gd), _clamp255(bd));
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/analysis/mood_adjust_test.dart`
Expected: PASS (모든 테스트).

- [ ] **Step 5: 커밋**

```bash
git add lib/analysis/mood_adjust.dart test/analysis/mood_adjust_test.dart
git commit -m "feat: 무드 보정 파라미터 모델·픽셀 수학(순수 TDD)"
```

---

### Task 2: 무드 세트 + 온디바이스 프리셋 (순수)

**Files:**
- Create: `lib/edit/mood.dart`
- Test: `test/edit/mood_test.dart`

**Interfaces:**
- Consumes: `MoodParams`(Task 1).
- Produces:
  - `enum Mood { warm, cool, film, moody, vivid, bw }`
  - `extension MoodInfo on Mood { String get label; String get wire; MoodParams get preset; }`

- [ ] **Step 1: 실패 테스트 작성**

`test/edit/mood_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/edit/mood.dart';

void main() {
  test('무드 6종이 존재하고 라벨/wire가 비어있지 않다', () {
    expect(Mood.values.length, 6);
    for (final m in Mood.values) {
      expect(m.label.isNotEmpty, isTrue);
      expect(m.wire.isNotEmpty, isTrue);
    }
  });

  test('wire 키가 서로 겹치지 않는다', () {
    final wires = Mood.values.map((m) => m.wire).toSet();
    expect(wires.length, Mood.values.length);
  });

  test('bw 프리셋은 grayscale=true', () {
    expect(Mood.bw.preset.grayscale, isTrue);
  });

  test('vivid 프리셋은 채도가 양수, moody는 음수', () {
    expect(Mood.vivid.preset.saturation, greaterThan(0));
    expect(Mood.moody.preset.saturation, lessThan(0));
  });

  test('warm 프리셋은 색온도 양수, cool은 음수', () {
    expect(Mood.warm.preset.temperature, greaterThan(0));
    expect(Mood.cool.preset.temperature, lessThan(0));
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/edit/mood_test.dart`
Expected: FAIL (`mood.dart` 없음).

- [ ] **Step 3: 최소 구현**

`lib/edit/mood.dart`:

```dart
// lib/edit/mood.dart
// 순수 Dart — 무드 정의와 온디바이스 기본 프리셋(AI 실패 시 폴백).
import '../analysis/mood_adjust.dart';

enum Mood { warm, cool, film, moody, vivid, bw }

extension MoodInfo on Mood {
  String get label => switch (this) {
    Mood.warm => '따뜻하게',
    Mood.cool => '시원하게',
    Mood.film => '필름',
    Mood.moody => '무디',
    Mood.vivid => '쨍하게',
    Mood.bw => '흑백',
  };

  String get wire => name; // 'warm','cool','film','moody','vivid','bw'

  /// AI 실패/오프라인 시 사용할 기본 보정값.
  MoodParams get preset => switch (this) {
    Mood.warm => const MoodParams(temperature: 0.35, brightness: 0.05, saturation: 0.1),
    Mood.cool => const MoodParams(temperature: -0.35, saturation: 0.05),
    Mood.film => const MoodParams(contrast: -0.15, saturation: -0.1, temperature: 0.1, tint: 0.08),
    Mood.moody => const MoodParams(saturation: -0.35, contrast: 0.1, brightness: -0.05),
    Mood.vivid => const MoodParams(saturation: 0.4, contrast: 0.15),
    Mood.bw => const MoodParams(grayscale: true, contrast: 0.1),
  };
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/edit/mood_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/edit/mood.dart test/edit/mood_test.dart
git commit -m "feat: 무드 6종 정의·온디바이스 프리셋"
```

---

### Task 3: 이미지에 보정 적용 (image 패키지)

**Files:**
- Create: `lib/edit/mood_processor.dart`
- Test: `test/edit/mood_processor_test.dart`

**Interfaces:**
- Consumes: `MoodParams`(Task 1), `adjustRgb`(Task 1).
- Produces:
  - `img.Image applyMoodToImage(img.Image src, MoodParams p)` — 각 픽셀에 `adjustRgb` 적용한 새 이미지.
  - `Future<File> applyMood(File src, MoodParams p)` — 디코드→방향 반영→EXIF 제거→적용→JPEG 임시파일. 아이솔레이트 실행.

- [ ] **Step 1: 실패 테스트 작성**

`test/edit/mood_processor_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ttongson_camera/analysis/mood_adjust.dart';
import 'package:ttongson_camera/edit/mood_processor.dart';

void main() {
  test('identity 파라미터는 픽셀 값을 유지', () {
    final src = img.Image(width: 2, height: 2);
    src.setPixelRgb(0, 0, 100, 150, 200);
    src.setPixelRgb(1, 1, 10, 20, 30);
    final out = applyMoodToImage(src, MoodParams.identity);
    final p = out.getPixel(0, 0);
    expect([p.r.toInt(), p.g.toInt(), p.b.toInt()], [100, 150, 200]);
  });

  test('grayscale 프리셋은 R=G=B로 만든다', () {
    final src = img.Image(width: 1, height: 1);
    src.setPixelRgb(0, 0, 200, 100, 0);
    final out = applyMoodToImage(src, const MoodParams(grayscale: true));
    final p = out.getPixel(0, 0);
    expect(p.r.toInt(), p.g.toInt());
    expect(p.g.toInt(), p.b.toInt());
  });

  test('원본 이미지는 변형하지 않는다(새 이미지 반환)', () {
    final src = img.Image(width: 1, height: 1);
    src.setPixelRgb(0, 0, 100, 100, 100);
    applyMoodToImage(src, const MoodParams(brightness: 1.0));
    final p = src.getPixel(0, 0);
    expect(p.r.toInt(), 100); // 원본 불변
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/edit/mood_processor_test.dart`
Expected: FAIL (`mood_processor.dart` 없음).

- [ ] **Step 3: 최소 구현**

`lib/edit/mood_processor.dart`:

```dart
// lib/edit/mood_processor.dart
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../analysis/mood_adjust.dart';

/// 각 픽셀에 adjustRgb를 적용한 새 이미지를 반환(원본 불변).
img.Image applyMoodToImage(img.Image src, MoodParams p) {
  final out = src.clone();
  for (final pixel in out) {
    final (r, g, b) = adjustRgb(
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
      p,
    );
    pixel.setRgb(r, g, b);
  }
  return out;
}

/// src 이미지를 보정해 JPEG 임시 파일로 저장하고 경로 File을 반환.
/// 디코드→방향 반영→EXIF 제거→보정→인코드. 픽셀 처리는 아이솔레이트에서.
Future<File> applyMood(File src, MoodParams p) async {
  final bytes = await src.readAsBytes();
  final jpeg = await Isolate.run(() => _process(bytes, p));
  final dir = await getTemporaryDirectory();
  final out = File(
    '${dir.path}/mood_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await out.writeAsBytes(jpeg);
  return out;
}

Uint8List _process(Uint8List bytes, MoodParams p) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('이미지 디코딩 실패');
  }
  final baked = img.bakeOrientation(decoded);
  baked.exif = img.ExifData();
  final adjusted = applyMoodToImage(baked, p);
  return img.encodeJpg(adjusted, quality: 90);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/edit/mood_processor_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/edit/mood_processor.dart test/edit/mood_processor_test.dart
git commit -m "feat: 이미지에 무드 보정 적용(image 패키지)"
```

---

### Task 4: 서버 콜러블 `enhance` (Claude 보정값)

**Files:**
- Create: `functions/src/mood.ts`
- Create: `functions/src/enhance.ts`
- Create: `functions/src/mood.test.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Consumes: 기존 `ratelimit.ts`, `auth_guard.ts`, `@anthropic-ai/sdk`.
- Produces:
  - `mood.ts`: `type MoodKey`; `parseMoodKey(raw): MoodKey`; `MOOD_SCHEMA`; `buildMoodSystem(mood)`; `buildMoodUser(mood)`; `parseMoodParams(text): {brightness,contrast,saturation,temperature,tint,grayscale}`.
  - `enhance.ts`: `export const enhance` (onCall).

- [ ] **Step 1: 실패 테스트 작성**

`functions/src/mood.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { parseMoodKey, parseMoodParams } from "./mood.js";

describe("parseMoodKey", () => {
  it("화이트리스트 값은 그대로", () => {
    expect(parseMoodKey("warm")).toBe("warm");
    expect(parseMoodKey("bw")).toBe("bw");
  });
  it("이상값은 warm 폴백", () => {
    expect(parseMoodKey("xyz")).toBe("warm");
    expect(parseMoodKey(undefined)).toBe("warm");
  });
});

describe("parseMoodParams", () => {
  it("범위를 벗어난 수치는 -1~1로 클램프", () => {
    const p = parseMoodParams(
      JSON.stringify({
        brightness: 9, contrast: -9, saturation: 0.2,
        temperature: 2, tint: -2, grayscale: true,
      }),
    );
    expect(p.brightness).toBe(1);
    expect(p.contrast).toBe(-1);
    expect(p.temperature).toBe(1);
    expect(p.tint).toBe(-1);
    expect(p.grayscale).toBe(true);
  });
  it("누락 필드는 0/false로 방어", () => {
    const p = parseMoodParams(JSON.stringify({ brightness: 0.1 }));
    expect(p.contrast).toBe(0);
    expect(p.grayscale).toBe(false);
  });
  it("JSON이 아니면 throw", () => {
    expect(() => parseMoodParams("not json")).toThrow();
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd functions && npx vitest run src/mood.test.ts`
Expected: FAIL (`mood.js` 없음).

- [ ] **Step 3: `mood.ts` 구현**

`functions/src/mood.ts`:

```ts
export type MoodKey = "warm" | "cool" | "film" | "moody" | "vivid" | "bw";

const MOODS: MoodKey[] = ["warm", "cool", "film", "moody", "vivid", "bw"];

export function parseMoodKey(raw: unknown): MoodKey {
  return MOODS.includes(raw as MoodKey) ? (raw as MoodKey) : "warm";
}

export const MOOD_SCHEMA = {
  type: "object",
  properties: {
    brightness: { type: "number" },
    contrast: { type: "number" },
    saturation: { type: "number" },
    temperature: { type: "number" },
    tint: { type: "number" },
    grayscale: { type: "boolean" },
  },
  required: ["brightness", "contrast", "saturation", "temperature", "tint", "grayscale"],
  additionalProperties: false,
} as const;

const DIRECTION: Record<MoodKey, string> = {
  warm: "따뜻하고 아늑한 분위기(색온도를 약간 앰버 쪽으로).",
  cool: "시원하고 차분한 분위기(색온도를 약간 블루 쪽으로).",
  film: "아날로그 필름 감성(대비를 살짝 낮추고 약간 바랜 톤).",
  moody: "채도를 낮춘 차분하고 무게감 있는 톤.",
  vivid: "선명하고 화사한 톤(채도·대비를 살짝 올림).",
  bw: "분위기 있는 흑백(grayscale=true).",
};

export function buildMoodSystem(mood: MoodKey): string {
  return (
    "당신은 사진 색보정 전문가입니다. 입력 사진을 분석해 요청한 분위기를 " +
    "'자연스럽고 과하지 않게' 내는 보정값을 정합니다. " +
    "brightness/contrast/saturation/temperature/tint 는 모두 -1.0~1.0, " +
    "temperature 양수=따뜻(앰버)·음수=시원(블루), tint 양수=마젠타·음수=그린. " +
    "grayscale 은 흑백일 때만 true. 값은 대체로 -0.5~0.5 범위의 은은한 보정을 권장합니다. " +
    `목표 분위기: ${DIRECTION[mood]}`
  );
}

export function buildMoodUser(mood: MoodKey): string {
  return `이 사진에 '${mood}' 분위기를 입히기 위한 보정값을 정해 주세요.`;
}

export function parseMoodParams(text: string): {
  brightness: number; contrast: number; saturation: number;
  temperature: number; tint: number; grayscale: boolean;
} {
  const raw = JSON.parse(text);
  const c = (v: unknown): number =>
    typeof v === "number" ? Math.max(-1, Math.min(1, v)) : 0;
  return {
    brightness: c(raw.brightness),
    contrast: c(raw.contrast),
    saturation: c(raw.saturation),
    temperature: c(raw.temperature),
    tint: c(raw.tint),
    grayscale: raw.grayscale === true,
  };
}
```

- [ ] **Step 4: `mood.ts` 테스트 통과 확인**

Run: `cd functions && npx vitest run src/mood.test.ts`
Expected: PASS.

- [ ] **Step 5: `enhance.ts` 구현 (`advise.ts` 패턴 미러)**

`functions/src/enhance.ts`:

```ts
// functions/src/enhance.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import Anthropic from "@anthropic-ai/sdk";
import { requireAuthUid } from "./auth_guard.js";
import { windowStart, overLimit } from "./ratelimit.js";
import {
  parseMoodKey, MOOD_SCHEMA, buildMoodSystem, buildMoodUser, parseMoodParams,
} from "./mood.js";

if (getApps().length === 0) initializeApp();

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

const MAX_IMAGE_BYTES = 4 * 1024 * 1024;
const RATE_MAX = 30;
const RATE_WINDOW_MS = 60_000;

export const enhance = onCall(
  {
    region: "asia-northeast3",
    secrets: [ANTHROPIC_API_KEY],
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (request) => {
    requireAuthUid(request.auth);
    const data = request.data as {
      imageBase64?: string; mediaType?: string; deviceId?: string; mood?: unknown;
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
    const mood = parseMoodKey(data.mood);

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
      const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
      const response = await client.messages.create({
        model: "claude-sonnet-4-6",
        max_tokens: 512,
        system: buildMoodSystem(mood),
        output_config: {
          format: { type: "json_schema", schema: MOOD_SCHEMA as { [key: string]: unknown } },
        },
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: "image/jpeg", data: data.imageBase64 } },
              { type: "text", text: buildMoodUser(mood) },
            ],
          },
        ],
      });
      const textBlock = response.content.find((b) => b.type === "text");
      if (!textBlock || textBlock.type !== "text") {
        throw new Error("모델 응답에 텍스트 블록이 없습니다");
      }
      return parseMoodParams(textBlock.text);
    } catch (err) {
      console.error("enhance failed", err);
      throw new HttpsError("internal", "보정값 생성에 실패했습니다");
    }
  },
);
```

- [ ] **Step 6: export 추가**

`functions/src/index.ts` 에 한 줄 추가:

```ts
export { enhance } from "./enhance.js";
```

- [ ] **Step 7: 빌드/전체 서버 테스트 확인**

Run: `cd functions && npm run build && npx vitest run`
Expected: 타입 오류 없이 빌드 성공, 모든 테스트 PASS.

- [ ] **Step 8: 커밋**

```bash
git add functions/src/mood.ts functions/src/enhance.ts functions/src/mood.test.ts functions/src/index.ts
git commit -m "feat: 서버 enhance 콜러블 — Claude 무드 보정값(구조화 출력)"
```

---

### Task 5: 클라이언트 무드 어드바이저 (호출 + 캐시)

**Files:**
- Create: `lib/cloud/mood_advisor.dart`
- Test: `test/cloud/mood_advisor_test.dart`

**Interfaces:**
- Consumes: `MoodParams`(Task 1), 기존 `advice_image.dart`(`encodeDownsizedJpeg`, `fileToBase64`).
- Produces:
  - `class MoodAdviceException implements Exception { final String message; ... }`
  - `class MoodAdvisor { MoodAdvisor({FirebaseFunctions? functions}); Future<MoodParams> enhance({required String jpegPath, required String moodWire, required String deviceId}); }`
  - 캐시: 인스턴스는 **촬영 사진 1장당 하나** 생성되므로 캐시 키는 `moodWire`.

- [ ] **Step 1: 실패 테스트 작성**

`test/cloud/mood_advisor_test.dart` (파싱만 순수 검증 — 네트워크 호출은 기기 검증):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/mood_adjust.dart';
import 'package:ttongson_camera/cloud/mood_advisor.dart';

void main() {
  test('서버 응답 맵을 MoodParams로 파싱(범위 클램프)', () {
    final p = moodParamsFromResult({
      'brightness': 2.0,
      'contrast': 0.1,
      'saturation': -5.0,
      'temperature': 0.2,
      'tint': 0.0,
      'grayscale': true,
    });
    expect(p.brightness, 1.0);
    expect(p.saturation, -1.0);
    expect(p.grayscale, isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/cloud/mood_advisor_test.dart`
Expected: FAIL (`mood_advisor.dart` / `moodParamsFromResult` 없음).

- [ ] **Step 3: 최소 구현 (`cloud_advisor.dart` 패턴 미러)**

`lib/cloud/mood_advisor.dart`:

```dart
// lib/cloud/mood_advisor.dart
import 'package:cloud_functions/cloud_functions.dart';
import '../analysis/mood_adjust.dart';
import 'advice_image.dart';

class MoodAdviceException implements Exception {
  final String message;
  MoodAdviceException(this.message);
  @override
  String toString() => 'MoodAdviceException: $message';
}

/// 서버 결과 맵 → MoodParams (범위 클램프는 MoodParams.fromJson이 담당).
MoodParams moodParamsFromResult(Map<String, dynamic> data) =>
    MoodParams.fromJson(data);

/// 촬영 사진 1장당 하나 생성. 무드별 결과를 캐시해 재호출을 막는다.
class MoodAdvisor {
  final FirebaseFunctions _functions;
  final Map<String, MoodParams> _cache = {};

  MoodAdvisor({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<MoodParams> enhance({
    required String jpegPath,
    required String moodWire,
    required String deviceId,
  }) async {
    final cached = _cache[moodWire];
    if (cached != null) return cached;
    try {
      final downsized = await encodeDownsizedJpeg(jpegPath);
      final base64 = await fileToBase64(downsized);
      final callable = _functions.httpsCallable(
        'enhance',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64,
        'mediaType': 'image/jpeg',
        'deviceId': deviceId,
        'mood': moodWire,
      });
      final params = moodParamsFromResult(Map<String, dynamic>.from(result.data));
      _cache[moodWire] = params;
      return params;
    } on FirebaseFunctionsException catch (e) {
      throw MoodAdviceException(e.message ?? '보정값 생성 실패');
    } catch (e) {
      throw MoodAdviceException('보정값 생성 실패: $e');
    }
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/cloud/mood_advisor_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/cloud/mood_advisor.dart test/cloud/mood_advisor_test.dart
git commit -m "feat: 클라이언트 무드 어드바이저(enhance 호출·무드별 캐시)"
```

---

### Task 6: 촬영 결과 화면 + 카메라 연결 (기기 검증)

**Files:**
- Create: `lib/screens/capture_result_screen.dart`
- Modify: `lib/screens/camera_screen.dart` (촬영 후 결과 화면 push)

**Interfaces:**
- Consumes: `Mood`/`MoodInfo`(Task 2), `applyMood`(Task 3), `MoodAdvisor`(Task 5), `MoodParams`(Task 1), 기존 `AuthService`, `DeviceId`(`lib/cloud/device_id.dart`), `AdviceConsentStore`(`lib/cloud/advice_consent.dart`), `CameraService.saveToGallery`.
- Produces: `class CaptureResultScreen extends StatefulWidget { final File original; final AuthService auth; const CaptureResultScreen({required this.original, required this.auth}); }`

> 이 태스크는 UI/플러그인 통합이라 단위 테스트 대신 **기기 수동 검증**한다(프로젝트 규율).

- [ ] **Step 1: 결과 화면 구현**

`lib/screens/capture_result_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../community/auth_service.dart';
import '../community/screens/sign_in_sheet.dart';
import '../cloud/advice_consent.dart';
import '../cloud/device_id.dart';
import '../cloud/mood_advisor.dart';
import '../analysis/mood_adjust.dart';
import '../camera/camera_service.dart';
import '../edit/mood.dart';
import '../edit/mood_processor.dart';

/// 촬영 직후 무드 보정 화면. 원본은 이미 갤러리에 저장됨.
/// 무드 탭 → 프리셋 즉시 미리보기 → AI 값 도착 시 갱신(무드별 캐시).
class CaptureResultScreen extends StatefulWidget {
  final File original;
  final AuthService auth;
  const CaptureResultScreen({
    super.key,
    required this.original,
    required this.auth,
  });

  @override
  State<CaptureResultScreen> createState() => _CaptureResultScreenState();
}

class _CaptureResultScreenState extends State<CaptureResultScreen> {
  final _advisor = MoodAdvisor();
  final _deviceId = DeviceId();
  final _consent = AdviceConsentStore();
  final _camera = CameraService();

  Mood? _selected; // null = 원본
  File _preview = File(''); // 표시용(초기엔 원본)
  MoodParams _finalParams = MoodParams.identity;
  bool _working = false;
  int _reqSeq = 0; // 늦게 도착한 이전 요청 무시용

  @override
  void initState() {
    super.initState();
    _preview = widget.original;
  }

  Future<bool> _ensureConsent() async {
    if (!widget.auth.isSignedIn) {
      final ok = await showSignInSheet(context, widget.auth);
      if (!ok) return false;
    }
    if (await _consent.hasConsented()) return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 보정 안내'),
        content: const Text(
          'AI 보정 시 사진 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('동의')),
        ],
      ),
    );
    if (ok == true) await _consent.setConsented();
    return ok == true;
  }

  Future<void> _selectMood(Mood? mood) async {
    final seq = ++_reqSeq;
    setState(() => _selected = mood);

    if (mood == null) {
      setState(() {
        _preview = widget.original;
        _finalParams = MoodParams.identity;
      });
      return;
    }

    // 1) 프리셋 즉시 미리보기 (디코드 실패 등은 스킵+안내 — 스펙 §8)
    setState(() => _working = true);
    var params = mood.preset;
    File file;
    try {
      file = await applyMood(widget.original, params);
    } catch (_) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _selected = null;
        _preview = widget.original;
        _finalParams = MoodParams.identity;
        _working = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 사진은 보정할 수 없어요')),
      );
      return;
    }
    if (!mounted || seq != _reqSeq) return;
    setState(() {
      _preview = file;
      _finalParams = params;
    });

    // 2) AI 갱신(동의 시). 실패/거부 시 프리셋 유지.
    if (await _ensureConsent()) {
      try {
        final deviceId = await _deviceId.get();
        params = await _advisor.enhance(
          jpegPath: widget.original.path,
          moodWire: mood.wire,
          deviceId: deviceId,
        );
        file = await applyMood(widget.original, params);
        if (!mounted || seq != _reqSeq) return;
        setState(() {
          _preview = file;
          _finalParams = params;
        });
      } catch (_) {
        // 프리셋 결과 유지(조용히 폴백)
      }
    }
    if (mounted && seq == _reqSeq) setState(() => _working = false);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_selected == null) {
        messenger.showSnackBar(const SnackBar(content: Text('원본은 이미 저장되어 있어요')));
        return;
      }
      final edited = await applyMood(widget.original, _finalParams);
      final ok = await _camera.saveToGallery(edited.path);
      messenger.showSnackBar(
        SnackBar(content: Text(ok ? '보정본을 저장했어요' : '저장 실패 — 권한을 확인해 주세요')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 무드'),
        actions: [
          TextButton(onPressed: _working ? null : _save, child: const Text('저장')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.file(_preview, fit: BoxFit.contain, key: ValueKey(_preview.path)),
                if (_working) const CircularProgressIndicator(),
              ],
            ),
          ),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                _MoodChip(label: '원본', selected: _selected == null, onTap: () => _selectMood(null)),
                for (final m in Mood.values)
                  _MoodChip(
                    label: m.label,
                    selected: _selected == m,
                    onTap: () => _selectMood(m),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MoodChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
```

- [ ] **Step 2: 카메라 화면에서 결과 화면으로 연결**

`lib/screens/camera_screen.dart` 의 `_capture()`에서, 저장 성공 후 촬영 파일 경로로 결과 화면을 push한다. 현재 `_capture()`는 `captureAndSave()`(경로를 돌려주지 않음)를 쓰므로, **경로를 확보하는 형태로 바꾼다**:

기존 (참고, `lib/screens/camera_screen.dart` 내 `_capture` 본문):

```dart
      final bool saved;
      if (_portrait && _mode == ShootingMode.person) {
        final path = await _camera.capturePhoto();
        final blurred = await applyPortraitBlur(
          File(path),
          nowMicros: DateTime.now().microsecondsSinceEpoch,
        );
        saved = await _camera.saveToGallery(blurred.path);
      } else {
        saved = await _camera.captureAndSave();
      }
```

변경 후 (촬영 파일 경로를 잡아 저장 후 결과 화면으로 이동):

```dart
      final String shotPath;
      if (_portrait && _mode == ShootingMode.person) {
        final path = await _camera.capturePhoto();
        final blurred = await applyPortraitBlur(
          File(path),
          nowMicros: DateTime.now().microsecondsSinceEpoch,
        );
        shotPath = blurred.path;
      } else {
        shotPath = await _camera.capturePhoto();
      }
      final saved = await _camera.saveToGallery(shotPath);
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 실패 — 사진첩 권한을 확인해 주세요')),
        );
      }
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CaptureResultScreen(
              original: File(shotPath),
              auth: _auth,
            ),
          ),
        );
      }
```

그리고 파일 상단 import에 다음을 추가:

```dart
import 'capture_result_screen.dart';
```

> 참고: `capturePhoto()`는 갤러리에 저장하지 않고 임시 경로만 돌려주므로, 위처럼 `saveToGallery(shotPath)`로 원본을 저장한 뒤 그 경로를 결과 화면에 넘긴다. `_auth`는 `camera_screen`이 이미 보유한 `AuthService` 필드다(없으면 기존 `_auth` 선언을 확인).

- [ ] **Step 3: 정적 분석**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && dart analyze lib test`
Expected: `No issues found!` (경고 있으면 수정).

- [ ] **Step 4: 기기 수동 검증**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter run`
확인 항목:
1. 촬영 → 결과 화면 진입, 원본이 크게 보인다.
2. 무드 칩 탭 → 즉시(프리셋) 미리보기 변화 → 잠시 후 AI 값으로 갱신(동의 후).
3. 같은 무드 재탭 시 재호출 없이 즉시 표시(캐시).
4. 비행기모드에서 무드 탭 → 프리셋만 적용되고 에러 없이 동작(폴백).
5. [저장] → 갤러리에 보정본 추가(원본과 별개로 2장).
6. '원본' 칩 → 원본으로 복귀.

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/capture_result_screen.dart lib/screens/camera_screen.dart
git commit -m "feat: 촬영 결과 화면 — 무드 보정(프리셋 즉시+AI 갱신)·원본/보정본 저장"
```

---

### Task 7: 완료 게이트 + 스토어 문구 반영

**Files:**
- Modify: (필요 시) `docs/` 스토어 문구 메모

- [ ] **Step 1: 전체 검증 게이트**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && tool/verify.sh`
Expected: format 검사·`dart analyze`·`flutter test` 모두 통과.

- [ ] **Step 2: 서버 검증**

Run: `cd functions && npm run build && npx vitest run`
Expected: 빌드·테스트 통과.

- [ ] **Step 3: 스토어 설명에 기능 반영(출시 시)**

기능이 실기기에서 검증된 후에만, 자세한 설명에 "AI 무드 보정(오늘의 무드)" 항목을 추가한다(허위광고 방지). 개인정보 처리방침은 이미 "AI 추천 시 이미지를 Anthropic에 전송"을 포함하므로 수정 불필요(재확인만).

- [ ] **Step 4: 브랜치 마무리**

`superpowers:finishing-a-development-branch` 스킬로 병합/PR 여부를 결정한다.
