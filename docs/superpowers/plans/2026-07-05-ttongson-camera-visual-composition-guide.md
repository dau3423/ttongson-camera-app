# 똥손카메라 — 시각 구도 가이드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 클라우드 구도 추천을 텍스트 카드에서 **시각 가이드**로 확장한다 — AI가 반환한 목표 박스를 프리뷰 위에 고스트 박스 + 이동 화살표로 그리고, Phase 1 실시간 인물 감지로 정렬되면 녹색 피드백을 주며, 미니맵으로 현재→목표를 보여준다.

**Architecture:** `CompositionAdvice` 계약을 `directions` 제거 + `targetBox{x,y,width,height}`(정규화) 추가로 바꾼다(백엔드·앱 동시). 앱은 순수 함수 `computeAlignment(현재 인물, 목표)`로 IoU 정렬 점수를 매 프레임 계산하고, `TargetGuideOverlay`(CustomPainter)와 `AdviceMinimap`이 이를 시각화한다. 순수 로직(파싱·정렬)은 TDD, 오버레이·미니맵·화면은 구현+기기 검증.

**Tech Stack:** Flutter(Dart), 기존 `camera`/`sensors_plus`/`google_mlkit_face_detection`; 백엔드 Firebase Functions(TypeScript, `@anthropic-ai/sdk` 0.110, `vitest`), `claude-sonnet-4-6` 비전 + `output_config.format` 구조화 출력.

## Global Constraints

- 앱: Flutter(Dart) null-safety. 패키지명 `ttongson_camera`. Flutter/dart at `/Users/soonbok/flutter/bin`.
- `CompositionAdvice` 계약(앱·백엔드 동일): `headline: String`, `targetBox: {x,y,width,height}`(정규화 0~1, 원점 좌상단), `rationale: String`. **`directions` 필드 제거.**
- 좌표 정규화 0.0~1.0, 원점 좌상단(x→오른쪽, y→아래). 각도는 도 단위. 색 규약: 좋음=녹색(0xAA69F0AE), 주의/미정렬=빨강(0xAAFF5252), 중립=흰색 반투명.
- 정렬: IoU 기반 score(0~1), `aligned = score ≥ 0.6`. `dx = target.centerX − current.centerX`, `dy = target.centerY − current.centerY`.
- 모델 ID는 정확히 `claude-sonnet-4-6`. 구조화 출력은 `output_config.format`(json_schema).
- 앱 정적분석은 `dart analyze lib test`(한글 경로로 `flutter analyze` 크래시). 백엔드는 `npm run build`(tsc) + `npx vitest run`.
- 앱 게이트: `tool/verify.sh`(format+analyze+test). 커밋: Conventional Commits. 작업 디렉토리 `/Users/soonbok/Projects/junicode/똥손카메라`.

---

## File Structure

```
functions/src/
  schema.ts    (MODIFY) COMPOSITION_SCHEMA에 targetBox + 프롬프트, directions 제거
  advice.ts    (MODIFY) CompositionAdvice/parseAdvice targetBox, AdviceDirection/directions 제거
functions/test/
  advice.test.ts (MODIFY) targetBox 파싱/검증 케이스
lib/cloud/
  composition_advice.dart  (MODIFY) TargetBox 추가, directions/AdviceAxis/AdviceDirection 제거
  target_alignment.dart    (CREATE, 순수) AlignmentResult + computeAlignment  [TDD]
  target_guide_overlay.dart(CREATE) 목표 고스트 박스 + 이동 화살표 CustomPainter
  advice_minimap.dart      (CREATE) 프레임+현재+목표+화살표 개요도
  advice_overlay.dart      (MODIFY) headline+rationale만 (directions 렌더 제거)
lib/screens/
  camera_screen.dart       (MODIFY) 정렬 계산 + TargetGuideOverlay/AdviceMinimap 배선
test/cloud/
  composition_advice_test.dart (MODIFY) targetBox 파싱
  target_alignment_test.dart   (CREATE)
```

---

## Task 1: 백엔드 계약 변경 — targetBox 추가 / directions 제거 (TDD)

**Files:**
- Modify: `functions/src/advice.ts`, `functions/src/schema.ts`
- Modify(Test): `functions/test/advice.test.ts`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `advice.ts`: `interface TargetBox { x:number; y:number; width:number; height:number }`, `interface CompositionAdvice { headline:string; targetBox:TargetBox; rationale:string }`, `parseAdvice(text)` — targetBox 검증(4필드 number), directions/AdviceDirection 제거. `OnDeviceMetrics` 유지.
  - `schema.ts`: `COMPOSITION_SCHEMA`에 targetBox(4필드), `SYSTEM_PROMPT`에 목표 박스 지시, `buildUserText` 유지.

- [ ] **Step 1: 테스트를 새 계약으로 교체 (실패 확인용)**

`functions/test/advice.test.ts` 전체를 아래로 교체:
```typescript
import { describe, it, expect } from "vitest";
import { parseAdvice } from "../src/advice.js";
import { buildUserText } from "../src/schema.js";

describe("parseAdvice", () => {
  it("유효한 JSON을 CompositionAdvice로 파싱(targetBox 포함)", () => {
    const text = JSON.stringify({
      headline: "인물을 오른쪽 3분할선으로",
      targetBox: { x: 0.55, y: 0.3, width: 0.3, height: 0.6 },
      rationale: "여백이 넓어 답답합니다",
    });
    const a = parseAdvice(text);
    expect(a.headline).toBe("인물을 오른쪽 3분할선으로");
    expect(a.targetBox).toEqual({ x: 0.55, y: 0.3, width: 0.3, height: 0.6 });
    expect(a.rationale).toContain("여백");
  });

  it("targetBox 누락이면 throw", () => {
    expect(() =>
      parseAdvice(JSON.stringify({ headline: "x", rationale: "z" })),
    ).toThrow();
  });

  it("targetBox 필드가 숫자가 아니면 throw", () => {
    const bad = JSON.stringify({
      headline: "x",
      targetBox: { x: "a", y: 0.3, width: 0.3, height: 0.6 },
      rationale: "z",
    });
    expect(() => parseAdvice(bad)).toThrow();
  });

  it("headline/rationale 누락이면 throw", () => {
    const bad = JSON.stringify({
      targetBox: { x: 0.5, y: 0.3, width: 0.3, height: 0.6 },
    });
    expect(() => parseAdvice(bad)).toThrow();
  });

  it("JSON이 아니면 throw", () => {
    expect(() => parseAdvice("not json")).toThrow();
  });
});

describe("buildUserText", () => {
  it("인물 지표가 있으면 프롬프트에 위치를 포함", () => {
    const t = buildUserText({
      hasPerson: true,
      personCenterX: 0.2,
      personCenterY: 0.5,
      tiltDeg: 3,
    });
    expect(t).toContain("인물");
    expect(t).toContain("0.2");
  });

  it("지표가 없어도 유효한 지시문을 만든다", () => {
    const t = buildUserText(undefined);
    expect(t.length).toBeGreaterThan(0);
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd functions && npx vitest run 2>&1 | tail -20 ; cd ..`
Expected: FAIL — 현재 parseAdvice는 directions를 요구하므로 targetBox 케이스 실패.

- [ ] **Step 3: advice.ts 교체**

`functions/src/advice.ts` 전체를 아래로 교체:
```typescript
export interface TargetBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface CompositionAdvice {
  headline: string;
  targetBox: TargetBox;
  rationale: string;
}

export interface OnDeviceMetrics {
  tiltDeg?: number;
  personCenterX?: number;
  personCenterY?: number;
  hasPerson?: boolean;
}

function parseTargetBox(raw: unknown): TargetBox {
  const t = raw as Record<string, unknown>;
  if (
    !t ||
    typeof t.x !== "number" ||
    typeof t.y !== "number" ||
    typeof t.width !== "number" ||
    typeof t.height !== "number"
  ) {
    throw new Error("targetBox 누락 또는 형식 오류");
  }
  return { x: t.x, y: t.y, width: t.width, height: t.height };
}

/** 모델이 반환한 JSON 텍스트를 CompositionAdvice로 검증·파싱. 위반 시 throw. */
export function parseAdvice(text: string): CompositionAdvice {
  const raw = JSON.parse(text); // JSON 아니면 SyntaxError throw
  if (typeof raw.headline !== "string" || typeof raw.rationale !== "string") {
    throw new Error("headline/rationale 누락");
  }
  const targetBox = parseTargetBox(raw.targetBox);
  return { headline: raw.headline, targetBox, rationale: raw.rationale };
}
```

- [ ] **Step 4: schema.ts 교체**

`functions/src/schema.ts` 전체를 아래로 교체:
```typescript
import type { OnDeviceMetrics } from "./advice.js";

export const COMPOSITION_SCHEMA = {
  type: "object",
  properties: {
    headline: { type: "string" },
    targetBox: {
      type: "object",
      properties: {
        x: { type: "number" },
        y: { type: "number" },
        width: { type: "number" },
        height: { type: "number" },
      },
      required: ["x", "y", "width", "height"],
      additionalProperties: false,
    },
    rationale: { type: "string" },
  },
  required: ["headline", "targetBox", "rationale"],
  additionalProperties: false,
} as const;

export const SYSTEM_PROMPT =
  "당신은 사진 구도 코치입니다. 사용자가 카메라로 보고 있는 장면 사진 한 장을 받고, " +
  "인물·배경·위치를 고려해 인물을 놓을 '더 좋은 목표 위치'를 정합니다. " +
  "반드시 한국어로 간결하게 답합니다. " +
  "headline은 한 줄 핵심 조언, rationale은 한 문장 이유입니다. " +
  "targetBox는 인물이 들어갈 목표 영역을 정규화 좌표(0~1, 원점 좌상단)로 나타낸 사각형입니다. " +
  "x,y는 좌상단, width,height는 크기이며 모두 0~1 사이입니다. " +
  "가능하면 3분할선/교차점에 맞추고, 인물 전체가 프레임에 담기도록 정합니다. " +
  "이미 구도가 좋으면 현재 인물 위치와 비슷한 목표를 반환하세요.";

export function buildUserText(metrics?: OnDeviceMetrics): string {
  const lines = [
    "이 장면에서 인물을 놓을 더 좋은 목표 위치를 targetBox로 제안해 주세요.",
  ];
  if (metrics) {
    if (
      metrics.hasPerson &&
      metrics.personCenterX != null &&
      metrics.personCenterY != null
    ) {
      lines.push(
        `참고(온디바이스 감지): 현재 인물 중심이 정규화 좌표 (${metrics.personCenterX}, ${metrics.personCenterY})에 있습니다.`,
      );
    }
    if (metrics.tiltDeg != null) {
      lines.push(`참고: 현재 좌우 기울기 약 ${metrics.tiltDeg}도.`);
    }
  }
  return lines.join("\n");
}
```

- [ ] **Step 5: 테스트 통과 + 빌드 확인**

Run: `cd functions && npx vitest run 2>&1 | tail -20 && npm run build 2>&1 | tail -8 ; cd ..`
Expected: vitest 7 pass, tsc 에러 없음. (`claude.ts`는 `COMPOSITION_SCHEMA`를 그대로 참조하므로 수정 불필요 — 재확인만.)

- [ ] **Step 6: Commit**

```bash
git add functions/src/advice.ts functions/src/schema.ts functions/test/advice.test.ts
git commit -m "feat(functions): replace directions with targetBox in advice contract (TDD)"
```

---

## Task 2: 앱 모델 마이그레이션 — TargetBox 추가 / directions 제거 + 카드 축소

**Files:**
- Modify: `lib/cloud/composition_advice.dart`, `lib/cloud/advice_overlay.dart`
- Modify(Test): `test/cloud/composition_advice_test.dart`

**Interfaces:**
- Consumes: 없음(순수 Dart 모델)
- Produces:
  - `class TargetBox { double x,y,width,height; }` — getter `centerX`,`centerY`,`right`,`bottom`.
  - `class CompositionAdvice { String headline; TargetBox? targetBox; String rationale; }` — `fromJson` 방어적(targetBox 누락/이상 → null, 값은 0~1 clamp).
  - `AdviceOverlay`는 headline+rationale만 표시(directions 렌더 제거).
  - **제거**: `AdviceAxis`, `AdviceDirection`, `directions`.

> 모델과 오버레이를 한 태스크로 묶는다 — directions 제거 시 오버레이가 그 심볼을 참조하면 컴파일이 깨지므로 함께 바꿔 트리를 green으로 유지한다.

- [ ] **Step 1: 모델 테스트를 새 계약으로 교체 (실패 확인용)**

`test/cloud/composition_advice_test.dart` 전체를 아래로 교체:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/composition_advice.dart';

void main() {
  test('정상 JSON을 파싱한다(targetBox 포함)', () {
    final a = CompositionAdvice.fromJson({
      'headline': '인물을 오른쪽 3분할선으로',
      'targetBox': {'x': 0.55, 'y': 0.3, 'width': 0.3, 'height': 0.6},
      'rationale': '여백이 넓어 답답합니다',
    });
    expect(a.headline, '인물을 오른쪽 3분할선으로');
    expect(a.targetBox, isNotNull);
    expect(a.targetBox!.x, 0.55);
    expect(a.targetBox!.centerX, closeTo(0.7, 0.0001));
    expect(a.rationale, contains('여백'));
  });

  test('targetBox 누락 시 null, 나머지는 파싱', () {
    final a = CompositionAdvice.fromJson({'headline': 'x', 'rationale': 'z'});
    expect(a.targetBox, isNull);
    expect(a.headline, 'x');
    expect(a.rationale, 'z');
  });

  test('targetBox 필드가 숫자가 아니면 null', () {
    final a = CompositionAdvice.fromJson({
      'headline': 'x',
      'targetBox': {'x': 'a', 'y': 0.3, 'width': 0.3, 'height': 0.6},
      'rationale': 'z',
    });
    expect(a.targetBox, isNull);
  });

  test('범위를 벗어난 값은 0~1로 clamp', () {
    final a = CompositionAdvice.fromJson({
      'headline': 'x',
      'targetBox': {'x': 1.2, 'y': -0.1, 'width': 0.3, 'height': 0.6},
      'rationale': 'z',
    });
    expect(a.targetBox!.x, 1.0);
    expect(a.targetBox!.y, 0.0);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/cloud/composition_advice_test.dart`
Expected: FAIL — `targetBox` 심볼 없음.

- [ ] **Step 3: composition_advice.dart 교체**

`lib/cloud/composition_advice.dart` 전체를 아래로 교체:
```dart
/// 인물이 들어갈 목표 영역(정규화 0~1, 원점 좌상단).
class TargetBox {
  final double x;
  final double y;
  final double width;
  final double height;
  const TargetBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get right => x + width;
  double get bottom => y + height;
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
}

/// 클라우드 구도 추천 결과. 방어적 파싱 — 누락/이상 값에도 견고.
class CompositionAdvice {
  final String headline;
  final TargetBox? targetBox;
  final String rationale;

  const CompositionAdvice({
    required this.headline,
    required this.targetBox,
    required this.rationale,
  });

  factory CompositionAdvice.fromJson(Map<String, dynamic> json) {
    return CompositionAdvice(
      headline: (json['headline'] as String?) ?? '',
      targetBox: _parseTargetBox(json['targetBox']),
      rationale: (json['rationale'] as String?) ?? '',
    );
  }

  static TargetBox? _parseTargetBox(dynamic raw) {
    if (raw is! Map) return null;
    final x = raw['x'];
    final y = raw['y'];
    final w = raw['width'];
    final h = raw['height'];
    if (x is! num || y is! num || w is! num || h is! num) return null;
    double c(num v) => v.toDouble().clamp(0.0, 1.0);
    return TargetBox(x: c(x), y: c(y), width: c(w), height: c(h));
  }
}
```

- [ ] **Step 4: advice_overlay.dart를 축소(directions 렌더 제거)**

`lib/cloud/advice_overlay.dart` 전체를 아래로 교체:
```dart
// lib/cloud/advice_overlay.dart
import 'package:flutter/material.dart';
import 'composition_advice.dart';

/// 클라우드 구도 추천 카드(축소판) — headline + rationale만 표시.
class AdviceOverlay extends StatelessWidget {
  final CompositionAdvice advice;
  final VoidCallback onClose;
  const AdviceOverlay({super.key, required this.advice, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 140,
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Colors.amberAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      advice.headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),
              if (advice.rationale.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    advice.rationale,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 테스트 통과 + 분석 + 전체 테스트**

Run: `flutter test test/cloud/composition_advice_test.dart && dart analyze lib test 2>&1 | tail -5 && flutter test 2>&1 | tail -3`
Expected: 모델 테스트 4 pass, analyze 에러 없음(directions 심볼 잔존 없음), 전체 테스트 pass.

- [ ] **Step 6: Commit**

```bash
git add lib/cloud/composition_advice.dart lib/cloud/advice_overlay.dart test/cloud/composition_advice_test.dart
git commit -m "feat: migrate CompositionAdvice to targetBox; shrink advice card (TDD)"
```

---

## Task 3: 정렬 판정 로직 (순수 함수, TDD)

**Files:**
- Create: `lib/cloud/target_alignment.dart`, `test/cloud/target_alignment_test.dart`

**Interfaces:**
- Consumes: `TargetBox`(Task 2), `PersonBox`(`lib/models/person_box.dart`, Phase 1 — getter `left`,`top`,`width`,`height`,`right`,`bottom`,`centerX`,`centerY`).
- Produces:
  - `class AlignmentResult { double score; bool aligned; double dx; double dy; }`
  - `AlignmentResult computeAlignment(PersonBox current, TargetBox target, {double alignThreshold = 0.6})` — IoU score, `aligned = score ≥ threshold`, `dx = target.centerX − current.centerX`, `dy = target.centerY − current.centerY`.

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/cloud/target_alignment_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/cloud/composition_advice.dart';
import 'package:ttongson_camera/cloud/target_alignment.dart';

void main() {
  test('완전히 겹치면 score≈1, aligned=true, dx=dy=0', () {
    const current = PersonBox(left: 0.3, top: 0.3, width: 0.4, height: 0.4);
    const target = TargetBox(x: 0.3, y: 0.3, width: 0.4, height: 0.4);
    final r = computeAlignment(current, target);
    expect(r.score, closeTo(1.0, 0.0001));
    expect(r.aligned, isTrue);
    expect(r.dx, closeTo(0.0, 0.0001));
    expect(r.dy, closeTo(0.0, 0.0001));
  });

  test('완전히 떨어져 있으면 score=0, aligned=false, dx/dy는 목표 방향', () {
    const current = PersonBox(left: 0.0, top: 0.0, width: 0.2, height: 0.2);
    const target = TargetBox(x: 0.6, y: 0.6, width: 0.2, height: 0.2);
    final r = computeAlignment(current, target);
    expect(r.score, 0.0);
    expect(r.aligned, isFalse);
    expect(r.dx, closeTo(0.6, 0.0001)); // 0.7 - 0.1
    expect(r.dy, closeTo(0.6, 0.0001));
  });

  test('부분 겹침이면 0<score<1', () {
    const current = PersonBox(left: 0.3, top: 0.3, width: 0.4, height: 0.4);
    const target = TargetBox(x: 0.5, y: 0.3, width: 0.4, height: 0.4);
    final r = computeAlignment(current, target);
    // 교집합 0.2*0.4=0.08, 합집합 0.16+0.16-0.08=0.24 → IoU≈0.333
    expect(r.score, closeTo(0.3333, 0.001));
    expect(r.aligned, isFalse);
    expect(r.dx, closeTo(0.2, 0.0001)); // 0.7 - 0.5
    expect(r.dy, closeTo(0.0, 0.0001));
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/cloud/target_alignment_test.dart`
Expected: FAIL — `computeAlignment`/`AlignmentResult` 없음.

- [ ] **Step 3: 구현**

```dart
// lib/cloud/target_alignment.dart
import 'dart:math' as math;
import '../models/person_box.dart';
import 'composition_advice.dart';

class AlignmentResult {
  final double score;
  final bool aligned;
  final double dx;
  final double dy;
  const AlignmentResult({
    required this.score,
    required this.aligned,
    required this.dx,
    required this.dy,
  });
}

/// 현재 인물 박스와 목표 박스의 정렬을 IoU로 계산한다. 순수 함수.
AlignmentResult computeAlignment(
  PersonBox current,
  TargetBox target, {
  double alignThreshold = 0.6,
}) {
  final ix1 = math.max(current.left, target.x);
  final iy1 = math.max(current.top, target.y);
  final ix2 = math.min(current.right, target.right);
  final iy2 = math.min(current.bottom, target.bottom);
  final iw = math.max(0.0, ix2 - ix1);
  final ih = math.max(0.0, iy2 - iy1);
  final inter = iw * ih;
  final union =
      current.width * current.height + target.width * target.height - inter;
  final score = union <= 0 ? 0.0 : inter / union;
  final dx = target.centerX - current.centerX;
  final dy = target.centerY - current.centerY;
  return AlignmentResult(
    score: score,
    aligned: score >= alignThreshold,
    dx: dx,
    dy: dy,
  );
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/cloud/target_alignment_test.dart`
Expected: PASS (3개).

- [ ] **Step 5: Commit**

```bash
git add lib/cloud/target_alignment.dart test/cloud/target_alignment_test.dart
git commit -m "feat: add IoU target alignment computation (TDD)"
```

---

## Task 4: `TargetGuideOverlay` (목표 고스트 박스 + 이동 화살표)

**Files:**
- Create: `lib/cloud/target_guide_overlay.dart`

**Interfaces:**
- Consumes: `TargetBox`(Task 2), `PersonBox`(Phase 1), `AlignmentResult`(Task 3).
- Produces:
  - `class TargetGuideOverlay extends StatelessWidget { final TargetBox target; final PersonBox? current; final AlignmentResult? alignment; }`
  - 목표 박스(정렬 시 녹색, 아니면 빨강)를 그리고, `current`가 있고 미정렬이면 현재 중심→목표 중심 화살표를 그린다.

> CustomPainter는 단위 테스트가 어렵다 — 구현 + `dart analyze` + 기기 시각 검증. 색은 상수 알파(withOpacity 미사용, 린트 회피).

- [ ] **Step 1: 구현**

```dart
// lib/cloud/target_guide_overlay.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/person_box.dart';
import 'composition_advice.dart';
import 'target_alignment.dart';

/// 목표 고스트 박스 + 현재→목표 이동 화살표. 판단 없음(값을 그대로 시각화).
class TargetGuideOverlay extends StatelessWidget {
  final TargetBox target;
  final PersonBox? current;
  final AlignmentResult? alignment;
  const TargetGuideOverlay({
    super.key,
    required this.target,
    this.current,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TargetGuidePainter(target, current, alignment),
      size: Size.infinite,
    );
  }
}

class _TargetGuidePainter extends CustomPainter {
  final TargetBox target;
  final PersonBox? current;
  final AlignmentResult? alignment;
  _TargetGuidePainter(this.target, this.current, this.alignment);

  static const _good = Color(0xEE69F0AE);
  static const _warn = Color(0xEEFF5252);
  static const _goodFill = Color(0x2669F0AE);
  static const _warnFill = Color(0x26FF5252);

  @override
  void paint(Canvas canvas, Size size) {
    final aligned = alignment?.aligned ?? false;
    final line = aligned ? _good : _warn;
    final fill = aligned ? _goodFill : _warnFill;

    final rect = Rect.fromLTWH(
      target.x * size.width,
      target.y * size.height,
      target.width * size.width,
      target.height * size.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = line,
    );

    final cur = current;
    if (cur != null && !aligned) {
      final from = Offset(cur.centerX * size.width, cur.centerY * size.height);
      final to = Offset(
        target.centerX * size.width,
        target.centerY * size.height,
      );
      _drawArrow(canvas, from, to, line);
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, p);
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const head = 20.0;
    final a1 = angle + math.pi - 0.4;
    final a2 = angle + math.pi + 0.4;
    canvas.drawLine(
      to,
      to + Offset(math.cos(a1) * head, math.sin(a1) * head),
      p,
    );
    canvas.drawLine(
      to,
      to + Offset(math.cos(a2) * head, math.sin(a2) * head),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _TargetGuidePainter old) =>
      old.target != target ||
      old.current != current ||
      old.alignment != alignment;
}
```

- [ ] **Step 2: 분석 확인**

Run: `dart analyze lib/cloud/target_guide_overlay.dart`
Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
git add lib/cloud/target_guide_overlay.dart
git commit -m "feat: add TargetGuideOverlay (ghost box + move arrow)"
```

---

## Task 5: `AdviceMinimap` (현재→목표 개요도)

**Files:**
- Create: `lib/cloud/advice_minimap.dart`

**Interfaces:**
- Consumes: `TargetBox`(Task 2), `PersonBox`(Phase 1), `AlignmentResult`(Task 3).
- Produces:
  - `class AdviceMinimap extends StatelessWidget { final TargetBox target; final PersonBox? current; final AlignmentResult? alignment; }`
  - 고정 크기(90×160) 개요도: 프레임 테두리 + 목표 박스(녹/빨, 정렬 시 채움) + 현재 인물(회색) + 현재→목표 화살표.

> 구현 + `dart analyze` + 기기 시각 검증.

- [ ] **Step 1: 구현**

```dart
// lib/cloud/advice_minimap.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/person_box.dart';
import 'composition_advice.dart';
import 'target_alignment.dart';

/// 프레임 대비 현재 인물→목표 위치를 작은 개요도로 보여준다.
class AdviceMinimap extends StatelessWidget {
  final TargetBox target;
  final PersonBox? current;
  final AlignmentResult? alignment;
  const AdviceMinimap({
    super.key,
    required this.target,
    this.current,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(6),
      child: CustomPaint(
        painter: _MinimapPainter(target, current, alignment),
        size: Size.infinite,
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final TargetBox target;
  final PersonBox? current;
  final AlignmentResult? alignment;
  _MinimapPainter(this.target, this.current, this.alignment);

  static const _good = Color(0xEE69F0AE);
  static const _warn = Color(0xEEFF5252);
  static const _goodFill = Color(0x5569F0AE);
  static const _grey = Color(0xBBBBBBBB);

  @override
  void paint(Canvas canvas, Size size) {
    // 프레임 테두리
    final frame = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x88FFFFFF),
    );

    final aligned = alignment?.aligned ?? false;
    final line = aligned ? _good : _warn;

    // 목표 박스
    final t = Rect.fromLTWH(
      target.x * size.width,
      target.y * size.height,
      target.width * size.width,
      target.height * size.height,
    );
    if (aligned) canvas.drawRect(t, Paint()..color = _goodFill);
    canvas.drawRect(
      t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = line,
    );

    // 현재 인물 + 화살표
    final cur = current;
    if (cur != null) {
      final c = Rect.fromLTWH(
        cur.left * size.width,
        cur.top * size.height,
        cur.width * size.width,
        cur.height * size.height,
      );
      canvas.drawRect(
        c,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _grey,
      );
      if (!aligned) {
        final from = Offset(
          cur.centerX * size.width,
          cur.centerY * size.height,
        );
        final to = Offset(
          target.centerX * size.width,
          target.centerY * size.height,
        );
        final p = Paint()
          ..color = line
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, p);
        final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
        const head = 7.0;
        canvas.drawLine(
          to,
          to +
              Offset(
                math.cos(angle + math.pi - 0.4) * head,
                math.sin(angle + math.pi - 0.4) * head,
              ),
          p,
        );
        canvas.drawLine(
          to,
          to +
              Offset(
                math.cos(angle + math.pi + 0.4) * head,
                math.sin(angle + math.pi + 0.4) * head,
              ),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter old) =>
      old.target != target ||
      old.current != current ||
      old.alignment != alignment;
}
```

- [ ] **Step 2: 분석 확인**

Run: `dart analyze lib/cloud/advice_minimap.dart`
Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
git add lib/cloud/advice_minimap.dart
git commit -m "feat: add AdviceMinimap overview (frame/current/target/arrow)"
```

---

## Task 6: `CameraScreen` 배선 — 정렬 계산 + 오버레이·미니맵 표시

**Files:**
- Modify: `lib/screens/camera_screen.dart`

**Interfaces:**
- Consumes: `_advice`(CompositionAdvice, targetBox 포함), `_metrics.person`(PersonBox?, Phase 1), `computeAlignment`(Task 3), `TargetGuideOverlay`(Task 4), `AdviceMinimap`(Task 5).
- Produces: 추천 활성 시 프리뷰 위에 목표 오버레이 + 미니맵 표시, 매 프레임 정렬 갱신. 카드는 축소판 유지.

> 통합/기기 검증. 기존 구조 유지하며 아래를 추가한다. `_onFrame`이 매 프레임 `setState`로 `_metrics`를 갱신하므로 build가 재실행되어 정렬이 재계산된다.

- [ ] **Step 1: import 추가**

`lib/screens/camera_screen.dart` 상단 import 블록에 추가:
```dart
import '../cloud/target_alignment.dart';
import '../cloud/target_guide_overlay.dart';
import '../cloud/advice_minimap.dart';
```
(`import '../models/person_box.dart';`가 없으면 추가 — `_metrics.person` 타입 참조용. 이미 analysis_engine 경유로 들어와 있으면 생략 가능하나 명시 추가 권장.)

- [ ] **Step 2: build()에서 정렬 계산 + 위젯 배선**

`build()`의 `final hints = _metrics.activeHints;` 아래에 정렬 계산을 추가:
```dart
    final person = _metrics.person;
    final targetBox = _advice?.targetBox;
    final alignment = (targetBox != null && person != null)
        ? computeAlignment(person, targetBox)
        : null;
```

그리고 최상위 `Stack`의 children에서 `GuideOverlay(...)` 바로 **다음 줄**에 목표 오버레이와 미니맵을 삽입:
```dart
          if (targetBox != null)
            TargetGuideOverlay(
              target: targetBox,
              current: person,
              alignment: alignment,
            ),
          if (targetBox != null)
            Positioned(
              top: 100,
              right: 12,
              child: AdviceMinimap(
                target: targetBox,
                current: person,
                alignment: alignment,
              ),
            ),
```
(기존 `AdviceOverlay`(카드)·로딩 오버레이는 그대로 두어 Stack 맨 위에 유지 — 카드가 목표 오버레이 위에 보이도록.)

- [ ] **Step 3: 분석 + 전체 테스트 + 게이트**

Run: `dart analyze lib test 2>&1 | tail -5 && flutter test 2>&1 | tail -3 && bash tool/verify.sh 2>&1 | tail -3`
Expected: analyze 에러 없음, 순수 로직 테스트 전부 PASS, `verify.sh` 통과.

- [ ] **Step 4: 기기 수동 검증**

실기기에서 `flutter run` 후(추천 크레딧/App Check 준비된 상태):
- ✨ 구도 추천 → 프리뷰에 **목표 고스트 박스**와 **미니맵**이 뜬다.
- 인물이 잡히면 현재→목표 **화살표**가 보이고, 목표 박스에 인물을 맞추면 **녹색**으로 바뀐다.
- 미니맵에 프레임·현재(회색)·목표(녹/빨)·화살표가 실시간 갱신.
- 카드는 headline+rationale만 작게. 닫기 시 오버레이·미니맵도 사라짐.
- Phase 1 격자·수평·촬영 정상.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/camera_screen.dart
git commit -m "feat: wire target guide overlay and minimap into camera screen"
```

---

## Task 7: 백엔드 재배포

**Files:** 없음(배포 액션)

**Interfaces:**
- Consumes: Task 1의 새 계약이 배포된 함수.
- Produces: 라이브 `advise`가 targetBox를 반환.

> 앱과 백엔드 계약이 함께 바뀌므로, 앱(Task 2~6) 완료 후 배포해 둘을 일치시킨다.

- [ ] **Step 1: 빌드 + 배포**

Run:
```bash
cd functions && npm run build 2>&1 | tail -5 ; cd .. && firebase deploy --only functions:advise --force 2>&1 | tail -8
```
Expected: `functions[advise(us-central1)] Successful update operation.` + `Deploy complete!`

- [ ] **Step 2: 스모크 확인(선택)**

앱을 다시 실행해 ✨ 구도 추천 → 목표 박스가 뜨는지 확인. 실패 시 `firebase functions:log --only advise`로 파싱/응답 확인.

- [ ] **Step 3: (커밋 없음)**

배포는 코드 변경이 없으므로 커밋 불필요.

---

## Self-Review 결과

**Spec 커버리지:**
- §2 계약(targetBox 추가/directions 제거) → Task 1(백엔드), Task 2(앱) ✅
- §3 라이브 오버레이(고스트 박스·화살표·녹색) → Task 4 + Task 6 배선 ✅
- §4 미니맵 → Task 5 + Task 6 ✅
- §5 카드 축소 → Task 2(advice_overlay) ✅
- §6 정렬 로직(IoU, 임계값 0.6, dx/dy) → Task 3(TDD) ✅
- §7 모듈/흐름 → Task 1~6, 재배포 Task 7 ✅
- §8 견고성(인물 미감지 시 화살표 생략, targetBox 이상 시 null) → Task 2 fromJson null + Task 4/6 조건부 렌더 ✅

**플레이스홀더 스캔:** 없음. 각 코드 스텝 완전 코드 포함. ✅

**타입 일관성:** `TargetBox`(x,y,width,height + centerX/centerY/right/bottom) 앱(Task 2)·`computeAlignment`(Task 3)·오버레이(Task 4)·미니맵(Task 5)에서 일치. `AlignmentResult{score,aligned,dx,dy}` Task 3 정의 ↔ Task 4/5/6 소비 일치. 백엔드 `TargetBox`(Task 1)와 앱 `TargetBox`(Task 2)는 동일 필드. `CompositionAdvice.targetBox`는 앱에서 nullable, 백엔드에서 required(스키마 보장) — 앱은 방어적. `PersonBox` getter(left/top/right/bottom/centerX/centerY/width/height)는 Phase 1에 존재(확인됨). ✅
