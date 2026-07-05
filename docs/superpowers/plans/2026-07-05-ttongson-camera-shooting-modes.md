# 촬영 모드(인물/자연/사물) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 하단 휠로 인물/자연/사물 촬영 모드를 전환하면 온디바이스 실시간 가이드와 클라우드 ✨ 구도 추천이 함께 모드에 맞춰 바뀐다.

**Architecture:** 모드는 순수 `enum ShootingMode`로 표현하고, 판단 로직(모드별 지표 분기)은 순수 함수 `AnalysisEngine.buildMetrics`에 둔다. 사물 감지는 ML Kit Object Detection 래퍼로 추가하고, 인물 감지와 같은 정규화 `PersonBox`를 돌려줘 기존 순수 함수(3분할·줌)를 재사용한다. 백엔드는 요청의 `mode`로 프롬프트를 고르고 `targetBox`를 선택 필드로 완화한다.

**Tech Stack:** Flutter/Dart(null-safety), `google_mlkit_object_detection`(신규), `google_mlkit_face_detection`, `shared_preferences`, `cloud_functions`; 백엔드 Firebase Functions(TypeScript, vitest), `@anthropic-ai/sdk`, 모델 `claude-sonnet-4-6`.

## Global Constraints

- 좌표계: 인물/사물/포인트 좌표는 **정규화 0.0~1.0**, 원점 **좌상단**(x→오른쪽, y→아래).
- 모드 wire 문자열은 정확히 `'person'` / `'nature'` / `'object'` (앱·백엔드 동일). 미지정/이상값은 **`person`으로 폴백**.
- 모드 라벨(한국어): 인물=`'인물'`, 자연=`'자연'`, 사물=`'사물'`.
- 정렬 판정 문자열은 `'좋아요'`로 통일.
- `lib/analysis/` 중 `person_detector.dart`·`analysis_engine.dart`·(신규)`object_detector.dart`를 **제외한** 파일은 Flutter/plugin import 금지(순수 Dart). 이 예외 목록은 Task 3에서 CLAUDE.md에 반영한다.
- 온디바이스 분석은 네트워크 0회. 클라우드는 ✨ 추천 시 1회만.
- 정적 분석은 `dart analyze lib test` 사용(`flutter analyze` 금지 — 한글 경로 LSP 크래시). 완료 게이트는 `tool/verify.sh`.
- 커밋 메시지는 Conventional Commits (`feat:`/`test:`/`chore:`/`docs:`).

---

### Task 1: ShootingMode enum (순수)

모드 값과 wire/label 매핑. 순수 Dart, TDD.

**Files:**
- Create: `lib/models/shooting_mode.dart`
- Test: `test/models/shooting_mode_test.dart`

**Interfaces:**
- Produces:
  - `enum ShootingMode { person, nature, object }`
  - `extension ShootingModeWire on ShootingMode`: `String get wire`, `String get label`, `static ShootingMode? fromWire(String? s)`.

- [ ] **Step 1: 실패 테스트 작성**

`test/models/shooting_mode_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/shooting_mode.dart';

void main() {
  test('wire 문자열은 person/nature/object', () {
    expect(ShootingMode.person.wire, 'person');
    expect(ShootingMode.nature.wire, 'nature');
    expect(ShootingMode.object.wire, 'object');
  });

  test('label 은 한국어', () {
    expect(ShootingMode.person.label, '인물');
    expect(ShootingMode.nature.label, '자연');
    expect(ShootingMode.object.label, '사물');
  });

  test('fromWire 는 유효값을 파싱하고 이상값/누락은 null', () {
    expect(ShootingModeWire.fromWire('person'), ShootingMode.person);
    expect(ShootingModeWire.fromWire('nature'), ShootingMode.nature);
    expect(ShootingModeWire.fromWire('object'), ShootingMode.object);
    expect(ShootingModeWire.fromWire('bogus'), isNull);
    expect(ShootingModeWire.fromWire(null), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/models/shooting_mode_test.dart`
Expected: FAIL — `shooting_mode.dart` 없음 / 심볼 미정의.

- [ ] **Step 3: 최소 구현**

`lib/models/shooting_mode.dart`:
```dart
/// 촬영 모드. wire 문자열은 앱·백엔드 공통 계약(person/nature/object).
enum ShootingMode { person, nature, object }

extension ShootingModeWire on ShootingMode {
  String get wire {
    switch (this) {
      case ShootingMode.person:
        return 'person';
      case ShootingMode.nature:
        return 'nature';
      case ShootingMode.object:
        return 'object';
    }
  }

  String get label {
    switch (this) {
      case ShootingMode.person:
        return '인물';
      case ShootingMode.nature:
        return '자연';
      case ShootingMode.object:
        return '사물';
    }
  }

  /// wire 문자열 → 모드. 이상값/누락은 null(호출측이 person으로 폴백).
  static ShootingMode? fromWire(String? s) {
    switch (s) {
      case 'person':
        return ShootingMode.person;
      case 'nature':
        return ShootingMode.nature;
      case 'object':
        return ShootingMode.object;
      default:
        return null;
    }
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/models/shooting_mode_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: 커밋**

```bash
git add lib/models/shooting_mode.dart test/models/shooting_mode_test.dart
git commit -m "feat: add ShootingMode enum with wire/label mapping"
```

---

### Task 2: AnalysisEngine 모드별 지표 분기 (순수)

`buildMetrics`에 `mode`를 받아 모드별로 채우는 지표를 분기. 순수 로직, TDD.

**Files:**
- Modify: `lib/analysis/analysis_engine.dart`
- Test: `test/analysis/analysis_engine_mode_test.dart`

**Interfaces:**
- Consumes: `ShootingMode`(Task 1). 기존 순수 함수 `computeTilt/computePitch/computeAngle/computeThirds/computeHeadroom/detectCrop/computeZoom`, `GuideMetrics`, `PersonBox`, `SensorSample`.
- Produces: 새 시그니처
  `GuideMetrics buildMetrics({PersonBox? person, PersonBox? face, required SensorSample sensor, ShootingMode mode = ShootingMode.person})`
  - `nature`: 감지 무시 → `GuideMetrics(tilt, angle)`만(angle은 hasPerson:false).
  - `object`: person 있으면 `person + thirds + zoom`만(headroom/crop/eye-level 없음, angle hasPerson:false).
  - `person`(기본): 현재와 동일(person+thirds+headroom+crop+zoom, angle hasPerson:true).
  - `person == null`(non-nature): `GuideMetrics(tilt, angle=hasPerson:false)`.

- [ ] **Step 1: 실패 테스트 작성**

`test/analysis/analysis_engine_mode_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/analysis_engine.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/models/shooting_mode.dart';

const _sensor = SensorSample(accelX: 0, accelY: 9.8, accelZ: 0);
const _box = PersonBox(left: 0.3, top: 0.3, width: 0.2, height: 0.3);

void main() {
  final engine = AnalysisEngine(null);

  test('자연 모드: 인물이 있어도 person/thirds/headroom/crop/zoom 모두 생략', () {
    final m = engine.buildMetrics(
      person: _box,
      face: _box,
      sensor: _sensor,
      mode: ShootingMode.nature,
    );
    expect(m.person, isNull);
    expect(m.thirds, isNull);
    expect(m.headroom, isNull);
    expect(m.crop, isNull);
    expect(m.zoom, isNull);
    // 수평/각도는 항상 존재
    expect(m.tilt, isNotNull);
    expect(m.angle, isNotNull);
  });

  test('사물 모드: person/thirds/zoom 만 채우고 headroom/crop 은 생략', () {
    final m = engine.buildMetrics(
      person: _box,
      face: _box,
      sensor: _sensor,
      mode: ShootingMode.object,
    );
    expect(m.person, isNotNull);
    expect(m.thirds, isNotNull);
    expect(m.zoom, isNotNull);
    expect(m.headroom, isNull);
    expect(m.crop, isNull);
  });

  test('인물 모드(기본): headroom/crop/thirds/zoom 모두 채움', () {
    final m = engine.buildMetrics(person: _box, face: _box, sensor: _sensor);
    expect(m.person, isNotNull);
    expect(m.headroom, isNotNull);
    expect(m.crop, isNotNull);
    expect(m.thirds, isNotNull);
    expect(m.zoom, isNotNull);
  });

  test('사물 모드에서 감지 없으면 person 은 null', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: _sensor,
      mode: ShootingMode.object,
    );
    expect(m.person, isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/analysis/analysis_engine_mode_test.dart`
Expected: FAIL — `buildMetrics`에 `mode` 인자 없음(컴파일 에러).

- [ ] **Step 3: 구현**

`lib/analysis/analysis_engine.dart` — import에 모드 추가, `buildMetrics` 교체:
```dart
import '../models/person_box.dart';
import '../models/shooting_mode.dart';
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

/// 감지된 대상 + 센서 샘플을 모드에 맞는 GuideMetrics로 조립한다(순수 로직).
class AnalysisEngine {
  final PersonDetector? detector;
  AnalysisEngine(this.detector);

  GuideMetrics buildMetrics({
    PersonBox? person,
    PersonBox? face,
    required SensorSample sensor,
    ShootingMode mode = ShootingMode.person,
  }) {
    final tilt = computeTilt(sensor.accelX, sensor.accelY);
    final pitch = computePitch(sensor.accelY, sensor.accelZ);

    // 자연: 수평·격자만. 대상 감지 무시.
    if (mode == ShootingMode.nature) {
      return GuideMetrics(tilt: tilt, angle: computeAngle(pitch, hasPerson: false));
    }

    // 대상 미감지: 수평·각도만.
    if (person == null) {
      return GuideMetrics(tilt: tilt, angle: computeAngle(pitch, hasPerson: false));
    }

    // 사물: 중앙(3분할)·줌만. 헤드룸/크롭/눈높이각 없음.
    if (mode == ShootingMode.object) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, hasPerson: false),
        person: person,
        thirds: computeThirds(person.centerX, person.centerY),
        zoom: computeZoom(person.height),
      );
    }

    // 인물(기본): 전체 지표.
    final angle = computeAngle(pitch, hasPerson: true);
    final cropBox = face ?? person;
    return GuideMetrics(
      tilt: tilt,
      angle: angle,
      person: person,
      thirds: computeThirds(person.centerX, person.centerY),
      headroom: computeHeadroom(person),
      crop: detectCrop(cropBox),
      zoom: computeZoom(person.height),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/analysis/analysis_engine_mode_test.dart`
Expected: PASS (4 tests). 기존 전체도 깨지지 않는지: `flutter test`.

- [ ] **Step 5: 커밋**

```bash
git add lib/analysis/analysis_engine.dart test/analysis/analysis_engine_mode_test.dart
git commit -m "feat: branch guide metrics by shooting mode"
```

---

### Task 3: 사물 감지 (ML Kit Object Detection)

인물 감지와 같은 인터페이스로 사물 박스를 반환하는 래퍼 추가. 플러그인 의존 → 단위 테스트 없이 구현 + 빌드/기기 검증.

**Files:**
- Create: `lib/analysis/object_detector.dart`
- Modify: `pubspec.yaml` (의존성 추가)
- Modify: `CLAUDE.md` (analysis/ 플러그인 예외 목록에 `object_detector.dart` 추가)

**Interfaces:**
- Consumes: `PersonDetector`/`Detection`/`PersonBox`(기존 `lib/analysis/person_detector.dart`).
- Produces: `class MlKitObjectDetector implements PersonDetector` — `detect()`가 가장 큰 사물 박스를 정규화 `PersonBox`로 담은 `Detection(face: box, person: box)` 반환(사물엔 얼굴 개념 없음 → 둘 다 같은 박스; 사물 모드는 face를 쓰지 않음). 미검출 시 `null`.

> **DRY 참고(리뷰 대비):** `_toInputImage` 헬퍼는 `person_detector.dart`의 것과 거의 동일하지만 **의도적으로 복제**한다. 두 파일이 각각 단일 ML Kit 패키지(face vs object)만 import하게 해서 `google_mlkit_commons` 재노출 심볼(InputImage 등)의 **ambiguous import 충돌을 피하기** 위함이다.

- [ ] **Step 1: 의존성 추가**

Run: `flutter pub add google_mlkit_object_detection`
Expected: `pubspec.yaml` dependencies에 `google_mlkit_object_detection` 추가, `pub get` 성공.

- [ ] **Step 2: 구현**

`lib/analysis/object_detector.dart`:
```dart
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../models/person_box.dart';
import 'person_detector.dart';

/// ML Kit Object Detection 기반 사물 감지. 가장 큰 사물 박스 하나를 정규화 PersonBox로 반환.
class MlKitObjectDetector implements PersonDetector {
  final ObjectDetector _detector = ObjectDetector(
    options: ObjectDetectorOptions(
      classifyObjects: false,
      multipleObjects: true,
      mode: DetectionMode.stream,
    ),
  );

  @override
  Future<Detection?> detect(CameraImage image, int rotationDegrees) async {
    final input = _toInputImage(image, rotationDegrees);
    if (input == null) return null;
    final objects = await _detector.processImage(input);
    if (objects.isEmpty) return null;

    // 면적이 가장 큰 사물 선택.
    objects.sort(
      (a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(
        a.boundingBox.width * a.boundingBox.height,
      ),
    );
    final o = objects.first.boundingBox;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final box = PersonBox(
      left: (o.left / imgW).clamp(0.0, 1.0),
      top: (o.top / imgH).clamp(0.0, 1.0),
      width: (o.width / imgW).clamp(0.0, 1.0),
      height: (o.height / imgH).clamp(0.0, 1.0),
    );
    // 사물엔 얼굴 개념이 없어 face/person 모두 같은 박스(사물 모드는 face 미사용).
    return Detection(face: box, person: box);
  }

  InputImage? _toInputImage(CameraImage image, int rotationDegrees) {
    final rotation =
        InputImageRotationValue.fromRawValue(rotationDegrees) ??
        InputImageRotation.rotation0deg;
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw as int) ??
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
  void dispose() => _detector.close();
}
```

- [ ] **Step 3: CLAUDE.md 예외 목록 갱신**

`CLAUDE.md`의 규약 항목을 아래처럼 수정(‑ `object_detector.dart` 추가):

찾을 문자열:
```
- `lib/analysis/` 중 `person_detector.dart`·`analysis_engine.dart`를 제외한 파일은 **Flutter/plugin import 금지**(순수 Dart).
```
교체:
```
- `lib/analysis/` 중 `person_detector.dart`·`analysis_engine.dart`·`object_detector.dart`를 제외한 파일은 **Flutter/plugin import 금지**(순수 Dart).
```

- [ ] **Step 4: 정적 분석 + 빌드 확인**

Run: `dart analyze lib test`
Expected: No issues.
Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL. (새 ML Kit 모듈로 minSdk/compileSdk 문제가 나면 face_detection과 동일한 기존 gradle 설정으로 해결 — 신규 실패 시 보고.)

- [ ] **Step 5: 커밋**

```bash
git add lib/analysis/object_detector.dart pubspec.yaml pubspec.lock CLAUDE.md
git commit -m "feat: add ML Kit object detector for object mode"
```

---

### Task 4: ModeStore (모드 영속화)

선택 모드를 `SharedPreferences`에 저장/복원. 플러그인 래퍼지만 `setMockInitialValues`로 테스트 가능 → TDD.

**Files:**
- Create: `lib/camera/mode_store.dart`
- Test: `test/camera/mode_store_test.dart`

**Interfaces:**
- Consumes: `ShootingMode`/`ShootingModeWire`(Task 1). `shared_preferences`(이미 pubspec에 존재).
- Produces: `class ModeStore { Future<ShootingMode> load(); Future<void> save(ShootingMode mode); }` — 저장 키 `'shooting_mode'`. 값 없거나 이상하면 `load()`는 `ShootingMode.person`.

- [ ] **Step 1: 실패 테스트 작성**

`test/camera/mode_store_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttongson_camera/camera/mode_store.dart';
import 'package:ttongson_camera/models/shooting_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('저장 값이 없으면 기본은 person', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ModeStore().load(), ShootingMode.person);
  });

  test('save 후 load 하면 같은 모드', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ModeStore();
    await store.save(ShootingMode.object);
    expect(await store.load(), ShootingMode.object);
  });

  test('이상 값이 저장돼 있으면 person 으로 폴백', () async {
    SharedPreferences.setMockInitialValues({'shooting_mode': 'bogus'});
    expect(await ModeStore().load(), ShootingMode.person);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/camera/mode_store_test.dart`
Expected: FAIL — `mode_store.dart` 없음.

- [ ] **Step 3: 구현**

`lib/camera/mode_store.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shooting_mode.dart';

/// 선택한 촬영 모드를 로컬에 저장/복원한다(판단 없음).
class ModeStore {
  static const _key = 'shooting_mode';

  Future<ShootingMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ShootingModeWire.fromWire(prefs.getString(_key)) ??
        ShootingMode.person;
  }

  Future<void> save(ShootingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.wire);
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/camera/mode_store_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: 커밋**

```bash
git add lib/camera/mode_store.dart test/camera/mode_store_test.dart
git commit -m "feat: persist selected shooting mode via SharedPreferences"
```

---

### Task 5: ModeSelector 위젯 (하단 휠)

현재 모드 표시 + 전환 콜백만 갖는 렌더 위젯. 판단 로직 없음. 위젯 테스트로 탭 전환 검증.

**Files:**
- Create: `lib/overlay/mode_selector.dart`
- Test: `test/overlay/mode_selector_test.dart`

**Interfaces:**
- Consumes: `ShootingMode`/`ShootingModeWire`(Task 1).
- Produces: `class ModeSelector extends StatelessWidget` — 생성자 `ModeSelector({required ShootingMode current, required ValueChanged<ShootingMode> onChanged})`. 3개 라벨(인물/자연/사물)을 가로로 표시, 현재 모드 강조, 다른 라벨 탭 시 `onChanged` 호출. 좌우 수평 스와이프로 이전/다음 모드 이동.

- [ ] **Step 1: 실패 테스트 작성**

`test/overlay/mode_selector_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/overlay/mode_selector.dart';
import 'package:ttongson_camera/models/shooting_mode.dart';

void main() {
  testWidgets('세 모드 라벨을 모두 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeSelector(
            current: ShootingMode.person,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('인물'), findsOneWidget);
    expect(find.text('자연'), findsOneWidget);
    expect(find.text('사물'), findsOneWidget);
  });

  testWidgets('다른 라벨 탭 시 onChanged 로 해당 모드 전달', (tester) async {
    ShootingMode? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeSelector(
            current: ShootingMode.person,
            onChanged: (m) => picked = m,
          ),
        ),
      ),
    );
    await tester.tap(find.text('사물'));
    expect(picked, ShootingMode.object);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/overlay/mode_selector_test.dart`
Expected: FAIL — `mode_selector.dart` 없음.

- [ ] **Step 3: 구현**

`lib/overlay/mode_selector.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/shooting_mode.dart';

/// 하단 촬영 모드 선택 휠. 렌더 + 콜백만(판단 없음).
class ModeSelector extends StatelessWidget {
  final ShootingMode current;
  final ValueChanged<ShootingMode> onChanged;
  const ModeSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  static const _modes = ShootingMode.values;

  void _shift(int delta) {
    final i = _modes.indexOf(current);
    final next = i + delta;
    if (next >= 0 && next < _modes.length) onChanged(_modes[next]);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 좌로 밀면 다음, 우로 밀면 이전 모드.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < 0) _shift(1);
        if (v > 0) _shift(-1);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final m in _modes)
            GestureDetector(
              onTap: () {
                if (m != current) onChanged(m);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  m.label,
                  style: TextStyle(
                    color: m == current ? Colors.amber : Colors.white70,
                    fontSize: m == current ? 18 : 15,
                    fontWeight: m == current ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/overlay/mode_selector_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: 커밋**

```bash
git add lib/overlay/mode_selector.dart test/overlay/mode_selector_test.dart
git commit -m "feat: add bottom shooting-mode selector widget"
```

---

### Task 6: 백엔드 — mode 프롬프트 + targetBox 선택화 (재배포)

요청 `mode`로 프롬프트를 고르고 `targetBox`를 선택 필드로 완화. vitest TDD 후 재배포.

**Files:**
- Modify: `functions/src/advice.ts` (Mode 타입/parseMode, targetBox optional 파싱)
- Modify: `functions/src/schema.ts` (targetBox required 제거, 모드별 프롬프트 빌더)
- Modify: `functions/src/claude.ts` (mode 전달)
- Modify: `functions/src/advise.ts` (요청에서 mode 파싱·전달)
- Test: `functions/test/advice.test.ts` (parseMode, targetBox optional)
- Test: `functions/test/schema.test.ts` (모드별 프롬프트)

**Interfaces:**
- Produces:
  - `advice.ts`: `export type Mode = "person" | "nature" | "object";` · `export function parseMode(raw: unknown): Mode`(화이트리스트, 그 외 `"person"`) · `CompositionAdvice.targetBox?: TargetBox` · `parseAdvice`가 targetBox 없어도 성공.
  - `schema.ts`: `export function buildSystemPrompt(mode: Mode): string` · `export function buildUserText(mode: Mode, metrics?: OnDeviceMetrics): string` · `COMPOSITION_SCHEMA.required = ["headline", "rationale"]`.
  - `claude.ts`: `requestAdvice(apiKey, imageBase64, mediaType, metrics, mode)`.

- [ ] **Step 1: 실패 테스트 작성 — parseMode & optional targetBox**

`functions/test/advice.test.ts`에 추가(기존 파일에 append; 없으면 생성, 상단 import 포함):
```ts
import { describe, it, expect } from "vitest";
import { parseMode, parseAdvice } from "../src/advice.js";

describe("parseMode", () => {
  it("유효한 모드는 그대로", () => {
    expect(parseMode("person")).toBe("person");
    expect(parseMode("nature")).toBe("nature");
    expect(parseMode("object")).toBe("object");
  });
  it("이상값/누락은 person 폴백", () => {
    expect(parseMode("bogus")).toBe("person");
    expect(parseMode(undefined)).toBe("person");
    expect(parseMode(123)).toBe("person");
  });
});

describe("parseAdvice targetBox 선택화", () => {
  it("targetBox 없어도 성공(자연 모드)", () => {
    const advice = parseAdvice(
      JSON.stringify({ headline: "수평선을 아래 1/3에", rationale: "하늘을 넓게" }),
    );
    expect(advice.headline).toBe("수평선을 아래 1/3에");
    expect(advice.targetBox).toBeUndefined();
  });
  it("targetBox 있으면 검증해 포함", () => {
    const advice = parseAdvice(
      JSON.stringify({
        headline: "오른쪽으로",
        rationale: "3분할",
        targetBox: { x: 0.6, y: 0.3, width: 0.2, height: 0.4 },
      }),
    );
    expect(advice.targetBox).toEqual({ x: 0.6, y: 0.3, width: 0.2, height: 0.4 });
  });
  it("targetBox 형식이 틀리면 에러", () => {
    expect(() =>
      parseAdvice(JSON.stringify({ headline: "h", rationale: "r", targetBox: { x: "no" } })),
    ).toThrow();
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd functions && npm test`
Expected: FAIL — `parseMode` 미정의, targetBox 누락 시 기존 parseAdvice가 throw.

- [ ] **Step 3: advice.ts 구현**

`functions/src/advice.ts` 교체:
```ts
export interface TargetBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface CompositionAdvice {
  headline: string;
  targetBox?: TargetBox;
  rationale: string;
}

export interface OnDeviceMetrics {
  tiltDeg?: number;
  personCenterX?: number;
  personCenterY?: number;
  hasPerson?: boolean;
}

export type Mode = "person" | "nature" | "object";

/** 요청 mode 파싱. 화이트리스트 외 값/누락은 person 폴백. */
export function parseMode(raw: unknown): Mode {
  if (raw === "person" || raw === "nature" || raw === "object") return raw;
  return "person";
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
    throw new Error("targetBox 형식 오류");
  }
  return { x: t.x, y: t.y, width: t.width, height: t.height };
}

/** 모델이 반환한 JSON 텍스트를 CompositionAdvice로 검증·파싱. 위반 시 throw. */
export function parseAdvice(text: string): CompositionAdvice {
  const raw = JSON.parse(text); // JSON 아니면 SyntaxError throw
  if (typeof raw.headline !== "string" || typeof raw.rationale !== "string") {
    throw new Error("headline/rationale 누락");
  }
  // targetBox는 선택: 있으면 검증(틀리면 throw), 없으면 생략.
  const targetBox = raw.targetBox === undefined ? undefined : parseTargetBox(raw.targetBox);
  return { headline: raw.headline, targetBox, rationale: raw.rationale };
}
```

- [ ] **Step 4: schema.ts 구현 (모드별 프롬프트 + required 완화)**

`functions/src/schema.ts` 교체:
```ts
import type { Mode, OnDeviceMetrics } from "./advice.js";

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
  required: ["headline", "rationale"],
  additionalProperties: false,
} as const;

const _BASE =
  "당신은 사진 구도 코치입니다. 반드시 한국어로 간결하게 답합니다. " +
  "headline은 한 줄 핵심 조언, rationale은 한 문장 이유입니다. ";

const _TARGETBOX_RULE =
  "targetBox는 목표 영역을 정규화 좌표(0~1, 원점 좌상단)로 나타낸 사각형입니다. " +
  "x,y는 좌상단, width,height는 크기이며 모두 0~1 사이입니다. " +
  "가능하면 3분할선/교차점에 맞추고, 대상 전체가 프레임에 담기도록 정합니다. ";

/** 모드별 시스템 프롬프트. */
export function buildSystemPrompt(mode: Mode): string {
  switch (mode) {
    case "object":
      return (
        _BASE +
        "사진 속 주요 사물을 놓을 '더 좋은 목표 위치'를 정합니다. " +
        _TARGETBOX_RULE +
        "이미 구도가 좋으면 현재 사물 위치와 비슷한 목표를 반환하세요."
      );
    case "nature":
      return (
        _BASE +
        "풍경/자연 사진의 구도를 코치합니다. 수평선 위치·3분할·전경/원경 균형을 위주로 조언합니다. " +
        "배치할 단일 피사체 박스가 없으므로 targetBox는 반환하지 마세요."
      );
    case "person":
    default:
      return (
        _BASE +
        "인물·배경·위치를 고려해 인물을 놓을 '더 좋은 목표 위치'를 정합니다. " +
        _TARGETBOX_RULE +
        "이미 구도가 좋으면 현재 인물 위치와 비슷한 목표를 반환하세요."
      );
  }
}

/** 모드별 사용자 텍스트. 온디바이스 지표는 인물 모드에서만 참고로 덧붙인다. */
export function buildUserText(mode: Mode, metrics?: OnDeviceMetrics): string {
  const lines: string[] = [];
  switch (mode) {
    case "object":
      lines.push("이 장면에서 주요 사물을 놓을 더 좋은 목표 위치를 targetBox로 제안해 주세요.");
      break;
    case "nature":
      lines.push("이 풍경 사진의 구도를 어떻게 잡으면 좋을지 조언해 주세요. targetBox는 생략하세요.");
      break;
    case "person":
    default:
      lines.push("이 장면에서 인물을 놓을 더 좋은 목표 위치를 targetBox로 제안해 주세요.");
      if (
        metrics?.hasPerson &&
        metrics.personCenterX != null &&
        metrics.personCenterY != null
      ) {
        lines.push(
          `참고(온디바이스 감지): 현재 인물 중심이 정규화 좌표 (${metrics.personCenterX}, ${metrics.personCenterY})에 있습니다.`,
        );
      }
  }
  if (metrics?.tiltDeg != null) {
    lines.push(`참고: 현재 좌우 기울기 약 ${metrics.tiltDeg}도.`);
  }
  return lines.join("\n");
}
```

- [ ] **Step 5: claude.ts 구현 (mode 전달)**

`functions/src/claude.ts` 교체:
```ts
// functions/src/claude.ts
import Anthropic from "@anthropic-ai/sdk";
import { COMPOSITION_SCHEMA, buildSystemPrompt, buildUserText } from "./schema.js";
import { parseAdvice, type CompositionAdvice, type Mode, type OnDeviceMetrics } from "./advice.js";

export async function requestAdvice(
  apiKey: string,
  imageBase64: string,
  mediaType: "image/jpeg",
  metrics: OnDeviceMetrics | undefined,
  mode: Mode,
): Promise<CompositionAdvice> {
  const client = new Anthropic({ apiKey });
  // 구조화 출력: output_config.format(json_schema).
  const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: buildSystemPrompt(mode),
    output_config: {
      format: {
        type: "json_schema",
        schema: COMPOSITION_SCHEMA as { [key: string]: unknown },
      },
    },
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: { type: "base64", media_type: mediaType, data: imageBase64 },
          },
          { type: "text", text: buildUserText(mode, metrics) },
        ],
      },
    ],
  });
  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("모델 응답에 텍스트 블록이 없습니다");
  }
  return parseAdvice(textBlock.text);
}
```

- [ ] **Step 6: advise.ts 구현 (요청 mode 파싱·전달)**

`functions/src/advise.ts` 수정:
- import에 `parseMode` 추가: `import type { OnDeviceMetrics } from "./advice.js";` → `import { parseMode, type OnDeviceMetrics } from "./advice.js";`
- `data` 타입에 `mode?: unknown;` 추가.
- `requestAdvice(...)` 호출을 mode 포함으로:
```ts
      return await requestAdvice(
        ANTHROPIC_API_KEY.value(),
        data.imageBase64,
        "image/jpeg",
        data.metrics,
        parseMode(data.mode),
      );
```

- [ ] **Step 7: schema 프롬프트 테스트 작성**

`functions/test/schema.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { buildSystemPrompt, buildUserText, COMPOSITION_SCHEMA } from "../src/schema.js";

describe("모드별 프롬프트", () => {
  it("자연 모드는 targetBox 를 만들지 않도록 지시", () => {
    expect(buildSystemPrompt("nature")).toContain("targetBox는 반환하지 마세요");
    expect(buildUserText("nature")).toContain("targetBox는 생략");
  });
  it("사물 모드는 사물 목표 위치를 지시", () => {
    expect(buildSystemPrompt("object")).toContain("주요 사물");
    expect(buildUserText("object")).toContain("사물");
  });
  it("인물 모드는 인물 중심 지표를 참고에 포함", () => {
    const text = buildUserText("person", {
      hasPerson: true,
      personCenterX: 0.5,
      personCenterY: 0.4,
    });
    expect(text).toContain("현재 인물 중심");
  });
});

describe("스키마", () => {
  it("targetBox 는 required 가 아니다", () => {
    expect(COMPOSITION_SCHEMA.required).toEqual(["headline", "rationale"]);
  });
});
```

- [ ] **Step 8: 전체 통과 + 빌드 확인**

Run: `cd functions && npm test`
Expected: PASS (기존 + 신규 케이스).
Run: `cd functions && npm run build`
Expected: TypeScript 컴파일 성공(에러 0).

- [ ] **Step 9: 커밋**

```bash
git add functions/src/advice.ts functions/src/schema.ts functions/src/claude.ts functions/src/advise.ts functions/test/advice.test.ts functions/test/schema.test.ts
git commit -m "feat(functions): mode-specific prompts and optional targetBox"
```

- [ ] **Step 10: 재배포**

Run: `firebase deploy --only functions:advise`
Expected: Deploy complete. (배포는 기기 검증(Task 8) 전에 완료돼 있어야 자연 모드 텍스트 응답을 확인할 수 있다.)

---

### Task 7: CloudAdvisor에 mode 전달

앱 요청 페이로드에 `mode` 추가. 플러그인(FirebaseFunctions) 의존 → 정적 분석으로 검증.

**Files:**
- Modify: `lib/cloud/cloud_advisor.dart`

**Interfaces:**
- Consumes: `ShootingMode`/`ShootingModeWire`(Task 1). 백엔드 `mode` 계약(Task 6).
- Produces: `suggest(String jpegPath, GuideMetrics metrics, String deviceId, ShootingMode mode)` — 요청 데이터에 `'mode': mode.wire` 포함.

- [ ] **Step 1: 구현**

`lib/cloud/cloud_advisor.dart` 수정:
- import 추가: `import '../models/shooting_mode.dart';`
- `suggest` 시그니처에 `ShootingMode mode` 추가:
```dart
  Future<CompositionAdvice> suggest(
    String jpegPath,
    GuideMetrics metrics,
    String deviceId,
    ShootingMode mode,
  ) async {
```
- `callable.call` 페이로드에 mode 추가:
```dart
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64,
        'mediaType': 'image/jpeg',
        'deviceId': deviceId,
        'mode': mode.wire,
        'metrics': _metricsPayload(metrics),
      });
```

- [ ] **Step 2: 정적 분석 확인**

Run: `dart analyze lib test`
Expected: `camera_screen.dart`에서 `suggest` 호출 인자 부족 에러가 날 수 있음(Task 8에서 해결). 이 태스크만 단독 검증 시엔 `cloud_advisor.dart` 자체에 에러가 없어야 함. Task 8과 이어서 진행하므로, 8 완료 후 `dart analyze lib test`가 클린이어야 한다.

- [ ] **Step 3: 커밋**

```bash
git add lib/cloud/cloud_advisor.dart
git commit -m "feat: send shooting mode in cloud advice request"
```

---

### Task 8: camera_screen 통합 (모드 상태 배선)

모드 상태를 보유하고 감지기·엔진·오버레이·클라우드 요청·UI에 배선. 조립부 → 구현 + 기기 수동 검증.

**Files:**
- Modify: `lib/screens/camera_screen.dart`

**Interfaces:**
- Consumes: `ShootingMode`(T1), `AnalysisEngine.buildMetrics(mode:)`(T2), `MlKitObjectDetector`(T3), `ModeStore`(T4), `ModeSelector`(T5), `CloudAdvisor.suggest(...,mode)`(T7).

- [ ] **Step 1: import 추가**

`lib/screens/camera_screen.dart` 상단 import 블록에 추가:
```dart
import '../models/shooting_mode.dart';
import '../analysis/object_detector.dart';
import '../camera/mode_store.dart';
import '../overlay/mode_selector.dart';
```

- [ ] **Step 2: 필드 교체 — 감지기 2종 + 모드 상태**

`late final PersonDetector _detector;` 를 아래로 교체:
```dart
  late final PersonDetector _faceDetector;
  late final PersonDetector _objectDetector;
  final ModeStore _modeStore = ModeStore();
  ShootingMode _mode = ShootingMode.person;
```

- [ ] **Step 3: initState 배선**

`initState`의 감지기/엔진 생성 부분을 교체:
```dart
    _faceDetector = MlKitPersonDetector();
    _objectDetector = MlKitObjectDetector();
    _engine = AnalysisEngine(null);
```
(엔진은 감지기를 사용하지 않으므로 `null` 전달 — 감지는 화면에서 모드에 맞춰 호출.)

- [ ] **Step 4: 저장된 모드 복원**

`_init()`의 `await _camera.initialize();` 다음 줄에 추가:
```dart
      final savedMode = await _modeStore.load();
      if (mounted) setState(() => _mode = savedMode);
```

- [ ] **Step 5: _onFrame 모드별 감지**

`_onFrame` 본문을 교체:
```dart
  Future<void> _onFrame(CameraImage image) async {
    if (_processing) return; // 스로틀: 재진입 방지
    _processing = true;
    try {
      final mode = _mode;
      Detection? detection;
      if (mode == ShootingMode.person) {
        detection = await _faceDetector.detect(image, _camera.sensorOrientation);
      } else if (mode == ShootingMode.object) {
        detection = await _objectDetector.detect(image, _camera.sensorOrientation);
      }
      // 자연 모드: 감지 없음.
      final m = _engine.buildMetrics(
        person: detection?.person,
        face: detection?.face,
        sensor: _sensor,
        mode: mode,
      );
      if (mounted) setState(() => _metrics = m);
    } catch (_) {
      // 프레임 단위 실패는 무시(다음 프레임 계속)
    } finally {
      _processing = false;
    }
  }
```

- [ ] **Step 6: 모드 전환 핸들러 추가**

`_onFrame` 아래에 추가:
```dart
  Future<void> _onModeChanged(ShootingMode mode) async {
    setState(() {
      _mode = mode;
      _advice = null; // 이전 추천/시각 가이드 무효화
      // 이전 대상 박스 즉시 제거(다음 프레임까지 잔상 방지).
      _metrics = GuideMetrics(
        tilt: const TiltInfo(rollDegrees: 0, isLevel: true, hint: ''),
        angle: const AngleAdvice(pitchDegrees: 0, hint: ''),
      );
    });
    await _modeStore.save(mode);
  }
```

- [ ] **Step 7: _requestAdvice에 mode 전달**

`_requestAdvice` 안의 suggest 호출을 교체:
```dart
      final advice = await _advisor.suggest(framePath, _metrics, deviceId, _mode);
```

- [ ] **Step 8: dispose 두 감지기 정리**

`_detector.dispose();` 를 교체:
```dart
    _faceDetector.dispose();
    _objectDetector.dispose();
```

- [ ] **Step 9: UI — 촬영 버튼 위에 ModeSelector**

`build`의 하단 버튼 `Positioned(bottom: 40, ...)`에서 `child: Row(...)`를 아래 Column으로 감싸 교체:
```dart
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModeSelector(current: _mode, onChanged: _onModeChanged),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        _showGrid ? Icons.grid_on : Icons.grid_off,
                        color: Colors.white,
                        size: 32,
                      ),
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
                    IconButton(
                      icon: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _requestAdvice,
                    ),
                  ],
                ),
              ],
            ),
          ),
```

- [ ] **Step 10: verify 게이트**

Run: `bash tool/verify.sh`
Expected: format 클린 + `dart analyze lib test` No issues + `flutter test` 전부 PASS.

- [ ] **Step 11: 기기 수동 검증**

Run: `flutter run` (실기기)
확인:
- 하단 휠로 인물/자연/사물 전환됨. 앱 재실행 시 마지막 모드 유지.
- 인물: 얼굴 기반 가이드(헤드룸·눈높이 등) 동작.
- 사물: 물건에 박스/중앙·줌 힌트, ✨ 추천 시 시각 targetBox 표시.
- 자연: 격자·수평계만, ✨ 추천은 텍스트 카드만(박스 없음).
- 모드 전환 시 이전 추천 박스가 즉시 사라짐.

- [ ] **Step 12: 커밋**

```bash
git add lib/screens/camera_screen.dart
git commit -m "feat: wire shooting modes into camera screen"
```

---

## 완료 정의

하단 휠로 인물/자연/사물 전환이 되고, 모드별 온디바이스 가이드와 ✨ 추천이 각각 동작한다. 순수 로직(모드 분기·모드 enum·모드 저장) + 백엔드 스키마/파서/프롬프트 테스트 통과, `tool/verify.sh` 통과, 백엔드 재배포 후 실기기에서 세 모드 모두 확인.
