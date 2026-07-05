# 순차 단계형 가이드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 동시에 뜨던 여러 가이드를 "한 번에 하나씩 지시하고, 맞추면 다음, 전부 맞으면 찍으세요"로 바꾼다.

**Architecture:** 순수 함수 `computeCurrentStep(GuideMetrics)`가 우선순위대로 가장 급한 단계 1개를 반환한다. `AnalysisEngine`이 모드별로 지표를 채우고(자연도 검출 사용), 오버레이는 현재 단계 하나만 렌더하며, 화면이 단계 전진/완료를 감지해 진동·소리를 낸다. 계산(순수) ↔ 렌더/플러그인 분리를 유지한다.

**Tech Stack:** Flutter(Dart), null-safety. 순수 로직은 `lib/analysis/`(플러그인 import 금지, TDD). 진동/소리는 Flutter 내장 `HapticFeedback`/`SystemSound`(새 패키지·에셋 없음).

## Global Constraints

- 좌표계: 정규화 0.0~1.0, 원점 좌상단(x→오른쪽, y→아래).
- 각도 단위: 도(degree). 수평 허용오차 ±1.5°, 눈높이/정면 허용오차 ±10°.
- 정렬 판정 문자열은 `'좋아요'`로 통일. 완료 문구는 `'찍으세요!'` 단일 상수.
- `lib/analysis/` 중 `person_detector.dart`·`analysis_engine.dart`·`object_detector.dart` 외 파일은 **순수 Dart**(Flutter/plugin import 금지).
- 정적 분석은 `dart analyze lib test`를 쓴다(한글 디렉토리명 때문에 `flutter analyze`는 크래시).
- 네트워크 0회·온디바이스 유지.
- 계산부(analysis/)는 엄격 TDD. 카메라/오버레이/플러그인은 구현 + 기기 수동 검증.
- 완료 게이트: `tool/verify.sh` 통과.

---

### Task 1: `ThirdsAlignment`에 현재 좌표 추가

위치 단계의 화살표(현재점→목표점)를 그리려면 정렬 결과가 입력받은 피사체 중심을 함께 담아야 한다.

**Files:**
- Modify: `lib/analysis/thirds.dart`
- Test: `test/analysis/thirds_test.dart`

**Interfaces:**
- Produces: `ThirdsAlignment { double currentX, currentY, targetX, targetY, distance, score; String hint }`, `computeThirds(double cx, double cy, {double alignedTolerance = 0.05}) -> ThirdsAlignment`

- [ ] **Step 1: 실패 테스트 추가**

`test/analysis/thirds_test.dart`의 `main()` 안, 마지막 test 뒤에 추가:

```dart
  test('입력한 피사체 중심을 currentX/currentY 로 그대로 담는다', () {
    final a = computeThirds(0.2, 0.7);
    expect(a.currentX, closeTo(0.2, 1e-9));
    expect(a.currentY, closeTo(0.7, 1e-9));
  });
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && flutter test test/analysis/thirds_test.dart`
Expected: FAIL — `currentX`/`currentY` getter 없음(컴파일 에러).

- [ ] **Step 3: 필드 추가**

`lib/analysis/thirds.dart`의 클래스와 생성자, 반환부를 아래처럼 바꾼다.

클래스 필드/생성자:
```dart
class ThirdsAlignment {
  final double currentX;
  final double currentY;
  final double targetX;
  final double targetY;
  final double distance;
  final double score;
  final String hint;
  const ThirdsAlignment({
    required this.currentX,
    required this.currentY,
    required this.targetX,
    required this.targetY,
    required this.distance,
    required this.score,
    required this.hint,
  });
}
```

반환부(`return ThirdsAlignment(...)`)에 현재 좌표를 추가:
```dart
  return ThirdsAlignment(
    currentX: cx,
    currentY: cy,
    targetX: bestX,
    targetY: bestY,
    distance: bestD,
    score: score,
    hint: hint,
  );
```

- [ ] **Step 4: 통과 확인**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && flutter test test/analysis/thirds_test.dart`
Expected: PASS (기존 4개 + 신규 1개).

- [ ] **Step 5: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/analysis/thirds.dart test/analysis/thirds_test.dart
git commit -m "feat(analysis): ThirdsAlignment에 현재 좌표(currentX/Y) 추가"
```

---

### Task 2: 모드별 각도 안내(`AngleGuide`)

각도 안내를 인물(눈높이)뿐 아니라 사물·자연(정면·수평)에도 쓸 수 있게 일반화한다. 시그니처 변경으로 깨지는 엔진 호출부는 이 태스크에서 최소 수정해 빌드를 초록으로 유지한다.

**Files:**
- Modify: `lib/analysis/angle_zoom.dart`
- Modify: `lib/analysis/analysis_engine.dart` (호출부 3곳만)
- Test: `test/analysis/angle_zoom_test.dart`

**Interfaces:**
- Produces: `enum AngleGuide { none, eyeLevel, frontal }`, `computeAngle(double pitchDegrees, {AngleGuide guide = AngleGuide.none, double tolerance = 10}) -> AngleAdvice`

- [ ] **Step 1: 테스트 교체(각도 그룹) — 실패 테스트**

`test/analysis/angle_zoom_test.dart`의 `group('angle advice', ...)` 블록 전체를 아래로 교체(다른 그룹은 그대로 둔다):

```dart
  group('angle advice', () {
    test('guide=none 이면 안내 없음', () {
      expect(computeAngle(40, guide: AngleGuide.none).hint, '');
    });
    test('인물(eyeLevel) 눈높이면 안내 없음', () {
      expect(computeAngle(0, guide: AngleGuide.eyeLevel).hint, '');
    });
    test('인물(eyeLevel) 위를 향하면 눈높이로 내리라고', () {
      expect(computeAngle(30, guide: AngleGuide.eyeLevel).hint, '카메라를 눈높이로 내리세요');
    });
    test('인물(eyeLevel) 아래를 향하면 눈높이로 올리라고', () {
      expect(computeAngle(-30, guide: AngleGuide.eyeLevel).hint, '카메라를 눈높이로 올리세요');
    });
    test('정면(frontal) 위를 향하면 수평으로 내리라고', () {
      expect(computeAngle(30, guide: AngleGuide.frontal).hint, '카메라를 수평으로 내리세요');
    });
    test('정면(frontal) 아래를 향하면 수평으로 올리라고', () {
      expect(computeAngle(-30, guide: AngleGuide.frontal).hint, '카메라를 수평으로 올리세요');
    });
    test('정면(frontal) 수평이면 안내 없음', () {
      expect(computeAngle(0, guide: AngleGuide.frontal).hint, '');
    });
  });
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && flutter test test/analysis/angle_zoom_test.dart`
Expected: FAIL — `AngleGuide` 미정의.

- [ ] **Step 3: `computeAngle` 재작성**

`lib/analysis/angle_zoom.dart`의 `computeAngle` 함수 전체를 아래로 교체(위의 `AngleAdvice`/`ZoomAdvice`/`computePitch`/`computeZoom`은 그대로):

```dart
enum AngleGuide { none, eyeLevel, frontal }

/// 촬영 각도를 모드에 맞게 안내한다.
/// eyeLevel(인물): 눈높이 기준. frontal(사물·자연): 정면·수평 기준.
AngleAdvice computeAngle(
  double pitchDegrees, {
  AngleGuide guide = AngleGuide.none,
  double tolerance = 10,
}) {
  String hint = '';
  if (guide == AngleGuide.eyeLevel) {
    if (pitchDegrees > tolerance) {
      hint = '카메라를 눈높이로 내리세요';
    } else if (pitchDegrees < -tolerance) {
      hint = '카메라를 눈높이로 올리세요';
    }
  } else if (guide == AngleGuide.frontal) {
    if (pitchDegrees > tolerance) {
      hint = '카메라를 수평으로 내리세요';
    } else if (pitchDegrees < -tolerance) {
      hint = '카메라를 수평으로 올리세요';
    }
  }
  return AngleAdvice(pitchDegrees: pitchDegrees, hint: hint);
}
```

- [ ] **Step 4: 엔진 호출부 최소 수정(빌드 유지)**

`lib/analysis/analysis_engine.dart`에서 `computeAngle(pitch, hasPerson: ...)` 3곳을 바꾼다:
- 인물 브랜치 `computeAngle(pitch, hasPerson: true)` → `computeAngle(pitch, guide: AngleGuide.eyeLevel)`
- 나머지 `computeAngle(pitch, hasPerson: false)` 2곳 → `computeAngle(pitch, guide: AngleGuide.none)`

(Task 3에서 사물/자연을 frontal로 다시 손본다. 지금은 기존 동작 유지가 목적.)

- [ ] **Step 5: 통과 확인**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && flutter test test/analysis/angle_zoom_test.dart test/analysis/analysis_engine_test.dart test/analysis/analysis_engine_mode_test.dart`
Expected: PASS (angle 그룹 신규 7개 포함, 엔진 테스트 기존대로).

- [ ] **Step 6: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/analysis/angle_zoom.dart lib/analysis/analysis_engine.dart test/analysis/angle_zoom_test.dart
git commit -m "feat(analysis): 모드별 각도 안내(AngleGuide none/eyeLevel/frontal)"
```

---

### Task 3: `AnalysisEngine` 모드별 지표 확장(자연 검출·사물 잘림·정면 각도)

자연도 검출된 주제로 거리·위치를 안내하고, 사물에 잘림·정면 각도를, 자연에 정면 각도를 채운다.

**Files:**
- Modify: `lib/analysis/analysis_engine.dart`
- Test: `test/analysis/analysis_engine_mode_test.dart`

**Interfaces:**
- Consumes: `computeAngle(pitch, {AngleGuide guide})` (Task 2), `computeThirds`, `computeZoom`, `computeHeadroom`, `detectCrop`.
- Produces: `AnalysisEngine.buildMetrics({PersonBox? person, PersonBox? face, required SensorSample sensor, ShootingMode mode}) -> GuideMetrics`

- [ ] **Step 1: 모드 테스트 교체 — 실패 테스트**

`test/analysis/analysis_engine_mode_test.dart`에서 자연/사물 테스트 2개를 아래로 교체하고, 자연 각도 테스트 1개를 추가한다.

자연 테스트(기존 '자연 모드: ... 모두 생략' 대체):
```dart
  test('자연 모드: 주제가 잡히면 person/thirds/zoom 채우고 headroom/crop 은 생략', () {
    final m = engine.buildMetrics(
      person: _box,
      face: _box,
      sensor: _sensor,
      mode: ShootingMode.nature,
    );
    expect(m.person, isNotNull);
    expect(m.thirds, isNotNull);
    expect(m.zoom, isNotNull);
    expect(m.headroom, isNull);
    expect(m.crop, isNull);
  });

  test('자연 모드: 주제 미검출이면 thirds/zoom 은 null', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: _sensor,
      mode: ShootingMode.nature,
    );
    expect(m.thirds, isNull);
    expect(m.zoom, isNull);
  });

  test('자연 모드: 앞뒤로 기울면 정면(수평) 각도 안내', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: const SensorSample(accelX: 0, accelY: 9.8, accelZ: 9.8), // pitch≈45
      mode: ShootingMode.nature,
    );
    expect(m.angle.hint, '카메라를 수평으로 내리세요');
  });
```

사물 테스트(기존 '사물 모드: ... headroom/crop 은 생략' 대체):
```dart
  test('사물 모드: person/thirds/zoom/crop 채우고 headroom 은 생략', () {
    final m = engine.buildMetrics(
      person: _box,
      face: _box,
      sensor: _sensor,
      mode: ShootingMode.object,
    );
    expect(m.person, isNotNull);
    expect(m.thirds, isNotNull);
    expect(m.zoom, isNotNull);
    expect(m.crop, isNotNull);
    expect(m.headroom, isNull);
  });
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && flutter test test/analysis/analysis_engine_mode_test.dart`
Expected: FAIL — 자연이 thirds null, 사물이 crop null(현재 동작).

- [ ] **Step 3: `buildMetrics` 재작성**

`lib/analysis/analysis_engine.dart`의 `import` 상단에 `angle_zoom.dart`가 이미 있으니 그대로 두고, `buildMetrics` 본문 전체를 아래로 교체:

```dart
  GuideMetrics buildMetrics({
    PersonBox? person,
    PersonBox? face,
    required SensorSample sensor,
    ShootingMode mode = ShootingMode.person,
  }) {
    final tilt = computeTilt(sensor.accelX, sensor.accelY);
    final pitch = computePitch(sensor.accelY, sensor.accelZ);

    // 자연: 수평 + 앞뒤 기울기(항상). 주제가 잡히면 거리·위치도.
    if (mode == ShootingMode.nature) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, guide: AngleGuide.frontal),
        person: person,
        thirds: person == null
            ? null
            : computeThirds(person.centerX, person.centerY),
        zoom: person == null ? null : computeZoom(person.height),
      );
    }

    // 대상 미감지(인물/사물): 수평만.
    if (person == null) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, guide: AngleGuide.none),
      );
    }

    // 사물: 수평·잘림·거리·위치·정면 각도. 헤드룸 없음.
    if (mode == ShootingMode.object) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, guide: AngleGuide.frontal),
        person: person,
        thirds: computeThirds(person.centerX, person.centerY),
        crop: detectCrop(person),
        zoom: computeZoom(person.height),
      );
    }

    // 인물(기본): 전체 지표. 3분할·잘림은 얼굴 기준.
    final cropBox = face ?? person;
    final thirdsBox = face ?? person;
    return GuideMetrics(
      tilt: tilt,
      angle: computeAngle(pitch, guide: AngleGuide.eyeLevel),
      person: person,
      thirds: computeThirds(thirdsBox.centerX, thirdsBox.centerY),
      headroom: computeHeadroom(person),
      crop: detectCrop(cropBox),
      zoom: computeZoom(person.height),
    );
  }
```

- [ ] **Step 4: 통과 확인**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && flutter test test/analysis/`
Expected: PASS (모든 analysis 테스트).

- [ ] **Step 5: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/analysis/analysis_engine.dart test/analysis/analysis_engine_mode_test.dart
git commit -m "feat(analysis): 자연 검출 지표·사물 잘림·모드별 정면 각도"
```

---

### Task 4: `computeCurrentStep` — 단계 선택 순수 로직

우선순위대로 가장 급한 단계 하나를 반환한다. 이 플랜의 핵심.

**Files:**
- Create: `lib/analysis/guide_step.dart`
- Test: `test/analysis/guide_step_test.dart`

**Interfaces:**
- Consumes: `GuideMetrics`(tilt/crop/zoom/thirds/headroom/angle), `ThirdsAlignment`(current/target 좌표, hint).
- Produces: `enum GuideStepKind { level, crop, distance, position, headroom, angle, ready }`, `class GuideStep { GuideStepKind kind; String message; ThirdsAlignment? target }`, `computeCurrentStep(GuideMetrics) -> GuideStep`.

- [ ] **Step 1: 실패 테스트 작성**

`test/analysis/guide_step_test.dart` 생성:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/models/shooting_mode.dart';
import 'package:ttongson_camera/analysis/analysis_engine.dart';
import 'package:ttongson_camera/analysis/guide_step.dart';

void main() {
  final engine = AnalysisEngine(null);
  const level = SensorSample(accelX: 0, accelY: 9.8, accelZ: 0); // roll≈0, pitch≈0
  const tilted = SensorSample(accelX: 9.8, accelY: 9.8, accelZ: 0); // roll≈45

  test('수평이 안 맞으면 level 단계가 최우선', () {
    final m = engine.buildMetrics(person: null, sensor: tilted);
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.level);
    expect(s.message, '왼쪽을 내리세요');
  });

  test('인물이 프레임 밖으로 잘리면 수평 다음 crop 단계', () {
    // 수평 OK, 얼굴이 위/왼쪽에 닿아 잘림.
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.0, top: 0.0, width: 0.3, height: 0.5),
      face: const PersonBox(left: 0.0, top: 0.0, width: 0.2, height: 0.15),
      sensor: level,
    );
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.crop);
  });

  test('피사체가 작으면 distance 단계', () {
    // 수평 OK, 잘림 없음, 얼굴 작음(줌 힌트 발생), 위치는 교차점.
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.28, top: 0.30, width: 0.1, height: 0.10),
      face: const PersonBox(left: 0.283, top: 0.283, width: 0.1, height: 0.10),
      sensor: level,
    );
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.distance);
  });

  test('위치가 어긋나면 position 단계 + 현재/목표 좌표 포함', () {
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.75, top: 0.55, width: 0.2, height: 0.60),
      face: const PersonBox(left: 0.80, top: 0.55, width: 0.1, height: 0.12),
      sensor: level,
    );
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.position);
    expect(s.target, isNotNull);
    expect(s.target!.currentX, closeTo(0.85, 1e-9)); // face centerX
  });

  test('모든 조건이 좋으면 ready + 찍으세요!', () {
    // 얼굴이 (1/3,1/3) 교차점, person 헤드룸(top 0.10)·크기(height 0.65) 적정,
    // 잘림 없음, 수평, 눈높이(pitch 0).
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.28, top: 0.10, width: 0.1, height: 0.65),
      face: const PersonBox(left: 0.283, top: 0.283, width: 0.1, height: 0.10),
      sensor: level,
    );
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.ready);
    expect(s.message, '찍으세요!');
  });

  test('자연 모드에서 주제 미검출이면 수평만 맞으면 ready', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: level,
      mode: ShootingMode.nature,
    );
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.ready);
  });
}
```

> 참고: 위 박스 값은 각 지표 임계를 만족/위반하도록 고른 것이다 — 헤드룸(person.top 0.05~0.15), 줌(person.height 0.5~0.8), 위치(얼굴 중심 ±0.05 of 1/3·2/3), 잘림(margin 0.02).

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && flutter test test/analysis/guide_step_test.dart`
Expected: FAIL — `guide_step.dart`/`computeCurrentStep` 미정의.

- [ ] **Step 3: 구현**

`lib/analysis/guide_step.dart` 생성:

```dart
// lib/analysis/guide_step.dart
// 순수 Dart — Flutter/plugin import 금지.
import 'guide_metrics.dart';
import 'thirds.dart';

enum GuideStepKind { level, crop, distance, position, headroom, angle, ready }

/// 지금 사용자가 해야 할 단 하나의 행동.
class GuideStep {
  final GuideStepKind kind;
  final String message;
  final ThirdsAlignment? target; // position 단계에서만 채움(현재점·목표점)
  const GuideStep({required this.kind, required this.message, this.target});
}

const _aligned = '좋아요';
const _readyMessage = '찍으세요!';

/// 우선순위대로 가장 급한(활성) 단계 하나를 고른다. 없으면 ready.
GuideStep computeCurrentStep(GuideMetrics m) {
  if (!m.tilt.isLevel) {
    return GuideStep(kind: GuideStepKind.level, message: m.tilt.hint);
  }
  final crop = m.crop;
  if (crop != null && crop.any) {
    return GuideStep(kind: GuideStepKind.crop, message: crop.message);
  }
  final zoom = m.zoom;
  if (zoom != null && zoom.hint.isNotEmpty) {
    return GuideStep(kind: GuideStepKind.distance, message: zoom.hint);
  }
  final thirds = m.thirds;
  if (thirds != null && thirds.hint != _aligned) {
    return GuideStep(
      kind: GuideStepKind.position,
      message: '여기로 옮기세요',
      target: thirds,
    );
  }
  final headroom = m.headroom;
  if (headroom != null && headroom.hint.isNotEmpty) {
    return GuideStep(kind: GuideStepKind.headroom, message: headroom.hint);
  }
  if (m.angle.hint.isNotEmpty) {
    return GuideStep(kind: GuideStepKind.angle, message: m.angle.hint);
  }
  return const GuideStep(kind: GuideStepKind.ready, message: _readyMessage);
}
```

- [ ] **Step 4: 통과 확인 (값 조정 포함)**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && flutter test test/analysis/guide_step_test.dart`
Expected: PASS. 만약 특정 케이스가 의도 kind와 다르면, 해당 테스트의 PersonBox/face 값을 조정한다(각 지표의 임계: 헤드룸 person.top 0.05~0.15, 줌 person.height 0.5~0.8, 위치 얼굴중심 ±0.05 of 1/3·2/3, 잘림 margin 0.02). 구현은 바꾸지 않는다.

- [ ] **Step 5: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/analysis/guide_step.dart test/analysis/guide_step_test.dart
git commit -m "feat(analysis): computeCurrentStep 단계 선택 로직"
```

---

### Task 5: 자연 모드에서도 객체 검출 실행 (배선)

자연 모드가 검출 지표를 받으려면 프레임 처리에서 객체 검출을 돌려야 한다. 렌더/플러그인 배선이라 기기 수동 검증.

**Files:**
- Modify: `lib/screens/camera_screen.dart` (`_onFrame`)

**Interfaces:**
- Consumes: `_faceDetector`, `_objectDetector` (`PersonDetector`), `AnalysisEngine.buildMetrics`.

- [ ] **Step 1: `_onFrame` 검출 분기 수정**

`lib/screens/camera_screen.dart`의 `_onFrame` 안에서 검출 분기를 아래처럼 바꾼다. 인물은 얼굴, 그 외(사물·자연)는 객체 검출.

교체 전:
```dart
      final mode = _mode;
      Detection? detection;
      if (mode == ShootingMode.person) {
        detection = await _faceDetector.detect(
          image,
          _camera.sensorOrientation,
        );
      } else if (mode == ShootingMode.object) {
        detection = await _objectDetector.detect(
          image,
          _camera.sensorOrientation,
        );
      }
      // 자연 모드: 감지 없음.
```
교체 후:
```dart
      final mode = _mode;
      Detection? detection;
      if (mode == ShootingMode.person) {
        detection = await _faceDetector.detect(
          image,
          _camera.sensorOrientation,
        );
      } else {
        // 사물·자연: 객체 검출로 주제 박스 확보(자연은 미검출 시 null).
        detection = await _objectDetector.detect(
          image,
          _camera.sensorOrientation,
        );
      }
```

- [ ] **Step 2: 정적 분석**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && dart analyze lib test`
Expected: No issues found!

- [ ] **Step 3: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/screens/camera_screen.dart
git commit -m "feat: 자연 모드에서도 객체 검출 실행"
```

---

### Task 6: 오버레이 — 현재 단계 하나만 렌더

격자·수평선은 유지하고, 위치 단계일 때 현재 마커 + 화살표 + 목표 링을 그린다. 인물 박스는 단계에 따라 색을 바꾼다. 판단 로직은 없다(현재 단계는 주입받음). 렌더라서 기기 수동 검증.

**Files:**
- Modify: `lib/overlay/guide_overlay.dart`

**Interfaces:**
- Consumes: `GuideMetrics`, `GuideStep`/`GuideStepKind`, `ThirdsAlignment`.
- Produces: `GuideOverlay({required GuideMetrics metrics, required GuideStep step, bool showGrid})`.

- [ ] **Step 1: `guide_overlay.dart` 재작성**

`lib/overlay/guide_overlay.dart` 전체를 아래로 교체:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analysis/guide_metrics.dart';
import '../analysis/guide_step.dart';
import '../analysis/thirds.dart';

class GuideOverlay extends StatelessWidget {
  final GuideMetrics metrics;
  final GuideStep step;
  final bool showGrid;
  const GuideOverlay({
    super.key,
    required this.metrics,
    required this.step,
    this.showGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GuidePainter(metrics: metrics, step: step, showGrid: showGrid),
      size: Size.infinite,
    );
  }
}

class GuidePainter extends CustomPainter {
  final GuideMetrics metrics;
  final GuideStep step;
  final bool showGrid;
  GuidePainter({
    required this.metrics,
    required this.step,
    required this.showGrid,
  });

  static const _good = Color(0xAA69F0AE); // 초록
  static const _warn = Color(0xAAFF5252); // 빨강
  static const _amber = Color(0xEEFFC107); // 목표 안내
  static const _neutral = Color(0x88FFFFFF);
  static const _marker = Color(0xEEFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) _paintGrid(canvas, size);
    _paintLevel(canvas, size);
    _paintPerson(canvas, size);
    if (step.kind == GuideStepKind.position && step.target != null) {
      _paintPosition(canvas, size, step.target!);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _neutral
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), p);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), p);
    }
  }

  void _paintLevel(Canvas canvas, Size size) {
    final level = metrics.tilt.isLevel;
    final p = Paint()
      ..color = level ? _good : _warn
      ..strokeWidth = 3;
    final cy = size.height / 2;
    final cx = size.width / 2;
    final rad = metrics.tilt.rollDegrees * math.pi / 180;
    final half = size.width * 0.15;
    final dxr = half * math.cos(rad);
    final dyr = half * math.sin(rad);
    canvas.drawLine(Offset(cx - dxr, cy - dyr), Offset(cx + dxr, cy + dyr), p);
  }

  void _paintPerson(Canvas canvas, Size size) {
    final person = metrics.person;
    if (person == null) return;
    // 잘림 단계면 빨강, 모두 통과(ready)면 초록, 그 외 중립.
    final color = step.kind == GuideStepKind.crop
        ? _warn
        : step.kind == GuideStepKind.ready
        ? _good
        : _neutral;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = step.kind == GuideStepKind.ready ? 3 : 2
      ..color = color;
    canvas.drawRect(
      Rect.fromLTWH(
        person.left * size.width,
        person.top * size.height,
        person.width * size.width,
        person.height * size.height,
      ),
      p,
    );
  }

  void _paintPosition(Canvas canvas, Size size, ThirdsAlignment t) {
    final aligned = t.hint == '좋아요';
    final tgt = Offset(t.targetX * size.width, t.targetY * size.height);
    final color = aligned ? _good : _amber;
    // 목표 링 + 중앙 점
    canvas.drawCircle(
      tgt,
      aligned ? 22 : 16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
    canvas.drawCircle(tgt, 4, Paint()..color = color);
    if (aligned) return;
    // 현재 마커 + 화살표(현재 → 목표)
    final cur = Offset(t.currentX * size.width, t.currentY * size.height);
    canvas.drawCircle(cur, 6, Paint()..color = _marker);
    _paintArrow(canvas, cur, tgt, color);
  }

  void _paintArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, p);
    final angle = (to - from).direction;
    const headLen = 16.0;
    const spread = 0.5; // rad
    canvas.drawLine(to, to - Offset.fromDirection(angle - spread, headLen), p);
    canvas.drawLine(to, to - Offset.fromDirection(angle + spread, headLen), p);
  }

  @override
  bool shouldRepaint(covariant GuidePainter old) =>
      old.metrics != metrics || old.step != step || old.showGrid != showGrid;
}
```

- [ ] **Step 2: 정적 분석**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && dart analyze lib test`
Expected: `camera_screen.dart`에서 `GuideOverlay`에 `step` 인자가 없다는 에러가 날 수 있다 → Task 7에서 배선하므로, 이 태스크 단독 분석은 오버레이 파일만 확인:
Run: `dart analyze lib/overlay/guide_overlay.dart`
Expected: No issues found! (경고 수준 제외)

- [ ] **Step 3: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/overlay/guide_overlay.dart
git commit -m "feat(overlay): 현재 단계 하나만 렌더(화살표·목표 링·단계별 색)"
```

---

### Task 7: 화면 배선 — 단계 상태·진동·소리·배너

현재 단계를 상태로 들고, 단계 전진/완료 시 진동·소리를 낸다. 상단 다중 힌트 스택을 제거하고 단일 문구 배너 + "찍으세요!" 배너로 바꾼다. 오버레이에 step을 넘긴다. 렌더/플러그인 배선이라 기기 수동 검증.

**Files:**
- Modify: `lib/screens/camera_screen.dart`

**Interfaces:**
- Consumes: `computeCurrentStep`(Task 4), `GuideStep`/`GuideStepKind`, `GuideOverlay({metrics, step, showGrid})`(Task 6), `HapticFeedback`/`SystemSound`(`package:flutter/services.dart`).

- [ ] **Step 1: services import 추가**

`lib/screens/camera_screen.dart` 상단 import에 추가(이미 있으면 생략):
```dart
import 'package:flutter/services.dart';
import '../analysis/guide_step.dart';
```

- [ ] **Step 2: 상태 필드 추가**

`_CameraScreenState` 필드부(예: `bool _processing = false;` 근처)에 추가:
```dart
  GuideStep _step = const GuideStep(kind: GuideStepKind.level, message: '');
  GuideStepKind? _prevStepKind;

  static const _stepOrder = <GuideStepKind>[
    GuideStepKind.level,
    GuideStepKind.crop,
    GuideStepKind.distance,
    GuideStepKind.position,
    GuideStepKind.headroom,
    GuideStepKind.angle,
    GuideStepKind.ready,
  ];
```

- [ ] **Step 3: 피드백 헬퍼 추가**

`_CameraScreenState` 안에 메서드 추가:
```dart
  /// 단계가 앞으로 전진했을 때만 1회 진동+소리. 후퇴는 무음.
  void _handleStepFeedback(GuideStepKind kind) {
    final prev = _prevStepKind;
    _prevStepKind = kind;
    if (prev == null || kind == prev) return;
    if (_stepOrder.indexOf(kind) <= _stepOrder.indexOf(prev)) return;
    if (kind == GuideStepKind.ready) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } else {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    }
  }
```

- [ ] **Step 4: `_onFrame`에서 단계 계산·피드백**

`_onFrame` 안 `final m = _engine.buildMetrics(...)` 다음, `setState` 부분을 아래로 교체:
```dart
      final step = computeCurrentStep(m);
      _handleStepFeedback(step.kind);
      if (mounted) {
        setState(() {
          _metrics = m;
          _step = step;
        });
      }
```

- [ ] **Step 5: 모드 변경 시 피드백 상태 초기화**

`_onModeChanged`의 `setState(() { ... })` 안(또는 직후)에 추가하여 모드 전환 시 헛울림 방지:
```dart
      _prevStepKind = null;
      _step = const GuideStep(kind: GuideStepKind.level, message: '');
```

- [ ] **Step 6: 오버레이에 step 전달**

build의 `GuideOverlay(metrics: _metrics, showGrid: _showGrid)` 를:
```dart
GuideOverlay(metrics: _metrics, step: _step, showGrid: _showGrid),
```

- [ ] **Step 7: 상단 다중 힌트 → 단일 배너로 교체**

build에서 기존 상단 힌트 스택(`Positioned(top: 48, ... for (final h in hints) ...)`) 전체를 아래로 교체. (상단의 `final hints = _metrics.activeHints;` 줄은 더 이상 안 쓰면 제거)
```dart
          if (_step.kind != GuideStepKind.ready && _step.message.isNotEmpty)
            Positioned(
              top: 48,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _step.message,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
          if (_step.kind == GuideStepKind.ready)
            Positioned(
              top: 44,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC2E7D32),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      '✓ 찍으세요!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
```

- [ ] **Step 8: 정적 분석**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && dart analyze lib test`
Expected: No issues found! (미사용 `hints`/`activeHints` 경고가 있으면 해당 참조 제거)

- [ ] **Step 9: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/screens/camera_screen.dart
git commit -m "feat: 단계형 가이드 배선 — 단계 상태·진동·소리·배너"
```

---

### Task 8: 최종 검증 (게이트)

**Files:** (없음 — 게이트만)

- [ ] **Step 1: 전체 게이트**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라 && tool/verify.sh`
Expected: `✅ verify 통과` (format + `dart analyze` + 모든 테스트).

- [ ] **Step 2: 기기 수동 검증 체크리스트**

`flutter run` 후 확인:
- 인물: 수평→(잘림)→거리→얼굴 위치(화살표로 링에 유도)→머리공간→눈높이 순으로 **하나씩** 지시. 맞출 때마다 진동+소리, 초록. 전부 맞으면 "✓ 찍으세요!".
- 사물: 수평→(잘림)→거리→위치→정면 각도→찍으세요.
- 자연: 주제가 잡히면 위치·거리 안내, 안 잡히면 수평(+앞뒤 기울기)만 맞추면 찍으세요.
- 위치 화살표가 프리뷰 속 피사체·목표에 맞게 정렬되는지(세로 기준).

- [ ] **Step 3: (해당 시) 게이트 통과 사실만 보고**

수동 검증 결과와 함께 완료를 보고한다. 실패 항목이 있으면 그대로 보고한다.

---

## Self-Review (작성자 확인 완료)

- **스펙 커버리지:** 우선순위(2.1)→Task 4, 모드별 단계(2.2)→Task 3+4, 화살표 데이터(2.3)→Task 1, 성공 신호(3)→Task 7, 화면 구성(4)→Task 6+7, 아키텍처(5)→Task 1~7, 테스트(6)→각 Task, 자연 검출→Task 3+5. 누락 없음.
- **플레이스홀더:** 각 코드 스텝에 실제 코드 포함. Task 4 Step 4에 값 조정 안내가 있으나 구현이 아닌 테스트 픽스처 튜닝이라 허용.
- **타입 일관성:** `GuideStep{kind,message,target}`, `GuideStepKind`, `computeCurrentStep`, `ThirdsAlignment{currentX,currentY,targetX,targetY}`, `AngleGuide{none,eyeLevel,frontal}`, `GuideOverlay({metrics,step,showGrid})` — 태스크 간 시그니처 일치 확인.
