# 커뮤니티 계획 C — 개인정보 가림 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 갤러리에서 고른 사진을 업로드 전 기기 내에서 가린다 — 얼굴 자동 모자이크(기본 ON, 토글 가능) + 수동 박스 모자이크, EXIF 제거된 JPEG만 업로드.

**Architecture:** 순수 데이터(`MaskRegion`)와 순수 계산(`masking.dart`)은 TDD. 얼굴 감지·픽셀 합성은 `mask_processor.dart`가 아이솔레이트에서 수행. `MaskEditorScreen`이 편집 UI, `create_post_screen.dart`가 선택→[가림]→캡션→업로드를 조립. 계획 B의 `PostRepository.createPost`를 처리된 File로 재사용.

**Tech Stack:** Flutter(Dart), `google_ml_kit`(google_mlkit_face_detection), `image`(픽셀 처리), `image_picker`, `path_provider`, `firebase_storage`. **신규 의존성 없음**(모두 기존 존재).

## Global Constraints

- 좌표계: 모든 가림 좌표는 정규화 0.0~1.0, 원점 좌상단(x→오른쪽, y→아래). (CLAUDE.md 전역 규약)
- `MaskRegion`·`masking.dart`는 **순수 Dart** — Flutter/plugin/`image` import 금지. `mask_processor.dart`·화면만 플러그인 의존.
- 가림 방식은 **모자이크 한 가지**. 방식 선택·스티커 없음(YAGNI, C2에서).
- 처리 파이프라인: EXIF 방향 반영 디코드 → 최장변 **1600px** 축소(업스케일 금지) → enabled 영역 모자이크 → JPEG **품질 85**, EXIF 미포함.
- 모자이크 강도 기본값: 영역 긴 변 **약 12블록**(`targetBlocks=12`), 최소 블록 **4px**.
- **원본 미전송 보장**: 작성 흐름은 항상 처리 파이프라인 결과 File만 업로드한다(가림 0개여도 재인코딩).
- 순수 로직 엄격 TDD. 감지·아이솔레이트·UI는 구현 + 기기 수동 검증(억지 단위테스트 금지).
- 게이트: 앱 `tool/verify.sh`. 정적분석 `dart analyze lib test`(**`flutter analyze` 금지**). Flutter SDK `/Users/soonbok/flutter/bin`.
- 커밋: Conventional Commits + `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

```
lib/community/
  models/mask_region.dart        # (신규) 순수 값 객체
  masking.dart                   # (신규) 순수 계산: 픽셀 매핑·블록·정규화·좌표변환
  mask_processor.dart            # (신규) 비순수: 얼굴 감지 + 아이솔레이트 합성
  screens/mask_editor_screen.dart# (신규) 가림 편집 UI
  screens/create_post_screen.dart# (수정) 선택→[가림]→캡션→업로드
test/community/
  mask_region_test.dart          # (신규)
  masking_test.dart              # (신규)
```

---

### Task 1: `MaskRegion` 모델

**Files:**
- Create: `lib/community/models/mask_region.dart`
- Test: `test/community/mask_region_test.dart`

**Interfaces:**
- Produces: `class MaskRegion { double left, top, width, height; bool isAuto; bool enabled; double get right; double get bottom; MaskRegion copyWith({bool? enabled}); == / hashCode }` — 생성자 `MaskRegion({required left, top, width, height, isAuto = false, enabled = true})`.

- [ ] **Step 1: 실패 테스트** — `test/community/mask_region_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/mask_region.dart';

void main() {
  test('기본값: isAuto false, enabled true, right/bottom 계산', () {
    const r = MaskRegion(left: 0.1, top: 0.2, width: 0.3, height: 0.4);
    expect(r.isAuto, isFalse);
    expect(r.enabled, isTrue);
    expect(r.right, closeTo(0.4, 1e-9));
    expect(r.bottom, closeTo(0.6, 1e-9));
  });

  test('copyWith(enabled) 은 나머지 필드를 보존', () {
    const r = MaskRegion(
      left: 0.1, top: 0.2, width: 0.3, height: 0.4, isAuto: true);
    final off = r.copyWith(enabled: false);
    expect(off.enabled, isFalse);
    expect(off.isAuto, isTrue);
    expect(off.left, 0.1);
    expect(off.width, 0.3);
  });

  test('동등성: 모든 필드가 같으면 ==', () {
    const a = MaskRegion(left: 0, top: 0, width: 0.5, height: 0.5, isAuto: true);
    const b = MaskRegion(left: 0, top: 0, width: 0.5, height: 0.5, isAuto: true);
    const c = MaskRegion(left: 0, top: 0, width: 0.5, height: 0.5);
    expect(a, equals(b));
    expect(a == c, isFalse);
  });
}
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/community/mask_region_test.dart` → FAIL (파일 없음).
- [ ] **Step 3: 구현** — `lib/community/models/mask_region.dart`:

```dart
// lib/community/models/mask_region.dart
// 순수 Dart — Flutter/plugin/image import 금지.

/// 정규화(0.0~1.0, 원점 좌상단) 좌표계의 가림 영역.
class MaskRegion {
  final double left;
  final double top;
  final double width;
  final double height;

  /// 얼굴 자동 감지로 만든 영역인지.
  final bool isAuto;

  /// 처리 대상 여부. enabled 영역만 모자이크로 합성한다.
  final bool enabled;

  const MaskRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.isAuto = false,
    this.enabled = true,
  });

  double get right => left + width;
  double get bottom => top + height;

  MaskRegion copyWith({bool? enabled}) => MaskRegion(
    left: left,
    top: top,
    width: width,
    height: height,
    isAuto: isAuto,
    enabled: enabled ?? this.enabled,
  );

  @override
  bool operator ==(Object other) =>
      other is MaskRegion &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height &&
      other.isAuto == isAuto &&
      other.enabled == enabled;

  @override
  int get hashCode =>
      Object.hash(left, top, width, height, isAuto, enabled);
}
```

- [ ] **Step 4:** `flutter test test/community/mask_region_test.dart` → PASS (3).
- [ ] **Step 5: 커밋**

```bash
git add lib/community/models/mask_region.dart test/community/mask_region_test.dart
git commit -m "feat: MaskRegion 가림 영역 값 객체"
```

---

### Task 2: `masking.dart` 이미지 기하 순수 함수

**Files:**
- Create: `lib/community/masking.dart`
- Test: `test/community/masking_test.dart`

**Interfaces:**
- Consumes: `MaskRegion`(Task 1).
- Produces:
  - `class IntRect { int left, top, width, height; int get right; int get bottom; == }`
  - `IntRect pixelRect(MaskRegion r, int imgW, int imgH)` — 경계 clamp.
  - `int mosaicBlockSize(int rectW, int rectH, {int targetBlocks = 12, int minBlock = 4})`
  - `MaskRegion faceBoxToRegion(double boxLeft, double boxTop, double boxWidth, double boxHeight, int imgW, int imgH)` — `isAuto: true`.
  - `class Dimensions { int width, height; == }`
  - `Dimensions fitDimensions(int w, int h, int maxLongSide)` — 업스케일 금지.

- [ ] **Step 1: 실패 테스트** — `test/community/masking_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/masking.dart';
import 'package:ttongson_camera/community/models/mask_region.dart';

void main() {
  group('pixelRect', () {
    test('정규화 영역을 픽셀 사각형으로', () {
      const r = MaskRegion(left: 0.25, top: 0.5, width: 0.25, height: 0.25);
      final pr = pixelRect(r, 400, 200);
      expect(pr.left, 100);
      expect(pr.top, 100);
      expect(pr.right, lessThanOrEqualTo(400));
      expect(pr.width, greaterThan(0));
    });

    test('이미지 경계를 벗어나면 clamp', () {
      const r = MaskRegion(left: 0.9, top: 0.9, width: 0.5, height: 0.5);
      final pr = pixelRect(r, 100, 100);
      expect(pr.left, 90);
      expect(pr.right, 100);
      expect(pr.bottom, 100);
      expect(pr.width, lessThanOrEqualTo(10));
    });

    test('음수 시작도 0으로 clamp', () {
      const r = MaskRegion(left: -0.1, top: -0.1, width: 0.3, height: 0.3);
      final pr = pixelRect(r, 100, 100);
      expect(pr.left, 0);
      expect(pr.top, 0);
    });
  });

  group('mosaicBlockSize', () {
    test('긴 변 기준 약 targetBlocks 개 블록', () {
      // 긴 변 120px, 12블록 → 블록 10px
      expect(mosaicBlockSize(120, 60), 10);
    });
    test('아주 작은 영역은 minBlock floor', () {
      // 긴 변 12px / 12 = 1 → minBlock 4로 상승
      expect(mosaicBlockSize(12, 8), 4);
    });
    test('minBlock 조정 가능', () {
      expect(mosaicBlockSize(12, 8, minBlock: 2), 2);
    });
  });

  group('faceBoxToRegion', () {
    test('픽셀 박스를 정규화하고 isAuto true', () {
      final r = faceBoxToRegion(100, 50, 200, 100, 400, 200);
      expect(r.left, closeTo(0.25, 1e-9));
      expect(r.top, closeTo(0.25, 1e-9));
      expect(r.width, closeTo(0.5, 1e-9));
      expect(r.height, closeTo(0.5, 1e-9));
      expect(r.isAuto, isTrue);
      expect(r.enabled, isTrue);
    });
    test('이미지 경계를 넘는 박스는 0~1로 clamp', () {
      final r = faceBoxToRegion(-20, -20, 500, 500, 400, 400);
      expect(r.left, 0);
      expect(r.top, 0);
      expect(r.right, lessThanOrEqualTo(1.0));
      expect(r.bottom, lessThanOrEqualTo(1.0));
    });
  });

  group('fitDimensions', () {
    test('최장변이 상한을 넘으면 비율 유지 축소', () {
      final d = fitDimensions(3200, 1600, 1600);
      expect(d.width, 1600);
      expect(d.height, 800);
    });
    test('이미 작으면 그대로(업스케일 금지)', () {
      final d = fitDimensions(800, 600, 1600);
      expect(d.width, 800);
      expect(d.height, 600);
    });
  });
}
```

- [ ] **Step 2:** `flutter test test/community/masking_test.dart` → FAIL.
- [ ] **Step 3: 구현** — `lib/community/masking.dart`:

```dart
// lib/community/masking.dart
// 순수 Dart — Flutter/plugin/image import 금지.
import 'models/mask_region.dart';

/// 정수 픽셀 사각형(순수 값 타입).
class IntRect {
  final int left;
  final int top;
  final int width;
  final int height;
  const IntRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  int get right => left + width;
  int get bottom => top + height;

  @override
  bool operator ==(Object other) =>
      other is IntRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// 정규화 영역을 이미지 픽셀 사각형으로 변환하고 경계로 clamp.
IntRect pixelRect(MaskRegion r, int imgW, int imgH) {
  var l = (r.left * imgW).floor();
  var t = (r.top * imgH).floor();
  var right = (r.right * imgW).ceil();
  var bottom = (r.bottom * imgH).ceil();
  if (l < 0) l = 0;
  if (t < 0) t = 0;
  if (right > imgW) right = imgW;
  if (bottom > imgH) bottom = imgH;
  final w = right - l < 0 ? 0 : right - l;
  final h = bottom - t < 0 ? 0 : bottom - t;
  return IntRect(left: l, top: t, width: w, height: h);
}

/// 영역 긴 변이 약 targetBlocks개 블록으로 픽셀화되도록 블록 크기 계산.
int mosaicBlockSize(
  int rectW,
  int rectH, {
  int targetBlocks = 12,
  int minBlock = 4,
}) {
  final longEdge = rectW > rectH ? rectW : rectH;
  var b = (longEdge / targetBlocks).floor();
  if (b < minBlock) b = minBlock;
  if (b < 1) b = 1;
  return b;
}

/// 감지된 픽셀 박스를 정규화 MaskRegion(isAuto: true)으로. 0~1로 clamp.
MaskRegion faceBoxToRegion(
  double boxLeft,
  double boxTop,
  double boxWidth,
  double boxHeight,
  int imgW,
  int imgH,
) {
  var l = boxLeft / imgW;
  var t = boxTop / imgH;
  var w = boxWidth / imgW;
  var h = boxHeight / imgH;
  if (l < 0) {
    w += l;
    l = 0;
  }
  if (t < 0) {
    h += t;
    t = 0;
  }
  if (l + w > 1) w = 1 - l;
  if (t + h > 1) h = 1 - t;
  if (w < 0) w = 0;
  if (h < 0) h = 0;
  return MaskRegion(left: l, top: t, width: w, height: h, isAuto: true);
}

/// 축소 치수(순수 값 타입).
class Dimensions {
  final int width;
  final int height;
  const Dimensions(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      other is Dimensions && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// 최장변이 상한을 넘으면 비율 유지 축소, 아니면 원본 유지(업스케일 금지).
Dimensions fitDimensions(int w, int h, int maxLongSide) {
  final longEdge = w > h ? w : h;
  if (longEdge <= maxLongSide) return Dimensions(w, h);
  final scale = maxLongSide / longEdge;
  return Dimensions((w * scale).round(), (h * scale).round());
}
```

- [ ] **Step 4:** `flutter test test/community/masking_test.dart` → PASS (10).
- [ ] **Step 5: 커밋**

```bash
git add lib/community/masking.dart test/community/masking_test.dart
git commit -m "feat: masking 순수 기하 함수(pixelRect·모자이크블록·정규화·축소)"
```

---

### Task 3: `masking.dart` 위젯↔정규화 좌표 변환 헬퍼

**Files:**
- Modify: `lib/community/masking.dart`
- Modify: `test/community/masking_test.dart`

**Interfaces:**
- Produces:
  - `class FitRect { double left, top, width, height; == }`
  - `FitRect containRect(double boxW, double boxH, double imgW, double imgH)` — `BoxFit.contain`으로 배치된 이미지 표시 사각형(레터박스 오프셋 포함).
  - `class NormPoint { double x, y; == }`
  - `NormPoint normFromWidget(double dx, double dy, FitRect fit)` — 위젯 로컬 좌표를 0~1 정규화로(표시 영역 밖은 clamp).

- [ ] **Step 1: 실패 테스트** — `test/community/masking_test.dart`의 `main()` 안에 group 추가:

```dart
  group('containRect (BoxFit.contain)', () {
    test('가로가 더 넓은 이미지: 너비 맞춤, 상하 레터박스', () {
      // box 200x200, image 400x200(aspect 2) → w=200, h=100, top=50
      final fit = containRect(200, 200, 400, 200);
      expect(fit.width, closeTo(200, 1e-6));
      expect(fit.height, closeTo(100, 1e-6));
      expect(fit.left, closeTo(0, 1e-6));
      expect(fit.top, closeTo(50, 1e-6));
    });
    test('세로가 더 긴 이미지: 높이 맞춤, 좌우 레터박스', () {
      // box 200x200, image 100x400(aspect 0.25) → h=200, w=50, left=75
      final fit = containRect(200, 200, 100, 400);
      expect(fit.height, closeTo(200, 1e-6));
      expect(fit.width, closeTo(50, 1e-6));
      expect(fit.top, closeTo(0, 1e-6));
      expect(fit.left, closeTo(75, 1e-6));
    });
  });

  group('normFromWidget', () {
    test('표시 영역 내부 좌표를 정규화', () {
      final fit = containRect(200, 200, 400, 200); // left0 top50 w200 h100
      final p = normFromWidget(100, 100, fit); // 중앙
      expect(p.x, closeTo(0.5, 1e-6));
      expect(p.y, closeTo(0.5, 1e-6));
    });
    test('표시 영역 밖은 0~1로 clamp', () {
      final fit = containRect(200, 200, 400, 200);
      final p = normFromWidget(-50, 0, fit);
      expect(p.x, 0.0);
      expect(p.y, 0.0);
    });
  });
```

- [ ] **Step 2:** `flutter test test/community/masking_test.dart` → FAIL (containRect/normFromWidget 없음).
- [ ] **Step 3: 구현** — `lib/community/masking.dart` 끝에 추가:

```dart
/// BoxFit.contain으로 배치된 이미지의 표시 사각형(위젯 좌표계, 레터박스 포함).
class FitRect {
  final double left;
  final double top;
  final double width;
  final double height;
  const FitRect(this.left, this.top, this.width, this.height);

  @override
  bool operator ==(Object other) =>
      other is FitRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// box(boxW×boxH) 안에 image(imgW×imgH)를 contain으로 배치했을 때의 표시 사각형.
FitRect containRect(double boxW, double boxH, double imgW, double imgH) {
  final boxAspect = boxW / boxH;
  final imgAspect = imgW / imgH;
  double w;
  double h;
  if (imgAspect > boxAspect) {
    // 이미지가 더 넓다 → 너비 맞춤
    w = boxW;
    h = boxW / imgAspect;
  } else {
    // 이미지가 더 높다(또는 동일) → 높이 맞춤
    h = boxH;
    w = boxH * imgAspect;
  }
  final left = (boxW - w) / 2;
  final top = (boxH - h) / 2;
  return FitRect(left, top, w, h);
}

/// 정규화 점(순수 값 타입).
class NormPoint {
  final double x;
  final double y;
  const NormPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is NormPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// 위젯 로컬 좌표(dx,dy)를 표시 사각형 fit 기준 정규화(0~1)로. 밖은 clamp.
NormPoint normFromWidget(double dx, double dy, FitRect fit) {
  final x = ((dx - fit.left) / fit.width).clamp(0.0, 1.0);
  final y = ((dy - fit.top) / fit.height).clamp(0.0, 1.0);
  return NormPoint(x, y);
}
```

- [ ] **Step 4:** `flutter test test/community/masking_test.dart` → PASS (14).
- [ ] **Step 5: 커밋**

```bash
git add lib/community/masking.dart test/community/masking_test.dart
git commit -m "feat: masking 위젯↔정규화 좌표 변환 헬퍼(containRect·normFromWidget)"
```

---

### Task 4: `mask_processor.dart` — 얼굴 감지 + 아이솔레이트 합성

**Files:**
- Create: `lib/community/mask_processor.dart`

**Interfaces:**
- Consumes: `MaskRegion`(T1), `pixelRect`·`mosaicBlockSize`·`faceBoxToRegion`·`fitDimensions`·`IntRect`(T2).
- Produces:
  - `Future<List<MaskRegion>> detectFaceRegions(File src)`
  - `Future<File> applyMasks(File src, List<MaskRegion> regions)`

> 순수 테스트 없음(플러그인·아이솔레이트·파일 IO). 게이트는 `dart analyze`. 실동작은 Task 7 기기 검증.

- [ ] **Step 1: 구현** — `lib/community/mask_processor.dart`:

```dart
// lib/community/mask_processor.dart
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'masking.dart';
import 'models/mask_region.dart';

/// 정지 이미지에서 얼굴을 감지해 자동 가림 영역을 만든다.
/// 감지 실패/미감지/디코딩 실패 시 빈 리스트(비차단).
Future<List<MaskRegion>> detectFaceRegions(File src) async {
  final detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  try {
    final faces = await detector.processImage(
      InputImage.fromFilePath(src.path),
    );
    if (faces.isEmpty) return const [];
    // ML Kit의 얼굴 박스는 EXIF 방향이 반영된 이미지 좌표.
    // 정규화 기준도 방향 반영 크기를 써야 하므로 bakeOrientation 후 크기 사용.
    final bytes = await src.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const [];
    final baked = img.bakeOrientation(decoded);
    final w = baked.width;
    final h = baked.height;
    return faces.map((f) {
      final b = f.boundingBox;
      return faceBoxToRegion(b.left, b.top, b.width, b.height, w, h);
    }).toList();
  } catch (_) {
    return const [];
  } finally {
    await detector.close();
  }
}

/// enabled 영역을 모자이크로 가린 새 JPEG 임시 파일을 만든다.
/// 픽셀 처리는 아이솔레이트에서 수행. 원본은 변경하지 않는다.
Future<File> applyMasks(File src, List<MaskRegion> regions) async {
  final bytes = await src.readAsBytes();
  final enabled = regions.where((r) => r.enabled).toList();
  final jpeg = await Isolate.run(() => _composite(bytes, enabled));
  final dir = await getTemporaryDirectory();
  final out = File(
    '${dir.path}/masked_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await out.writeAsBytes(jpeg);
  return out;
}

/// 아이솔레이트에서 실행: 디코드→방향 반영→축소→모자이크→JPEG 인코드.
Uint8List _composite(Uint8List bytes, List<MaskRegion> regions) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('이미지 디코딩 실패');
  }
  var image = img.bakeOrientation(decoded);
  final dim = fitDimensions(image.width, image.height, 1600);
  if (dim.width != image.width || dim.height != image.height) {
    image = img.copyResize(image, width: dim.width, height: dim.height);
  }
  for (final r in regions) {
    final pr = pixelRect(r, image.width, image.height);
    if (pr.width <= 0 || pr.height <= 0) continue;
    _mosaic(image, pr);
  }
  return img.encodeJpg(image, quality: 85);
}

/// 영역을 다운스케일(평균)→업스케일(nearest)로 픽셀화해 원본에 덮어쓴다.
void _mosaic(img.Image image, IntRect pr) {
  final b = mosaicBlockSize(pr.width, pr.height);
  final smallW = (pr.width / b).ceil().clamp(1, pr.width);
  final smallH = (pr.height / b).ceil().clamp(1, pr.height);
  final region = img.copyCrop(
    image,
    x: pr.left,
    y: pr.top,
    width: pr.width,
    height: pr.height,
  );
  final down = img.copyResize(
    region,
    width: smallW,
    height: smallH,
    interpolation: img.Interpolation.average,
  );
  final up = img.copyResize(
    down,
    width: pr.width,
    height: pr.height,
    interpolation: img.Interpolation.nearest,
  );
  img.compositeImage(image, up, dstX: pr.left, dstY: pr.top);
}
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/mask_processor.dart` → No issues found!
  - 만약 `image` 4.x API(`copyCrop`/`copyResize`의 명명 인자, `Interpolation`, `compositeImage`, `bakeOrientation`)에서 분석 에러가 나면, 설치된 버전의 시그니처를 확인해 동일 동작으로 맞춘 뒤 concern으로 보고한다(임의 동작 변경 금지).
- [ ] **Step 3: 커밋**

```bash
git add lib/community/mask_processor.dart
git commit -m "feat: mask_processor — 얼굴 감지 + 아이솔레이트 모자이크 합성"
```

---

### Task 5: `MaskEditorScreen` 가림 편집 화면

**Files:**
- Create: `lib/community/screens/mask_editor_screen.dart`

**Interfaces:**
- Consumes: `MaskRegion`(T1), `containRect`·`normFromWidget`·`FitRect`(T3), `detectFaceRegions`·`applyMasks`(T4).
- Produces: `class MaskEditorScreen extends StatefulWidget { MaskEditorScreen({required File image}) }`. `Navigator.pop`으로 처리된 `File`(완료) 또는 `null`(취소) 반환.

> UI/플러그인 태스크: 구현 + 기기 검증. 게이트는 `dart analyze`.

- [ ] **Step 1: 구현** — `lib/community/screens/mask_editor_screen.dart`:

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../masking.dart';
import '../mask_processor.dart';
import '../models/mask_region.dart';

/// 업로드 전 가림 편집. 얼굴 자동 모자이크(기본 ON, 토글) + 수동 박스.
/// 완료 시 처리된 JPEG File을 반환, 취소 시 null.
class MaskEditorScreen extends StatefulWidget {
  final File image;
  const MaskEditorScreen({super.key, required this.image});

  @override
  State<MaskEditorScreen> createState() => _MaskEditorScreenState();
}

class _MaskEditorScreenState extends State<MaskEditorScreen> {
  final List<MaskRegion> _regions = [];
  ui.Image? _decoded; // 표시 이미지 크기(종횡비) 계산용
  int? _selected;
  bool _detecting = true;
  bool _processing = false;

  // 드래그 진행 상태(정규화 좌표)
  NormPoint? _dragStart;
  NormPoint? _dragNow;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 이미지 종횡비 확보
    final bytes = await widget.image.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    // 얼굴 자동 감지
    final faces = await detectFaceRegions(widget.image);
    if (!mounted) return;
    setState(() {
      _decoded = decoded;
      _regions.addAll(faces);
      _detecting = false;
    });
  }

  Future<void> _done() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final out = await applyMasks(widget.image, _regions);
      if (mounted) Navigator.pop(context, out);
    } catch (_) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가림 처리에 실패했어요')),
        );
      }
    }
  }

  void _onPanStart(Offset local, FitRect fit) {
    setState(() {
      _dragStart = normFromWidget(local.dx, local.dy, fit);
      _dragNow = _dragStart;
      _selected = null;
    });
  }

  void _onPanUpdate(Offset local, FitRect fit) {
    setState(() => _dragNow = normFromWidget(local.dx, local.dy, fit));
  }

  void _onPanEnd() {
    final a = _dragStart;
    final b = _dragNow;
    _dragStart = null;
    _dragNow = null;
    if (a == null || b == null) return;
    final left = a.x < b.x ? a.x : b.x;
    final top = a.y < b.y ? a.y : b.y;
    final w = (a.x - b.x).abs();
    final h = (a.y - b.y).abs();
    // 너무 작은 드래그는 무시(오탭 방지)
    if (w < 0.02 || h < 0.02) {
      setState(() {});
      return;
    }
    setState(() {
      _regions.add(
        MaskRegion(left: left, top: top, width: w, height: h),
      );
      _selected = _regions.length - 1;
    });
  }

  void _onTap(Offset local, FitRect fit) {
    final p = normFromWidget(local.dx, local.dy, fit);
    int? hit;
    for (var i = _regions.length - 1; i >= 0; i--) {
      final r = _regions[i];
      if (p.x >= r.left && p.x <= r.right && p.y >= r.top && p.y <= r.bottom) {
        hit = i;
        break;
      }
    }
    setState(() => _selected = hit);
  }

  void _deleteSelected() {
    final i = _selected;
    if (i == null) return;
    setState(() {
      _regions.removeAt(i);
      _selected = null;
    });
  }

  void _toggleSelected() {
    final i = _selected;
    if (i == null) return;
    setState(() {
      _regions[i] = _regions[i].copyWith(enabled: !_regions[i].enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final decoded = _decoded;
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('개인정보 가림'),
        actions: [
          TextButton(
            onPressed: _processing ? null : _done,
            child: const Text('완료'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: (decoded == null)
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final fit = containRect(
                        constraints.maxWidth,
                        constraints.maxHeight,
                        decoded.width.toDouble(),
                        decoded.height.toDouble(),
                      );
                      return GestureDetector(
                        onPanStart: (d) => _onPanStart(d.localPosition, fit),
                        onPanUpdate: (d) => _onPanUpdate(d.localPosition, fit),
                        onPanEnd: (_) => _onPanEnd(),
                        onTapUp: (d) => _onTap(d.localPosition, fit),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: Image.file(
                                widget.image,
                                fit: BoxFit.contain,
                              ),
                            ),
                            CustomPaint(
                              painter: _MaskPainter(
                                regions: _regions,
                                selected: _selected,
                                fit: fit,
                                dragStart: _dragStart,
                                dragNow: _dragNow,
                              ),
                            ),
                            if (_detecting || _processing)
                              const ColoredBox(
                                color: Colors.black45,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _Controls(
            hasSelection: selected != null,
            selectedEnabled:
                selected != null ? _regions[selected].enabled : false,
            onDelete: _deleteSelected,
            onToggle: _toggleSelected,
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final bool hasSelection;
  final bool selectedEnabled;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  const _Controls({
    required this.hasSelection,
    required this.selectedEnabled,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Expanded(
              child: Text(
                '드래그로 가릴 영역 추가 · 탭으로 선택',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            TextButton.icon(
              onPressed: hasSelection ? onToggle : null,
              icon: Icon(
                selectedEnabled ? Icons.visibility_off : Icons.visibility,
              ),
              label: Text(selectedEnabled ? '가림 끄기' : '가림 켜기'),
            ),
            TextButton.icon(
              onPressed: hasSelection ? onDelete : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('삭제'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  final List<MaskRegion> regions;
  final int? selected;
  final FitRect fit;
  final NormPoint? dragStart;
  final NormPoint? dragNow;
  _MaskPainter({
    required this.regions,
    required this.selected,
    required this.fit,
    required this.dragStart,
    required this.dragNow,
  });

  Rect _toWidget(double l, double t, double w, double h) => Rect.fromLTWH(
    fit.left + l * fit.width,
    fit.top + t * fit.height,
    w * fit.width,
    h * fit.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < regions.length; i++) {
      final r = regions[i];
      final rect = _toWidget(r.left, r.top, r.width, r.height);
      final fill = Paint()
        ..color = r.enabled
            ? Colors.black.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.15);
      canvas.drawRect(rect, fill);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == selected ? 3 : 1.5
        ..color = i == selected
            ? Colors.amber
            : (r.enabled ? Colors.white70 : Colors.white30);
      canvas.drawRect(rect, border);
    }
    // 드래그 프리뷰
    final a = dragStart;
    final b = dragNow;
    if (a != null && b != null) {
      final left = a.x < b.x ? a.x : b.x;
      final top = a.y < b.y ? a.y : b.y;
      final w = (a.x - b.x).abs();
      final h = (a.y - b.y).abs();
      final rect = _toWidget(left, top, w, h);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.amberAccent;
      canvas.drawRect(rect, p);
    }
  }

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.regions != regions ||
      old.selected != selected ||
      old.fit != fit ||
      old.dragStart != dragStart ||
      old.dragNow != dragNow;
}
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/screens/mask_editor_screen.dart` → No issues found!
  - `Color.withValues`는 Flutter 3.27+ API. 설치된 Flutter가 더 낮아 분석 에러가 나면 `withOpacity(...)`로 대체하고 concern 보고.
- [ ] **Step 3: 커밋**

```bash
git add lib/community/screens/mask_editor_screen.dart
git commit -m "feat: MaskEditorScreen — 얼굴 자동+수동 박스 가림 편집"
```

---

### Task 6: 작성 흐름에 가림 단계 삽입

**Files:**
- Modify: `lib/community/screens/create_post_screen.dart`

**Interfaces:**
- Consumes: `MaskEditorScreen`(T5).

- [ ] **Step 1: import 추가** — `lib/community/screens/create_post_screen.dart`의 import 블록에 추가:

```dart
import 'mask_editor_screen.dart';
```

- [ ] **Step 2: `_pick()` 교체** — 기존 `_pick()`(사진 선택 후 곧바로 `_image` 설정)을 가림 편집 단계를 거치도록 교체:

```dart
  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    final masked = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => MaskEditorScreen(image: File(x.path)),
      ),
    );
    // 편집 취소(null) 시 이미지 미설정 유지.
    if (masked != null && mounted) setState(() => _image = masked);
  }
```

- [ ] **Step 3: 문서 주석 갱신** — 클래스 위 주석을 현재 흐름에 맞게 수정:

```dart
/// 사진 선택 → 가림 편집 → 캡션 → 업로드.
```

- [ ] **Step 4:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test` → No issues found!
- [ ] **Step 5: 커밋**

```bash
git add lib/community/screens/create_post_screen.dart
git commit -m "feat: 작성 흐름에 가림 편집 단계 삽입"
```

---

### Task 7: 최종 검증

- [ ] **Step 1:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh` → `✅ verify 통과` (순수 테스트 추가분 포함 전부 통과).
- [ ] **Step 2: 기기 수동 검증 (사람)** — 계획 B 배포(Storage/규칙/인덱스) 후 `flutter run`:
  - 커뮤니티 → + → 갤러리에서 **얼굴이 있는 사진** 선택 → 가림 편집 진입 시 얼굴에 **모자이크 영역 자동 표시(기본 ON)**.
  - 얼굴 영역 탭 → '가림 끄기'로 OFF/다시 ON 토글, '삭제'로 제거 확인.
  - 빈 곳 **드래그**로 수동 박스 추가 → 완료.
  - 완료 → 처리 스피너 → 캡션 → 올리기 → 피드에 **모자이크된 이미지** 표시.
  - 얼굴 없는 풍경 사진: 자동 영역 없이 그대로 완료·업로드 가능(가림 0개 허용).
  - (선택) 큰 사진에서 완료 시 UI 프리즈 없이 처리(아이솔레이트)되는지 체감 확인.

---

## Self-Review (작성자 확인)

- **스펙 커버리지(C):** MaskRegion=T1, 순수 기하(pixelRect·모자이크블록·정규화·축소)=T2, 좌표 변환=T3, 얼굴 감지+아이솔레이트 합성(EXIF 제거·1600px·품질85)=T4, 편집 UI(자동 ON·토글·수동 박스·삭제)=T5, 작성 흐름 통합(원본 미전송)=T6, 검증=T7. 의존성 추가 없음(스펙 §3 확인).
- **플레이스홀더:** 없음 — 모든 코드·테스트 실제 내용 포함. `image`/`Color.withValues`/Flutter 버전 관련 API 편차는 T4/T5에 "동일 동작으로 맞추고 concern 보고" 지침 명시.
- **타입 일관성:** `MaskRegion{left,top,width,height,isAuto,enabled,copyWith}`, `IntRect`, `pixelRect`, `mosaicBlockSize`, `faceBoxToRegion`, `Dimensions`/`fitDimensions`, `FitRect`/`containRect`, `NormPoint`/`normFromWidget`, `detectFaceRegions`, `applyMasks`, `MaskEditorScreen({image})` — 태스크 간 일치.
- **주의:** 방향 일관성(감지·합성 모두 EXIF 반영) T4에 명시. 원본 미전송은 T6가 항상 처리 File만 `_image`로 설정해 보장. 순수/비순수 분리 규약 준수(masking.dart는 image import 없음).
```
