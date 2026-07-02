# 똥손카메라 Phase 0 + Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 네트워크 없이 동작하는 실시간 촬영 가이드 앱을 만든다 — 카메라 프리뷰 위에 격자·수평·인물 포즈/위치·각도·줌 가이드를 실시간 표시하고 사진을 찍어 저장한다.

**Architecture:** Flutter 앱. `CameraService`가 프리뷰와 프레임 스트림을 제공하고, 순수 계산 함수들(tilt/thirds/headroom/crop/angle/zoom)이 프레임·센서 데이터를 `GuideMetrics`로 변환하며, `AnalysisEngine`이 이들을 조립하고, `GuideOverlay`(CustomPainter)가 지표를 화면에 그린다. 판단 로직(계산)과 렌더링을 철저히 분리해 계산부는 순수 함수로 TDD한다.

**Tech Stack:** Flutter, Dart, `camera`, `sensors_plus`, `google_ml_kit`(pose/face), `path_provider`, `gallery_saver` (또는 `image_gallery_saver`).

## Global Constraints

- 언어/프레임워크: **Flutter (Dart)**, null-safety 사용.
- 패키지명: **`ttongson_camera`**.
- **Phase 0+1 기능은 네트워크 호출 0회** — 모든 분석은 온디바이스.
- 좌표계 규약: 모든 인물/포인트 좌표는 **정규화(0.0~1.0)**, 원점은 **좌상단**(x→오른쪽, y→아래).
- 각도 단위: **도(degree)**. 수평(level) 허용오차 기본 **±1.5°**.
- 순수 계산 파일(`lib/analysis/*.dart` 중 detector·engine 제외)은 **Flutter/plugin import 금지** — 순수 Dart만(테스트 용이성).
- 커밋 메시지: Conventional Commits (`feat:`, `test:`, `chore:`).
- 테스트 실행: `flutter test`.

---

## File Structure

```
lib/
  main.dart                        # 앱 엔트리, 권한 요청, CameraScreen 진입
  models/
    person_box.dart                # PersonBox (정규화 bbox)
  analysis/
    tilt.dart                      # TiltInfo, computeTilt() [순수]
    thirds.dart                    # ThirdsAlignment, computeThirds() [순수]
    headroom.dart                  # HeadroomAdvice, computeHeadroom() [순수]
    crop.dart                      # CropWarning, detectCrop() [순수]
    angle_zoom.dart                # AngleAdvice/ZoomAdvice, computeAngle()/computeZoom() [순수]
    guide_metrics.dart             # GuideMetrics 집계 모델 [순수]
    person_detector.dart           # PersonDetector 인터페이스 + MlKitPersonDetector 구현
    analysis_engine.dart           # AnalysisEngine: 프레임+센서 -> GuideMetrics 스트림
  camera/
    camera_service.dart            # CameraService: 프리뷰/프레임스트림/촬영/저장
  overlay/
    guide_overlay.dart             # GuidePainter(CustomPainter) + GuideOverlay 위젯
  screens/
    camera_screen.dart             # 전체 화면 조립(프리뷰+오버레이+촬영버튼)
test/
  analysis/
    tilt_test.dart
    thirds_test.dart
    headroom_test.dart
    crop_test.dart
    angle_zoom_test.dart
    analysis_engine_test.dart
```

파일 분리 원칙: 각 순수 계산 파일은 자신의 결과 모델 클래스와 계산 함수 하나만 담는다(단일 책임). `guide_metrics.dart`는 이들을 조립하는 집계 모델만 담는다.

---

## Task 1: 프로젝트 세팅 및 의존성

**Files:**
- Create: `pubspec.yaml` (Flutter 기본 생성 후 수정)
- Create: 프로젝트 스캐폴드 전체 (`flutter create`)
- Modify: `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` (권한)

**Interfaces:**
- Consumes: 없음
- Produces: 빌드 가능한 빈 Flutter 앱 + 의존성 설치 완료.

- [ ] **Step 1: Flutter 프로젝트 생성**

프로젝트 루트(`/Users/soonbok/Projects/junicode/똥손카메라`)에서 실행:
```bash
flutter create --org com.junicode --project-name ttongson_camera .
```
Expected: `android/`, `ios/`, `lib/main.dart`, `pubspec.yaml` 생성.

- [ ] **Step 2: 의존성 추가**

Run:
```bash
flutter pub add camera sensors_plus google_ml_kit path_provider gallery_saver
```
Expected: `pubspec.yaml`의 `dependencies:`에 위 패키지들이 추가되고 `flutter pub get` 성공.

- [ ] **Step 3: 카메라/저장 권한 선언**

`android/app/src/main/AndroidManifest.xml`의 `<manifest>` 안, `<application>` 위에 추가:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
```

`ios/Runner/Info.plist`의 `<dict>` 안에 추가:
```xml
<key>NSCameraUsageDescription</key>
<string>촬영 가이드를 위해 카메라를 사용합니다.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>촬영한 사진을 갤러리에 저장합니다.</string>
```

또한 `android/app/build.gradle`의 `minSdkVersion`을 `21` 이상으로 설정(camera/ml_kit 요구).

- [ ] **Step 4: 빌드 확인**

Run: `flutter analyze`
Expected: 에러 없음(경고는 허용). 이어서 `flutter build apk --debug` 또는 연결된 기기에서 `flutter run`으로 기본 앱 실행 확인.

- [ ] **Step 5: Commit**

```bash
git init
git add -A
git commit -m "chore: scaffold Flutter project with camera/ml_kit deps"
```

---

## Task 2: PersonBox 모델

**Files:**
- Create: `lib/models/person_box.dart`
- Test: (Task 3~5에서 간접 사용; 자체 테스트 불필요 — 순수 값 객체)

**Interfaces:**
- Consumes: 없음
- Produces: `PersonBox(left, top, width, height)` 정규화 bbox. getter `right`, `bottom`, `centerX`, `centerY`.

- [ ] **Step 1: PersonBox 작성**

```dart
// lib/models/person_box.dart
/// 정규화(0.0~1.0) 좌표계의 인물 경계 상자. 원점은 좌상단.
class PersonBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const PersonBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}
```

- [ ] **Step 2: 분석 확인**

Run: `flutter analyze lib/models/person_box.dart`
Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
git add lib/models/person_box.dart
git commit -m "feat: add PersonBox normalized bounding box model"
```

---

## Task 3: 수평/기울기 계산 (tilt) — TDD

**Files:**
- Create: `lib/analysis/tilt.dart`
- Test: `test/analysis/tilt_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `class TiltInfo { final double rollDegrees; final bool isLevel; final String hint; }`
  - `TiltInfo computeTilt(double accelX, double accelY, {double levelToleranceDeg = 1.5})`
  - 규약: 세로 파지 시 `accelX≈0, accelY≈9.8`이면 `rollDegrees≈0`. `rollDegrees = atan2(accelX, accelY)` 도 단위. 양수 = 오른쪽으로 기움 → hint "왼쪽을 내리세요", 음수 → "오른쪽을 내리세요", 허용오차 내면 "" 이고 `isLevel=true`.

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/analysis/tilt_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/tilt.dart';

void main() {
  test('완벽히 수평이면 rollDegrees≈0, isLevel=true, hint 없음', () {
    final t = computeTilt(0.0, 9.8);
    expect(t.rollDegrees.abs(), lessThan(0.01));
    expect(t.isLevel, isTrue);
    expect(t.hint, '');
  });

  test('오른쪽으로 기울면 rollDegrees 양수, hint는 왼쪽을 내리라고 안내', () {
    final t = computeTilt(9.8, 9.8); // 45도
    expect(t.rollDegrees, closeTo(45.0, 0.5));
    expect(t.isLevel, isFalse);
    expect(t.hint, '왼쪽을 내리세요');
  });

  test('왼쪽으로 기울면 rollDegrees 음수, hint는 오른쪽을 내리라고 안내', () {
    final t = computeTilt(-9.8, 9.8); // -45도
    expect(t.rollDegrees, closeTo(-45.0, 0.5));
    expect(t.hint, '오른쪽을 내리세요');
  });

  test('허용오차 내 미세 기울기는 수평으로 판정', () {
    final t = computeTilt(0.17, 9.8); // 약 1.0도
    expect(t.rollDegrees.abs(), lessThan(1.5));
    expect(t.isLevel, isTrue);
    expect(t.hint, '');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/analysis/tilt_test.dart`
Expected: FAIL — `tilt.dart` / `computeTilt` 없음.

- [ ] **Step 3: 최소 구현**

```dart
// lib/analysis/tilt.dart
import 'dart:math' as math;

class TiltInfo {
  final double rollDegrees;
  final bool isLevel;
  final String hint;
  const TiltInfo({
    required this.rollDegrees,
    required this.isLevel,
    required this.hint,
  });
}

/// 가속도계 x,y로 좌우 기울기(roll)를 계산한다.
/// 세로 파지(x≈0,y≈9.8) 기준 0도. 양수=오른쪽으로 기움.
TiltInfo computeTilt(double accelX, double accelY,
    {double levelToleranceDeg = 1.5}) {
  final roll = math.atan2(accelX, accelY) * 180 / math.pi;
  final level = roll.abs() <= levelToleranceDeg;
  String hint;
  if (level) {
    hint = '';
  } else if (roll > 0) {
    hint = '왼쪽을 내리세요';
  } else {
    hint = '오른쪽을 내리세요';
  }
  return TiltInfo(rollDegrees: roll, isLevel: level, hint: hint);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/analysis/tilt_test.dart`
Expected: PASS (4개).

- [ ] **Step 5: Commit**

```bash
git add lib/analysis/tilt.dart test/analysis/tilt_test.dart
git commit -m "feat: add tilt/level computation from accelerometer"
```

---

## Task 4: 3분할 정렬 계산 (thirds) — TDD

**Files:**
- Create: `lib/analysis/thirds.dart`
- Test: `test/analysis/thirds_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `class ThirdsAlignment { final double targetX; final double targetY; final double distance; final double score; final String hint; }`
  - `ThirdsAlignment computeThirds(double cx, double cy, {double alignedTolerance = 0.05})`
  - 규약: 4개 교차점(1/3,1/3),(2/3,1/3),(1/3,2/3),(2/3,2/3) 중 가장 가까운 점 선택. `distance`=정규화 유클리드 거리. `score = 1 - min(distance/0.4, 1)`(0~1, 높을수록 정렬됨). hint: `dx=targetX-cx, dy=targetY-cy`; |성분|>tolerance면 수평("오른쪽으로"/"왼쪽으로")·수직("아래로"/"위로")을 조합, 둘 다 tolerance 이하면 "좋아요".

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/analysis/thirds_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/thirds.dart';

void main() {
  test('교차점 위에 있으면 정렬됨: distance≈0, score≈1, hint 좋아요', () {
    final a = computeThirds(1 / 3, 1 / 3);
    expect(a.distance, lessThan(0.01));
    expect(a.score, closeTo(1.0, 0.01));
    expect(a.hint, '좋아요');
  });

  test('가장 가까운 교차점을 선택한다', () {
    final a = computeThirds(0.66, 0.66);
    expect(a.targetX, closeTo(2 / 3, 0.001));
    expect(a.targetY, closeTo(2 / 3, 0.001));
  });

  test('피사체가 목표점보다 왼쪽/위면 오른쪽·아래로 안내', () {
    // 목표 (1/3,1/3)=(0.333,0.333), 피사체 (0.2,0.2) -> dx>0, dy>0
    final a = computeThirds(0.2, 0.2);
    expect(a.hint, '오른쪽으로 · 아래로');
  });

  test('멀수록 score가 낮다', () {
    final near = computeThirds(0.30, 0.33);
    final far = computeThirds(0.9, 0.9);
    expect(far.score, lessThan(near.score));
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/analysis/thirds_test.dart`
Expected: FAIL — `computeThirds` 없음.

- [ ] **Step 3: 최소 구현**

```dart
// lib/analysis/thirds.dart
import 'dart:math' as math;

class ThirdsAlignment {
  final double targetX;
  final double targetY;
  final double distance;
  final double score;
  final String hint;
  const ThirdsAlignment({
    required this.targetX,
    required this.targetY,
    required this.distance,
    required this.score,
    required this.hint,
  });
}

const _thirds = [1 / 3, 2 / 3];

/// 피사체 중심(cx,cy)에 대해 가장 가까운 3분할 교차점과 정렬 지표를 계산.
ThirdsAlignment computeThirds(double cx, double cy,
    {double alignedTolerance = 0.05}) {
  double bestX = _thirds[0], bestY = _thirds[0], bestD = double.infinity;
  for (final tx in _thirds) {
    for (final ty in _thirds) {
      final d = math.sqrt(math.pow(tx - cx, 2) + math.pow(ty - cy, 2));
      if (d < bestD) {
        bestD = d;
        bestX = tx;
        bestY = ty;
      }
    }
  }
  final score = 1 - math.min(bestD / 0.4, 1.0);
  final dx = bestX - cx;
  final dy = bestY - cy;
  final parts = <String>[];
  if (dx > alignedTolerance) {
    parts.add('오른쪽으로');
  } else if (dx < -alignedTolerance) {
    parts.add('왼쪽으로');
  }
  if (dy > alignedTolerance) {
    parts.add('아래로');
  } else if (dy < -alignedTolerance) {
    parts.add('위로');
  }
  final hint = parts.isEmpty ? '좋아요' : parts.join(' · ');
  return ThirdsAlignment(
    targetX: bestX,
    targetY: bestY,
    distance: bestD,
    score: score,
    hint: hint,
  );
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/analysis/thirds_test.dart`
Expected: PASS (4개).

- [ ] **Step 5: Commit**

```bash
git add lib/analysis/thirds.dart test/analysis/thirds_test.dart
git commit -m "feat: add rule-of-thirds alignment computation"
```

---

## Task 5: 머리 공간 계산 (headroom) — TDD

**Files:**
- Create: `lib/analysis/headroom.dart`
- Test: `test/analysis/headroom_test.dart`

**Interfaces:**
- Consumes: `PersonBox` (`lib/models/person_box.dart`)
- Produces:
  - `class HeadroomAdvice { final double ratio; final String hint; }`
  - `HeadroomAdvice computeHeadroom(PersonBox person, {double idealMin = 0.05, double idealMax = 0.15})`
  - 규약: `ratio = person.top`(머리 위 여백). ratio<idealMin → "카메라를 살짝 올리세요"(공간 확보), ratio>idealMax → "카메라를 살짝 내리세요", 그 외 "".

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/analysis/headroom_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/analysis/headroom.dart';

PersonBox boxWithTop(double top) =>
    PersonBox(left: 0.3, top: top, width: 0.4, height: 0.5);

void main() {
  test('머리 공간이 너무 좁으면 카메라를 올리라고 안내', () {
    final a = computeHeadroom(boxWithTop(0.01));
    expect(a.ratio, closeTo(0.01, 0.0001));
    expect(a.hint, '카메라를 살짝 올리세요');
  });

  test('머리 공간이 너무 넓으면 카메라를 내리라고 안내', () {
    final a = computeHeadroom(boxWithTop(0.30));
    expect(a.hint, '카메라를 살짝 내리세요');
  });

  test('적정 범위면 힌트 없음', () {
    final a = computeHeadroom(boxWithTop(0.10));
    expect(a.hint, '');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/analysis/headroom_test.dart`
Expected: FAIL — `computeHeadroom` 없음.

- [ ] **Step 3: 최소 구현**

```dart
// lib/analysis/headroom.dart
import '../models/person_box.dart';

class HeadroomAdvice {
  final double ratio;
  final String hint;
  const HeadroomAdvice({required this.ratio, required this.hint});
}

/// 인물 머리 위 여백 비율을 계산하고 카메라 상하 조정을 안내.
HeadroomAdvice computeHeadroom(PersonBox person,
    {double idealMin = 0.05, double idealMax = 0.15}) {
  final ratio = person.top;
  String hint;
  if (ratio < idealMin) {
    hint = '카메라를 살짝 올리세요';
  } else if (ratio > idealMax) {
    hint = '카메라를 살짝 내리세요';
  } else {
    hint = '';
  }
  return HeadroomAdvice(ratio: ratio, hint: hint);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/analysis/headroom_test.dart`
Expected: PASS (3개).

- [ ] **Step 5: Commit**

```bash
git add lib/analysis/headroom.dart test/analysis/headroom_test.dart
git commit -m "feat: add headroom computation and guidance"
```

---

## Task 6: 잘림 감지 (crop) — TDD

**Files:**
- Create: `lib/analysis/crop.dart`
- Test: `test/analysis/crop_test.dart`

**Interfaces:**
- Consumes: `PersonBox`
- Produces:
  - `class CropWarning { final bool top, bottom, left, right; bool get any; String get message; }`
  - `CropWarning detectCrop(PersonBox person, {double margin = 0.02})`
  - 규약: `top = person.top <= margin`, `bottom = person.bottom >= 1 - margin`, `left = person.left <= margin`, `right = person.right >= 1 - margin`. `message`: 잘린 변들을 한국어로 조합(예: "위/오른쪽이 잘렸어요"), 없으면 "".

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/analysis/crop_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/analysis/crop.dart';

void main() {
  test('여백 안에 있으면 잘림 없음', () {
    final w = detectCrop(
        const PersonBox(left: 0.2, top: 0.1, width: 0.5, height: 0.7));
    expect(w.any, isFalse);
    expect(w.message, '');
  });

  test('상단에 닿으면 위 잘림 감지', () {
    final w = detectCrop(
        const PersonBox(left: 0.2, top: 0.0, width: 0.5, height: 0.7));
    expect(w.top, isTrue);
    expect(w.message, contains('위'));
  });

  test('여러 변이 잘리면 메시지에 모두 포함', () {
    final w = detectCrop(
        const PersonBox(left: 0.0, top: 0.0, width: 1.0, height: 1.0));
    expect(w.top && w.bottom && w.left && w.right, isTrue);
    expect(w.message, contains('위'));
    expect(w.message, contains('아래'));
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/analysis/crop_test.dart`
Expected: FAIL — `detectCrop` 없음.

- [ ] **Step 3: 최소 구현**

```dart
// lib/analysis/crop.dart
import '../models/person_box.dart';

class CropWarning {
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  const CropWarning({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  bool get any => top || bottom || left || right;

  String get message {
    if (!any) return '';
    final sides = <String>[];
    if (top) sides.add('위');
    if (bottom) sides.add('아래');
    if (left) sides.add('왼쪽');
    if (right) sides.add('오른쪽');
    return '${sides.join('/')}이(가) 잘렸어요';
  }
}

/// 인물 경계가 프레임 가장자리에 닿아 잘렸는지 감지.
CropWarning detectCrop(PersonBox person, {double margin = 0.02}) {
  return CropWarning(
    top: person.top <= margin,
    bottom: person.bottom >= 1 - margin,
    left: person.left <= margin,
    right: person.right >= 1 - margin,
  );
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/analysis/crop_test.dart`
Expected: PASS (3개).

- [ ] **Step 5: Commit**

```bash
git add lib/analysis/crop.dart test/analysis/crop_test.dart
git commit -m "feat: add subject crop detection at frame edges"
```

---

## Task 7: 각도·줌 안내 (angle/zoom) — TDD

**Files:**
- Create: `lib/analysis/angle_zoom.dart`
- Test: `test/analysis/angle_zoom_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `class AngleAdvice { final double pitchDegrees; final String hint; }`
  - `double computePitch(double accelY, double accelZ)` — 규약: 세로 파지(y≈9.8,z≈0)면 0도. `pitch = atan2(accelZ, accelY) * 180/pi`. 양수=위를 향함(뒤로 젖힘).
  - `AngleAdvice computeAngle(double pitchDegrees, {bool hasPerson = false, double eyeLevelTolerance = 10})` — hasPerson일 때 |pitch|≤tol이면 "" , pitch>tol "카메라를 눈높이로 내리세요", pitch<-tol "카메라를 눈높이로 올리세요". hasPerson=false면 항상 "".
  - `class ZoomAdvice { final double subjectRatio; final String hint; }`
  - `ZoomAdvice computeZoom(double subjectHeightRatio, {double idealMin = 0.5, double idealMax = 0.8})` — ratio<idealMin "조금 다가가거나 확대하세요", ratio>idealMax "조금 물러나거나 축소하세요", 그 외 "".

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/analysis/angle_zoom_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/angle_zoom.dart';

void main() {
  group('pitch', () {
    test('세로 파지면 pitch≈0', () {
      expect(computePitch(9.8, 0.0).abs(), lessThan(0.01));
    });
    test('뒤로 젖히면 pitch 양수', () {
      expect(computePitch(9.8, 9.8), closeTo(45.0, 0.5));
    });
  });

  group('angle advice', () {
    test('인물 없으면 각도 안내 없음', () {
      expect(computeAngle(40, hasPerson: false).hint, '');
    });
    test('인물 촬영 시 눈높이면 안내 없음', () {
      expect(computeAngle(0, hasPerson: true).hint, '');
    });
    test('많이 젖혀 위를 향하면 눈높이로 내리라고 안내', () {
      expect(computeAngle(30, hasPerson: true).hint, '카메라를 눈높이로 내리세요');
    });
    test('많이 숙여 아래를 향하면 눈높이로 올리라고 안내', () {
      expect(computeAngle(-30, hasPerson: true).hint, '카메라를 눈높이로 올리세요');
    });
  });

  group('zoom advice', () {
    test('피사체가 작으면 다가가거나 확대 안내', () {
      expect(computeZoom(0.3).hint, '조금 다가가거나 확대하세요');
    });
    test('피사체가 크면 물러나거나 축소 안내', () {
      expect(computeZoom(0.9).hint, '조금 물러나거나 축소하세요');
    });
    test('적정 크기면 안내 없음', () {
      expect(computeZoom(0.65).hint, '');
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/analysis/angle_zoom_test.dart`
Expected: FAIL — 심볼 없음.

- [ ] **Step 3: 최소 구현**

```dart
// lib/analysis/angle_zoom.dart
import 'dart:math' as math;

class AngleAdvice {
  final double pitchDegrees;
  final String hint;
  const AngleAdvice({required this.pitchDegrees, required this.hint});
}

class ZoomAdvice {
  final double subjectRatio;
  final String hint;
  const ZoomAdvice({required this.subjectRatio, required this.hint});
}

/// 가속도계 y,z로 상하 기울기(pitch)를 계산. 세로 파지 기준 0도, 양수=위를 향함.
double computePitch(double accelY, double accelZ) {
  return math.atan2(accelZ, accelY) * 180 / math.pi;
}

/// 인물 촬영 시 눈높이 대비 촬영 각도를 안내.
AngleAdvice computeAngle(double pitchDegrees,
    {bool hasPerson = false, double eyeLevelTolerance = 10}) {
  String hint = '';
  if (hasPerson) {
    if (pitchDegrees > eyeLevelTolerance) {
      hint = '카메라를 눈높이로 내리세요';
    } else if (pitchDegrees < -eyeLevelTolerance) {
      hint = '카메라를 눈높이로 올리세요';
    }
  }
  return AngleAdvice(pitchDegrees: pitchDegrees, hint: hint);
}

/// 피사체 높이 비율로 줌/거리 조정을 안내.
ZoomAdvice computeZoom(double subjectHeightRatio,
    {double idealMin = 0.5, double idealMax = 0.8}) {
  String hint;
  if (subjectHeightRatio < idealMin) {
    hint = '조금 다가가거나 확대하세요';
  } else if (subjectHeightRatio > idealMax) {
    hint = '조금 물러나거나 축소하세요';
  } else {
    hint = '';
  }
  return ZoomAdvice(subjectRatio: subjectHeightRatio, hint: hint);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/analysis/angle_zoom_test.dart`
Expected: PASS (전체).

- [ ] **Step 5: Commit**

```bash
git add lib/analysis/angle_zoom.dart test/analysis/angle_zoom_test.dart
git commit -m "feat: add pitch-based angle and subject-size zoom guidance"
```

---

## Task 8: GuideMetrics 집계 모델

**Files:**
- Create: `lib/analysis/guide_metrics.dart`

**Interfaces:**
- Consumes: `TiltInfo`, `ThirdsAlignment`, `HeadroomAdvice`, `CropWarning`, `AngleAdvice`, `ZoomAdvice`, `PersonBox`.
- Produces:
  - `class GuideMetrics { final TiltInfo tilt; final PersonBox? person; final ThirdsAlignment? thirds; final HeadroomAdvice? headroom; final CropWarning? crop; final AngleAdvice angle; final ZoomAdvice? zoom; }`
  - `List<String> get activeHints` — 비어있지 않은 모든 hint를 우선순위(수평→잘림→머리공간→3분할→각도→줌) 순으로 반환.

- [ ] **Step 1: 작성**

```dart
// lib/analysis/guide_metrics.dart
import '../models/person_box.dart';
import 'tilt.dart';
import 'thirds.dart';
import 'headroom.dart';
import 'crop.dart';
import 'angle_zoom.dart';

/// 한 프레임에 대한 모든 실시간 가이드 지표의 집계.
class GuideMetrics {
  final TiltInfo tilt;
  final PersonBox? person;
  final ThirdsAlignment? thirds;
  final HeadroomAdvice? headroom;
  final CropWarning? crop;
  final AngleAdvice angle;
  final ZoomAdvice? zoom;

  const GuideMetrics({
    required this.tilt,
    required this.angle,
    this.person,
    this.thirds,
    this.headroom,
    this.crop,
    this.zoom,
  });

  /// 사용자에게 보여줄 활성 힌트 목록(우선순위 순, 빈 문자열 제외).
  List<String> get activeHints {
    final out = <String>[];
    void add(String? s) {
      if (s != null && s.isNotEmpty) out.add(s);
    }

    add(tilt.hint);
    add(crop?.message);
    add(headroom?.hint);
    add(thirds?.hint == '좋아요' ? '' : thirds?.hint);
    add(angle.hint);
    add(zoom?.hint);
    return out;
  }
}
```

- [ ] **Step 2: 분석 확인**

Run: `flutter analyze lib/analysis/guide_metrics.dart`
Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
git add lib/analysis/guide_metrics.dart
git commit -m "feat: add GuideMetrics aggregate with prioritized hints"
```

---

## Task 9: PersonDetector 인터페이스 + ML Kit 구현

**Files:**
- Create: `lib/analysis/person_detector.dart`

**Interfaces:**
- Consumes: `camera` 의 `CameraImage`, `google_ml_kit`, `PersonBox`.
- Produces:
  - `abstract class PersonDetector { Future<PersonBox?> detect(CameraImage image, int rotationDegrees); void dispose(); }`
  - `class MlKitPersonDetector implements PersonDetector` — ML Kit Pose/Face로 인물 bbox를 정규화해 반환. 인물 없으면 null.

> 참고: `CameraImage`→ML Kit `InputImage` 변환은 플랫폼 의존이라 단위 테스트 불가. 이 파일은 구현 + 기기 수동 검증. 추상 인터페이스 덕분에 Task 10의 AnalysisEngine은 Fake로 테스트한다.

- [ ] **Step 1: 인터페이스 + 구현 작성**

```dart
// lib/analysis/person_detector.dart
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../models/person_box.dart';

/// 프레임에서 인물 경계 상자(정규화)를 추출하는 인터페이스.
abstract class PersonDetector {
  Future<PersonBox?> detect(CameraImage image, int rotationDegrees);
  void dispose();
}

/// ML Kit Face Detection 기반 인물 감지 구현.
class MlKitPersonDetector implements PersonDetector {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );

  @override
  Future<PersonBox?> detect(CameraImage image, int rotationDegrees) async {
    final input = _toInputImage(image, rotationDegrees);
    if (input == null) return null;
    final faces = await _faceDetector.processImage(input);
    if (faces.isEmpty) return null;

    // 가장 큰 얼굴 선택 후, 얼굴 상단 위로 확장해 상반신 근사.
    faces.sort((a, b) =>
        (b.boundingBox.width * b.boundingBox.height)
            .compareTo(a.boundingBox.width * a.boundingBox.height));
    final f = faces.first.boundingBox;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    // 얼굴 박스를 인물 근사로 확장(위 0.5×h, 아래 3×h).
    final top = (f.top - f.height * 0.5).clamp(0.0, imgH);
    final bottom = (f.bottom + f.height * 3.0).clamp(0.0, imgH);
    return PersonBox(
      left: (f.left / imgW).clamp(0.0, 1.0),
      top: (top / imgH).clamp(0.0, 1.0),
      width: (f.width / imgW).clamp(0.0, 1.0),
      height: ((bottom - top) / imgH).clamp(0.0, 1.0),
    );
  }

  InputImage? _toInputImage(CameraImage image, int rotationDegrees) {
    final rotation =
        InputImageRotationValue.fromRawValue(rotationDegrees) ??
            InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() => _faceDetector.close();
}
```

- [ ] **Step 2: 분석 확인**

Run: `flutter analyze lib/analysis/person_detector.dart`
Expected: 에러 없음. (google_ml_kit API 버전에 따라 `InputImageMetadata` 시그니처가 다르면 설치된 버전에 맞춰 필드명을 조정한다.)

- [ ] **Step 3: Commit**

```bash
git add lib/analysis/person_detector.dart
git commit -m "feat: add PersonDetector interface and ML Kit face-based impl"
```

---

## Task 10: AnalysisEngine 조립 — TDD (Fake detector)

**Files:**
- Create: `lib/analysis/analysis_engine.dart`
- Test: `test/analysis/analysis_engine_test.dart`

**Interfaces:**
- Consumes: `PersonDetector`, 모든 compute 함수, `GuideMetrics`, `PersonBox`.
- Produces:
  - `class SensorSample { final double accelX, accelY, accelZ; }`
  - `class AnalysisEngine { AnalysisEngine(this.detector); GuideMetrics buildMetrics({PersonBox? person, required SensorSample sensor}); }`
  - `buildMetrics`는 순수 조립: tilt=computeTilt(x,y), angle=computeAngle(computePitch(y,z), hasPerson: person!=null), person 있으면 thirds(center)·headroom·crop·zoom(height) 계산, 없으면 그 필드들 null.

> `detect()`를 부르는 실시간 스트림 파이프라인은 기기 의존이므로, 테스트는 순수 조립 함수 `buildMetrics`를 검증한다. detector는 생성자에 보관만 하고 buildMetrics에서는 이미 감지된 person을 받는다(관심사 분리).

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/analysis/analysis_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/analysis/analysis_engine.dart';

void main() {
  final engine = AnalysisEngine(null);

  test('인물 없으면 person/thirds/headroom/crop/zoom 은 null, tilt/angle 존재', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0),
    );
    expect(m.person, isNull);
    expect(m.thirds, isNull);
    expect(m.headroom, isNull);
    expect(m.crop, isNull);
    expect(m.zoom, isNull);
    expect(m.tilt.isLevel, isTrue);
    expect(m.angle.hint, ''); // hasPerson=false
  });

  test('인물 있으면 모든 지표 계산', () {
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.3, top: 0.1, width: 0.4, height: 0.6),
      sensor: const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0),
    );
    expect(m.person, isNotNull);
    expect(m.thirds, isNotNull);
    expect(m.headroom, isNotNull);
    expect(m.crop, isNotNull);
    expect(m.zoom, isNotNull);
  });

  test('기울어진 센서면 tilt.hint 생성', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: const SensorSample(accelX: 9.8, accelY: 9.8, accelZ: 0),
    );
    expect(m.tilt.hint, '왼쪽을 내리세요');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/analysis/analysis_engine_test.dart`
Expected: FAIL — `AnalysisEngine`/`SensorSample` 없음.

- [ ] **Step 3: 최소 구현**

```dart
// lib/analysis/analysis_engine.dart
import '../models/person_box.dart';
import 'tilt.dart';
import 'thirds.dart';
import 'headroom.dart';
import 'crop.dart';
import 'angle_zoom.dart';
import 'guide_metrics.dart';
import 'person_detector.dart';

class SensorSample {
  final double accelX;
  final double accelY;
  final double accelZ;
  const SensorSample({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
  });
}

/// 감지된 인물 + 센서 샘플을 GuideMetrics로 조립한다(순수 로직).
class AnalysisEngine {
  final PersonDetector? detector;
  AnalysisEngine(this.detector);

  GuideMetrics buildMetrics({
    PersonBox? person,
    required SensorSample sensor,
  }) {
    final tilt = computeTilt(sensor.accelX, sensor.accelY);
    final pitch = computePitch(sensor.accelY, sensor.accelZ);
    final angle = computeAngle(pitch, hasPerson: person != null);

    if (person == null) {
      return GuideMetrics(tilt: tilt, angle: angle);
    }
    return GuideMetrics(
      tilt: tilt,
      angle: angle,
      person: person,
      thirds: computeThirds(person.centerX, person.centerY),
      headroom: computeHeadroom(person),
      crop: detectCrop(person),
      zoom: computeZoom(person.height),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/analysis/analysis_engine_test.dart`
Expected: PASS (3개).

- [ ] **Step 5: 전체 테스트 확인**

Run: `flutter test`
Expected: 모든 테스트 PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/analysis/analysis_engine.dart test/analysis/analysis_engine_test.dart
git commit -m "feat: add AnalysisEngine assembling GuideMetrics from person+sensor"
```

---

## Task 11: GuideOverlay (CustomPainter)

**Files:**
- Create: `lib/overlay/guide_overlay.dart`

**Interfaces:**
- Consumes: `GuideMetrics`, `ThirdsAlignment`, `PersonBox`.
- Produces:
  - `class GuideOverlay extends StatelessWidget { final GuideMetrics metrics; final bool showGrid; }`
  - 내부 `class GuidePainter extends CustomPainter` — 격자(3×3, showGrid일 때), 수평 상태선(level이면 녹색·아니면 빨강), 인물 bbox(잘림 시 빨강), 3분할 목표 교차점 마커를 그린다. 판단 없음(metrics 그대로 시각화).

> CustomPainter는 순수 단위테스트가 어렵다. 구현 + 기기/에뮬레이터 수동 시각 검증. 색 규약: 좋음=녹색(`Colors.greenAccent`), 주의=빨강(`Colors.redAccent`), 중립=흰색 반투명.

- [ ] **Step 1: 작성**

```dart
// lib/overlay/guide_overlay.dart
import 'package:flutter/material.dart';
import '../analysis/guide_metrics.dart';

class GuideOverlay extends StatelessWidget {
  final GuideMetrics metrics;
  final bool showGrid;
  const GuideOverlay({super.key, required this.metrics, this.showGrid = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GuidePainter(metrics: metrics, showGrid: showGrid),
      size: Size.infinite,
    );
  }
}

class GuidePainter extends CustomPainter {
  final GuideMetrics metrics;
  final bool showGrid;
  GuidePainter({required this.metrics, required this.showGrid});

  static const _good = Color(0xAA69F0AE); // greenAccent 반투명
  static const _warn = Color(0xAAFF5252); // redAccent 반투명
  static const _neutral = Color(0x88FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) _paintGrid(canvas, size);
    _paintLevel(canvas, size);
    _paintPerson(canvas, size);
    _paintThirdsTarget(canvas, size);
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
    // 화면 중앙, roll만큼 회전한 짧은 수평선.
    final rad = metrics.tilt.rollDegrees * 3.1415926535 / 180;
    final half = size.width * 0.15;
    final dxr = half * _cos(rad);
    final dyr = half * _sin(rad);
    canvas.drawLine(
        Offset(cx - dxr, cy - dyr), Offset(cx + dxr, cy + dyr), p);
  }

  void _paintPerson(Canvas canvas, Size size) {
    final person = metrics.person;
    if (person == null) return;
    final cropped = metrics.crop?.any ?? false;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = cropped ? _warn : _good;
    canvas.drawRect(
      Rect.fromLTWH(person.left * size.width, person.top * size.height,
          person.width * size.width, person.height * size.height),
      p,
    );
  }

  void _paintThirdsTarget(Canvas canvas, Size size) {
    final thirds = metrics.thirds;
    if (thirds == null) return;
    final aligned = thirds.hint == '좋아요';
    final p = Paint()..color = aligned ? _good : _warn;
    canvas.drawCircle(
      Offset(thirds.targetX * size.width, thirds.targetY * size.height),
      8,
      p,
    );
  }

  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 1.5707963268);
  double _taylorSin(double x) {
    // dart:math import 없이 Flutter widget 파일에서 쓰려면 math 사용이 낫다.
    // 실제로는 아래 import 'dart:math'로 교체.
    return x; // placeholder — Step 2에서 dart:math로 교체
  }

  @override
  bool shouldRepaint(covariant GuidePainter old) =>
      old.metrics != metrics || old.showGrid != showGrid;
}
```

- [ ] **Step 2: 삼각함수는 dart:math로 교체**

`_sin`/`_cos`/`_taylorSin`의 임시 구현을 제거하고 상단에 `import 'dart:math' as math;`를 추가한 뒤 `_paintLevel`에서 `math.cos(rad)`, `math.sin(rad)`를 직접 사용하도록 수정:

```dart
// 파일 상단
import 'dart:math' as math;

// _paintLevel 내부
final dxr = half * math.cos(rad);
final dyr = half * math.sin(rad);
```
그리고 `_sin`, `_cos`, `_taylorSin` 메서드 전체 삭제.

- [ ] **Step 3: 분석 확인**

Run: `flutter analyze lib/overlay/guide_overlay.dart`
Expected: 에러 없음.

- [ ] **Step 4: Commit**

```bash
git add lib/overlay/guide_overlay.dart
git commit -m "feat: add GuideOverlay CustomPainter for grid/level/person/thirds"
```

---

## Task 12: CameraService

**Files:**
- Create: `lib/camera/camera_service.dart`

**Interfaces:**
- Consumes: `camera`, `gallery_saver`.
- Produces:
  - `class CameraService { Future<void> initialize(); CameraController get controller; void startStream(void Function(CameraImage) onFrame); Future<void> stopStream(); Future<String> captureAndSave(); Future<void> dispose(); int get sensorOrientation; }`

> 카메라는 실기기 의존 — 단위테스트 대신 기기 수동 검증. Task 13에서 화면에 연결해 검증한다.

- [ ] **Step 1: 작성**

```dart
// lib/camera/camera_service.dart
import 'package:camera/camera.dart';
import 'package:gallery_saver/gallery_saver.dart';

/// 카메라 프리뷰/프레임 스트림/촬영·저장을 캡슐화한다.
class CameraService {
  CameraController? _controller;
  bool _streaming = false;

  CameraController get controller {
    final c = _controller;
    if (c == null) {
      throw StateError('CameraService.initialize()를 먼저 호출하세요');
    }
    return c;
  }

  int get sensorOrientation =>
      _controller?.description.sensorOrientation ?? 0;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    _controller = controller;
  }

  void startStream(void Function(CameraImage) onFrame) {
    if (_streaming) return;
    _streaming = true;
    controller.startImageStream(onFrame);
  }

  Future<void> stopStream() async {
    if (!_streaming) return;
    _streaming = false;
    await controller.stopImageStream();
  }

  /// 촬영 후 갤러리에 저장하고 파일 경로를 반환.
  Future<String> captureAndSave() async {
    final wasStreaming = _streaming;
    if (wasStreaming) await stopStream();
    final file = await controller.takePicture();
    await GallerySaver.saveImage(file.path);
    return file.path;
  }

  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
  }
}
```

- [ ] **Step 2: 분석 확인**

Run: `flutter analyze lib/camera/camera_service.dart`
Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
git add lib/camera/camera_service.dart
git commit -m "feat: add CameraService for preview/stream/capture/save"
```

---

## Task 13: CameraScreen 조립 + main 연결

**Files:**
- Create: `lib/screens/camera_screen.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `CameraService`, `AnalysisEngine`, `MlKitPersonDetector`, `GuideOverlay`, `SensorSample`, `sensors_plus`.
- Produces: 실행 가능한 전체 화면. 프리뷰 위 오버레이 + 활성 힌트 텍스트 + 촬영 버튼 + 격자 토글.

> 통합 화면 — 기기 수동 검증. 프레임 스로틀링: 마지막 처리 후 처리 중이면 새 프레임을 버려(detector 재진입 방지) 프레임 드랍을 최소화한다.

- [ ] **Step 1: CameraScreen 작성**

```dart
// lib/screens/camera_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../camera/camera_service.dart';
import '../analysis/analysis_engine.dart';
import '../analysis/person_detector.dart';
import '../analysis/guide_metrics.dart';
import '../analysis/tilt.dart';
import '../analysis/angle_zoom.dart';
import '../overlay/guide_overlay.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _camera = CameraService();
  late final PersonDetector _detector;
  late final AnalysisEngine _engine;

  SensorSample _sensor = const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0);
  GuideMetrics _metrics = GuideMetrics(
    tilt: const TiltInfo(rollDegrees: 0, isLevel: true, hint: ''),
    angle: const AngleAdvice(pitchDegrees: 0, hint: ''),
  );
  bool _ready = false;
  bool _showGrid = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _detector = MlKitPersonDetector();
    _engine = AnalysisEngine(_detector);
    accelerometerEvents.listen((e) {
      _sensor = SensorSample(accelX: e.x, accelY: e.y, accelZ: e.z);
    });
    _init();
  }

  Future<void> _init() async {
    await _camera.initialize();
    _camera.startStream(_onFrame);
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processing) return; // 스로틀: 재진입 방지
    _processing = true;
    try {
      final person =
          await _detector.detect(image, _camera.sensorOrientation);
      final m = _engine.buildMetrics(person: person, sensor: _sensor);
      if (mounted) setState(() => _metrics = m);
    } catch (_) {
      // 프레임 단위 실패는 무시(다음 프레임 계속)
    } finally {
      _processing = false;
    }
  }

  Future<void> _capture() async {
    final path = await _camera.captureAndSave();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장됨: $path')),
      );
      _camera.startStream(_onFrame);
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final hints = _metrics.activeHints;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_camera.controller),
          GuideOverlay(metrics: _metrics, showGrid: _showGrid),
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Column(
              children: [
                for (final h in hints)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    color: Colors.black54,
                    child: Text(h,
                        style: const TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off,
                      color: Colors.white, size: 32),
                  onPressed: () => setState(() => _showGrid = !_showGrid),
                ),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: main.dart 연결**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';

void main() {
  runApp(const TtongsonApp());
}

class TtongsonApp extends StatelessWidget {
  const TtongsonApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '똥손카메라',
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}
```

- [ ] **Step 3: 분석 + 전체 테스트**

Run: `flutter analyze && flutter test`
Expected: analyze 에러 없음, 모든 순수 로직 테스트 PASS.

- [ ] **Step 4: 기기 수동 검증**

연결된 실기기에서 `flutter run` 후 확인:
- 프리뷰가 뜨고 3×3 격자가 보인다(토글 동작).
- 기기를 좌우로 기울이면 중앙 수평선이 회전하고, 수평일 때 녹색·기울면 빨강, 상단에 "왼쪽/오른쪽을 내리세요" 표시.
- 사람을 비추면 인물 박스가 그려지고, 화면 끝에 걸치면 박스·경고가 빨강.
- 머리 공간/줌/각도 힌트가 상황에 맞게 상단에 나타난다.
- 촬영 버튼을 누르면 사진이 갤러리에 저장되고 스낵바 표시.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/camera_screen.dart lib/main.dart
git commit -m "feat: wire CameraScreen with live guide overlay and capture"
```

---

## Self-Review 결과

**Spec 커버리지:**
- 4.1 격자·수평 → Task 3(tilt), Task 11(격자·수평선 렌더), Task 13(힌트·토글) ✅
- 4.2 인물 포즈·위치 → Task 5(headroom), Task 6(crop), Task 4(thirds), Task 9(감지), Task 11(박스 렌더) ✅
- 4.3 각도·줌 → Task 7 ✅
- 4.4 AI 구도 추천(클라우드) → **Phase 2 별도 계획**(이 문서 범위 밖, 의도적) ✅
- 모듈 1~3(CameraService/AnalysisEngine/GuideOverlay) → Task 12/10/11 ✅. 모듈 4(CloudAdvisor)는 Phase 2.
- 비기능: 스로틀링(Task 13 재진입 방지), 오프라인(네트워크 0회), 색+텍스트 병행(Task 11/13) ✅

**플레이스홀더 스캔:** Task 11 Step 1에 의도적 임시 삼각함수가 있으나 Step 2에서 dart:math로 교체하도록 명시 — 잔여 플레이스홀더 없음. ✅

**타입 일관성:** `PersonBox`, `GuideMetrics`, `SensorSample`, `TiltInfo`, `ThirdsAlignment`, `HeadroomAdvice`, `CropWarning`, `AngleAdvice`, `ZoomAdvice`, `PersonDetector` 시그니처가 정의 태스크와 소비 태스크에서 일치. `computeThirds`의 정렬 판정 문자열 '좋아요'가 `GuideMetrics.activeHints`(Task 8)와 `GuidePainter._paintThirdsTarget`(Task 11)에서 동일하게 사용됨. ✅

---

## Phase 2 (별도 계획 예정)

`CloudAdvisor`(모듈 4) — 온디맨드 프레임 전송 → 클라우드 멀티모달 AI 구도 추천, 전송 동의 UX, 폴백. 이 계획 완료 후 별도 spec-refine 없이 기존 spec 4.4/6절을 근거로 `writing-plans`로 작성한다.
