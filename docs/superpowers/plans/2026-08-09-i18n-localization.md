# 다국어(i18n) 지원 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 똥손카메라를 한국어 외 영어·일본어·중국어(간체)로 표시하고, 기기 언어를 자동으로 따르며 미지원 언어는 한국어로 폴백한다.

**Architecture:** Flutter 공식 `gen-l10n`(ARB) 방식. `analysis/` 순수 계산부는 힌트 문자열 대신 의미값 enum을 반환하고, 표시문구 매핑은 UI 레이어(`AppLocalizations` + `guide_text.dart`)가 담당한다. 네이티브 앱 이름은 Android `strings.xml`/iOS `InfoPlist.strings`로 로케일화한다.

**Tech Stack:** Flutter, Dart, `flutter_localizations`(SDK), `intl`, `flutter gen-l10n`.

## Global Constraints

- 지원 로케일: `ko`(기준/템플릿), `en`, `ja`, `zh`(간체). 미지원 → `ko` 폴백.
- 앱 이름: ko=`똥손카메라`, en=`Ddongson Camera`, ja=`へたっぴカメラ`, zh=`手残相机`.
- `analysis/`는 `person_detector.dart`·`analysis_engine.dart`·`object_detector.dart`를 제외하고 **Flutter/plugin import 금지**(순수 Dart). enum도 순수 Dart.
- `'좋아요'` 문자열 센티넬 규약은 **`bool isAligned` 판정값**으로 대체(CLAUDE.md도 갱신).
- 좌표계·각도 규약은 기존 유지(정규화 0~1, 도 단위).
- 완료 게이트: `tool/verify.sh`(dart format 검사 + `dart analyze lib test` + `flutter test`) 통과. `flutter analyze`는 쓰지 않는다(한글 디렉토리 LSP 크래시).
- 각 태스크는 자체 테스트 사이클로 끝나고 커밋한다. Conventional Commits.
- Flutter/dart 바이너리 경로: `/Users/soonbok/flutter/bin`. 명령 실행 전 `export PATH="/Users/soonbok/flutter/bin:$PATH"`.

## ARB · 문자열 추출 규약 (모든 태스크 공통)

- ARB 파일: `lib/l10n/app_ko.arb`(템플릿), `app_en.arb`, `app_ja.arb`, `app_zh.arb`.
- 키 네이밍: `<영역><의미>` 카멜케이스. 예: `commonCancel`, `commonAgree`, `cameraSwitchFailed`, `guideLevelLowerLeft`, `authLoginFailed`.
- **문자열을 도입/추출하는 모든 태스크는 4개 ARB 파일 전부에 키를 추가한다**(ko=실제 한국어, en/ja/zh=번역 초안). 이렇게 해야 `flutter gen-l10n`이 경고 없이 통과하고 매 태스크 후 빌드가 green.
- 치환 있는 문자열은 ARB placeholder 사용. 예: `"saveFailed": "저장 실패: {error}"` + `"@saveFailed": {"placeholders": {"error": {"type": "String"}}}`.
- 코드 치환: `'문자열'` → `AppLocalizations.of(context)!.<key>`. import: `import 'package:flutter_gen/gen_l10n/app_localizations.dart';` (l10n.yaml 기본 출력 경로).
- 번역 용어집(일관성 유지 — 초안 시 준수):

| 개념 | ko | en | ja | zh |
|---|---|---|---|---|
| 촬영/찍다 | 찍으세요 | Shoot | 撮ろう | 拍摄 |
| 취소 | 취소 | Cancel | キャンセル | 取消 |
| 동의 | 동의 | Agree | 同意する | 同意 |
| 다시 시도 | 다시 시도 | Retry | 再試行 | 重试 |
| 카메라 | 카메라 | camera | カメラ | 相机 |
| 사진첩 | 사진첩 | photo library | 写真 | 相册 |
| 추천 | 추천 | suggestion | おすすめ | 推荐 |
| 로그인 | 로그인 | Sign in | ログイン | 登录 |
| 게시글 | 게시글 | post | 投稿 | 帖子 |

---

## Task 1: l10n 배관 + MaterialApp 배선 + 앱 타이틀

**Files:**
- Create: `l10n.yaml`
- Create: `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_ja.arb`, `lib/l10n/app_zh.arb`
- Modify: `pubspec.yaml` (dependencies + `generate: true`)
- Modify: `lib/main.dart:49-60` (MaterialApp)

**Interfaces:**
- Produces: `AppLocalizations` (생성). `AppLocalizations.of(context)!.appTitle` → 앱 이름. `AppLocalizations.localizationsDelegates`, `AppLocalizations.supportedLocales`.

- [ ] **Step 1: 의존성 추가**

`pubspec.yaml`의 `dependencies:`에 추가:
```yaml
  flutter_localizations:
    sdk: flutter
  intl: any
```
`flutter:` 섹션에 추가:
```yaml
  generate: true
```

- [ ] **Step 2: l10n.yaml 생성**

```yaml
arb-dir: lib/l10n
template-arb-file: app_ko.arb
output-localization-file: app_localizations.dart
```

- [ ] **Step 3: ARB 골격 4개 생성 (appTitle만)**

`lib/l10n/app_ko.arb`:
```json
{
  "@@locale": "ko",
  "appTitle": "똥손카메라"
}
```
`app_en.arb`:
```json
{ "@@locale": "en", "appTitle": "Ddongson Camera" }
```
`app_ja.arb`:
```json
{ "@@locale": "ja", "appTitle": "へたっぴカメラ" }
```
`app_zh.arb`:
```json
{ "@@locale": "zh", "appTitle": "手残相机" }
```

- [ ] **Step 4: pub get + 생성**

Run:
```bash
export PATH="/Users/soonbok/flutter/bin:$PATH"
flutter pub get && flutter gen-l10n
```
Expected: 경고 없이 `.dart_tool/flutter_gen/gen_l10n/app_localizations.dart` 생성.

- [ ] **Step 5: MaterialApp 배선**

`lib/main.dart` 상단 import 추가:
```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```
`MaterialApp(...)`를 아래로 교체(기존 `title: '똥손카메라',` 제거):
```dart
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('ko');
        for (final s in supported) {
          if (s.languageCode == locale.languageCode) return s;
        }
        return const Locale('ko');
      },
      navigatorObservers: [routeObserver],
      builder: (context, child) => CommunityTheme(
        controller: themeController,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const CameraScreen(),
    );
```

- [ ] **Step 6: 검증**

Run:
```bash
export PATH="/Users/soonbok/flutter/bin:$PATH"
dart analyze lib test && flutter test
```
Expected: analyze 이슈 없음, 기존 테스트 PASS.

- [ ] **Step 7: 커밋**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml lib/l10n lib/main.dart
git commit -m "feat(i18n): flutter_localizations 배관 + 앱 타이틀 로케일화"
```

---

## Task 2: Android 네이티브 앱 이름 로케일화

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (`android:label`)
- Create: `android/app/src/main/res/values/strings.xml`
- Create: `android/app/src/main/res/values-en/strings.xml`
- Create: `android/app/src/main/res/values-ja/strings.xml`
- Create: `android/app/src/main/res/values-zh/strings.xml`

- [ ] **Step 1: 기본 strings.xml (ko) 생성**

`android/app/src/main/res/values/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">똥손카메라</string>
</resources>
```

- [ ] **Step 2: 로케일별 strings.xml 생성**

`values-en/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Ddongson Camera</string>
</resources>
```
`values-ja/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">へたっぴカメラ</string>
</resources>
```
`values-zh/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">手残相机</string>
</resources>
```

- [ ] **Step 3: 매니페스트 label 참조로 변경**

`AndroidManifest.xml`의 `android:label="똥손카메라"`를 다음으로 교체:
```xml
        android:label="@string/app_name"
```

- [ ] **Step 4: 빌드 검증**

Run:
```bash
export PATH="/Users/soonbok/flutter/bin:$PATH"
cd android && ./gradlew :app:processDebugResources -q ; cd ..
```
Expected: 리소스 처리 에러 없음. (빌드 도구 미가용 시 `flutter build apk --debug`로 대체.)

- [ ] **Step 5: 커밋**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/res/values*/strings.xml
git commit -m "feat(i18n): Android 앱 이름 로케일별 리소스화"
```

---

## Task 3: iOS 네이티브 앱 이름 로케일화

**Files:**
- Modify: `ios/Runner/Info.plist` (`CFBundleLocalizations` 추가)
- Create: `ios/Runner/ko.lproj/InfoPlist.strings`
- Create: `ios/Runner/en.lproj/InfoPlist.strings`
- Create: `ios/Runner/ja.lproj/InfoPlist.strings`
- Create: `ios/Runner/zh-Hans.lproj/InfoPlist.strings`

- [ ] **Step 1: InfoPlist.strings 4개 생성**

`ios/Runner/ko.lproj/InfoPlist.strings`:
```
"CFBundleDisplayName" = "똥손카메라";
```
`ios/Runner/en.lproj/InfoPlist.strings`:
```
"CFBundleDisplayName" = "Ddongson Camera";
```
`ios/Runner/ja.lproj/InfoPlist.strings`:
```
"CFBundleDisplayName" = "へたっぴカメラ";
```
`ios/Runner/zh-Hans.lproj/InfoPlist.strings`:
```
"CFBundleDisplayName" = "手残相机";
```

- [ ] **Step 2: Info.plist에 CFBundleLocalizations 추가**

`ios/Runner/Info.plist`의 `<dict>` 안에 추가:
```xml
	<key>CFBundleLocalizations</key>
	<array>
		<string>ko</string>
		<string>en</string>
		<string>ja</string>
		<string>zh-Hans</string>
	</array>
```

- [ ] **Step 3: Xcode 프로젝트에 lproj 등록**

`ios/Runner.xcodeproj/project.pbxproj`의 `knownRegions`에 `ja`, `zh-Hans`가 없으면 추가하고, 4개 `InfoPlist.strings`를 variant group으로 등록한다. (Xcode에서 파일 추가 시 자동 등록되지만, CLI 작업 시 pbxproj 편집 필요.) 검증은 다음 단계 빌드로 확인.

- [ ] **Step 4: 빌드 검증**

Run:
```bash
export PATH="/Users/soonbok/flutter/bin:$PATH"
flutter build ios --debug --no-codesign
```
Expected: 빌드 성공(경고 허용). 실기기/시뮬레이터에서 언어 변경 시 앱 이름 반영 확인은 수동.

- [ ] **Step 5: 커밋**

```bash
git add ios/Runner/*.lproj/InfoPlist.strings ios/Runner/Info.plist ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(i18n): iOS 앱 이름 로케일별 InfoPlist.strings"
```

---

## Task 4: tilt.dart — 힌트 문자열 → TiltHint enum (TDD)

**Files:**
- Modify: `lib/analysis/tilt.dart`
- Test: `test/analysis/tilt_test.dart`

**Interfaces:**
- Produces: `enum TiltHint { none, lowerLeft, lowerRight }`. `TiltInfo.hint` 타입이 `String`→`TiltHint`로 변경.

- [ ] **Step 1: 테스트를 enum 단언으로 재작성**

`test/analysis/tilt_test.dart`의 hint 단언을 교체:
```dart
    // 수평
    expect(t.hint, TiltHint.none);
    // 오른쪽으로 기움(roll 양수) → 왼쪽을 내려야 함
    expect(t.hint, TiltHint.lowerLeft);
    // 왼쪽으로 기움(roll 음수) → 오른쪽을 내려야 함
    expect(t.hint, TiltHint.lowerRight);
    // 허용오차 내
    expect(t.hint, TiltHint.none);
```

- [ ] **Step 2: 실패 확인**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/analysis/tilt_test.dart`
Expected: FAIL (TiltHint 미정의).

- [ ] **Step 3: 구현**

`lib/analysis/tilt.dart`:
```dart
import 'dart:math' as math;

enum TiltHint { none, lowerLeft, lowerRight }

class TiltInfo {
  final double rollDegrees;
  final bool isLevel;
  final TiltHint hint;
  const TiltInfo({
    required this.rollDegrees,
    required this.isLevel,
    required this.hint,
  });
}

TiltInfo computeTilt(
  double accelX,
  double accelY, {
  double levelToleranceDeg = 1.5,
}) {
  final roll = math.atan2(accelX, accelY) * 180 / math.pi;
  final level = roll.abs() <= levelToleranceDeg;
  final TiltHint hint;
  if (level) {
    hint = TiltHint.none;
  } else if (roll > 0) {
    hint = TiltHint.lowerLeft;
  } else {
    hint = TiltHint.lowerRight;
  }
  return TiltInfo(rollDegrees: roll, isLevel: level, hint: hint);
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/analysis/tilt_test.dart`
Expected: PASS. (다른 파일 컴파일 에러는 후속 태스크에서 해결 — 이 단계는 단일 파일만.)

- [ ] **Step 5: 커밋**

```bash
git add lib/analysis/tilt.dart test/analysis/tilt_test.dart
git commit -m "refactor(analysis): tilt 힌트를 TiltHint enum으로 분리"
```

---

## Task 5: headroom.dart — HeadroomHint enum (TDD)

**Files:**
- Modify: `lib/analysis/headroom.dart`
- Test: `test/analysis/headroom_test.dart`

**Interfaces:**
- Produces: `enum HeadroomHint { none, raiseCamera, lowerCamera }`. `HeadroomAdvice.hint`: `String`→`HeadroomHint`.

- [ ] **Step 1: 테스트 재작성**

`test/analysis/headroom_test.dart`의 hint 단언 교체:
```dart
    expect(a.hint, HeadroomHint.raiseCamera); // top 0.01 (너무 좁음)
    expect(a.hint, HeadroomHint.lowerCamera); // top 0.30 (너무 넓음)
    expect(a.hint, HeadroomHint.none);        // top 0.10 (적정)
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/analysis/headroom_test.dart`
Expected: FAIL (HeadroomHint 미정의).

- [ ] **Step 3: 구현**

`lib/analysis/headroom.dart`:
```dart
import '../models/person_box.dart';

enum HeadroomHint { none, raiseCamera, lowerCamera }

class HeadroomAdvice {
  final double ratio;
  final HeadroomHint hint;
  const HeadroomAdvice({required this.ratio, required this.hint});
}

HeadroomAdvice computeHeadroom(
  PersonBox person, {
  double idealMin = 0.05,
  double idealMax = 0.15,
}) {
  final ratio = person.top;
  final HeadroomHint hint;
  if (ratio < idealMin) {
    hint = HeadroomHint.raiseCamera;
  } else if (ratio > idealMax) {
    hint = HeadroomHint.lowerCamera;
  } else {
    hint = HeadroomHint.none;
  }
  return HeadroomAdvice(ratio: ratio, hint: hint);
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/analysis/headroom_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/analysis/headroom.dart test/analysis/headroom_test.dart
git commit -m "refactor(analysis): headroom 힌트를 HeadroomHint enum으로 분리"
```

---

## Task 6: angle_zoom.dart — AngleHint · ZoomHint enum (TDD)

**Files:**
- Modify: `lib/analysis/angle_zoom.dart`
- Test: `test/analysis/angle_zoom_test.dart`

**Interfaces:**
- Produces: `enum AngleHint { none, eyeLevelUp, eyeLevelDown, frontalUp, frontalDown }`, `enum ZoomHint { none, closer, farther }`. `AngleAdvice.hint`/`ZoomAdvice.hint`: `String`→enum. (`computePitch`, `AngleGuide` 유지.)
- 의미: `eyeLevelDown`=눈높이로 내리세요, `eyeLevelUp`=눈높이로 올리세요, `frontalDown`=수평으로 내리세요, `frontalUp`=수평으로 올리세요, `closer`=다가가거나 확대, `farther`=물러나거나 축소.

- [ ] **Step 1: 테스트 재작성**

`test/analysis/angle_zoom_test.dart`의 hint 단언 교체:
```dart
    expect(computeAngle(40, guide: AngleGuide.none).hint, AngleHint.none);
    expect(computeAngle(0, guide: AngleGuide.eyeLevel).hint, AngleHint.none);
    expect(computeAngle(30, guide: AngleGuide.eyeLevel).hint, AngleHint.eyeLevelDown);
    expect(computeAngle(-30, guide: AngleGuide.eyeLevel).hint, AngleHint.eyeLevelUp);
    expect(computeAngle(30, guide: AngleGuide.frontal).hint, AngleHint.frontalDown);
    expect(computeAngle(-30, guide: AngleGuide.frontal).hint, AngleHint.frontalUp);
    expect(computeAngle(0, guide: AngleGuide.frontal).hint, AngleHint.none);
    expect(computeZoom(0.3).hint, ZoomHint.closer);
    expect(computeZoom(0.9).hint, ZoomHint.farther);
    expect(computeZoom(0.65).hint, ZoomHint.none);
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/analysis/angle_zoom_test.dart`
Expected: FAIL.

- [ ] **Step 3: 구현**

`lib/analysis/angle_zoom.dart`에서 `AngleAdvice`/`ZoomAdvice`와 두 함수 교체:
```dart
enum AngleHint { none, eyeLevelUp, eyeLevelDown, frontalUp, frontalDown }
enum ZoomHint { none, closer, farther }

class AngleAdvice {
  final double pitchDegrees;
  final AngleHint hint;
  const AngleAdvice({required this.pitchDegrees, required this.hint});
}

class ZoomAdvice {
  final double subjectRatio;
  final ZoomHint hint;
  const ZoomAdvice({required this.subjectRatio, required this.hint});
}
```
`computeAngle` 본문의 hint 배정:
```dart
  AngleHint hint = AngleHint.none;
  if (guide == AngleGuide.eyeLevel) {
    if (pitchDegrees > tolerance) {
      hint = AngleHint.eyeLevelDown;
    } else if (pitchDegrees < -tolerance) {
      hint = AngleHint.eyeLevelUp;
    }
  } else if (guide == AngleGuide.frontal) {
    if (pitchDegrees > tolerance) {
      hint = AngleHint.frontalDown;
    } else if (pitchDegrees < -tolerance) {
      hint = AngleHint.frontalUp;
    }
  }
  return AngleAdvice(pitchDegrees: pitchDegrees, hint: hint);
```
`computeZoom` 본문의 hint 배정:
```dart
  final ZoomHint hint;
  if (subjectHeightRatio < idealMin) {
    hint = ZoomHint.closer;
  } else if (subjectHeightRatio > idealMax) {
    hint = ZoomHint.farther;
  } else {
    hint = ZoomHint.none;
  }
  return ZoomAdvice(subjectRatio: subjectHeightRatio, hint: hint);
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/analysis/angle_zoom_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/analysis/angle_zoom.dart test/analysis/angle_zoom_test.dart
git commit -m "refactor(analysis): angle/zoom 힌트를 enum으로 분리"
```

---

## Task 7: crop.dart — message getter 제거 (TDD)

**Files:**
- Modify: `lib/analysis/crop.dart`
- Test: `test/analysis/crop_test.dart`

**Interfaces:**
- `CropWarning.message` getter 제거. `top/bottom/left/right` 불리언과 `any`만 남긴다. 표시문구는 UI가 불리언으로 조립.

- [ ] **Step 1: 테스트 재작성 (message 단언 제거, 불리언으로)**

`test/analysis/crop_test.dart` 전체 교체:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/analysis/crop.dart';

void main() {
  test('여백 안에 있으면 잘림 없음', () {
    final w = detectCrop(
      const PersonBox(left: 0.2, top: 0.1, width: 0.5, height: 0.7),
    );
    expect(w.any, isFalse);
  });

  test('상단에 닿으면 위 잘림 감지', () {
    final w = detectCrop(
      const PersonBox(left: 0.2, top: 0.0, width: 0.5, height: 0.7),
    );
    expect(w.top, isTrue);
    expect(w.any, isTrue);
  });

  test('여러 변이 잘리면 모두 true', () {
    final w = detectCrop(
      const PersonBox(left: 0.0, top: 0.0, width: 1.0, height: 1.0),
    );
    expect(w.top && w.bottom && w.left && w.right, isTrue);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/analysis/crop_test.dart`
Expected: 컴파일은 되지만 이후 message 참조하는 곳(guide_metrics)이 깨질 수 있음. 이 단계에선 crop_test만 PASS 확인.

- [ ] **Step 3: 구현 — message getter 삭제**

`lib/analysis/crop.dart`에서 `String get message { ... }` 블록 전체를 삭제. 나머지 유지.

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/analysis/crop_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/analysis/crop.dart test/analysis/crop_test.dart
git commit -m "refactor(analysis): CropWarning.message 제거(표시문구는 UI로 이관)"
```

---

## Task 8: thirds.dart — isAligned + 이동방향 노출 (TDD)

**Files:**
- Modify: `lib/analysis/thirds.dart`
- Test: `test/analysis/thirds_test.dart`

**Interfaces:**
- Produces: `ThirdsAlignment.hint`(String) 제거. 추가: `final bool isAligned;`, `final bool moveRight, moveLeft, moveUp, moveDown;`. `'좋아요'`↔정렬 여부는 `isAligned`로 판정.

- [ ] **Step 1: 테스트 재작성**

`test/analysis/thirds_test.dart`의 hint 단언 교체:
```dart
    // 교차점 위
    expect(a.isAligned, isTrue);
    // 목표보다 왼쪽/위 → 오른쪽·아래로
    final a2 = computeThirds(0.2, 0.2);
    expect(a2.isAligned, isFalse);
    expect(a2.moveRight, isTrue);
    expect(a2.moveDown, isTrue);
    expect(a2.moveLeft, isFalse);
    expect(a2.moveUp, isFalse);
```
(distance/score/target/current 단언은 그대로 유지.)

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/analysis/thirds_test.dart`
Expected: FAIL.

- [ ] **Step 3: 구현**

`lib/analysis/thirds.dart`의 `ThirdsAlignment` 클래스에서 `String hint`를 제거하고 방향/정렬 필드 추가, 생성자 갱신:
```dart
class ThirdsAlignment {
  final double currentX;
  final double currentY;
  final double targetX;
  final double targetY;
  final double distance;
  final double score;
  final bool isAligned;
  final bool moveRight;
  final bool moveLeft;
  final bool moveUp;
  final bool moveDown;
  const ThirdsAlignment({
    required this.currentX,
    required this.currentY,
    required this.targetX,
    required this.targetY,
    required this.distance,
    required this.score,
    required this.isAligned,
    required this.moveRight,
    required this.moveLeft,
    required this.moveUp,
    required this.moveDown,
  });
}
```
`computeThirds` 끝부분(`parts`/`hint` 생성)을 교체:
```dart
  final dx = bestX - cx;
  final dy = bestY - cy;
  final moveRight = dx > alignedTolerance;
  final moveLeft = dx < -alignedTolerance;
  final moveDown = dy > alignedTolerance;
  final moveUp = dy < -alignedTolerance;
  final isAligned = !moveRight && !moveLeft && !moveUp && !moveDown;
  return ThirdsAlignment(
    currentX: cx,
    currentY: cy,
    targetX: bestX,
    targetY: bestY,
    distance: bestD,
    score: score,
    isAligned: isAligned,
    moveRight: moveRight,
    moveLeft: moveLeft,
    moveUp: moveUp,
    moveDown: moveDown,
  );
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/analysis/thirds_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/analysis/thirds.dart test/analysis/thirds_test.dart
git commit -m "refactor(analysis): thirds 힌트를 isAligned+이동방향으로 분리"
```

---

## Task 9: guide_metrics · guide_step — 구조값화 (TDD)

**Files:**
- Modify: `lib/analysis/guide_metrics.dart`
- Modify: `lib/analysis/guide_step.dart`
- Test: `test/analysis/guide_metrics_test.dart`
- Test: `test/analysis/guide_step_test.dart`

**Interfaces:**
- Produces: `GuideMetrics.activeHints`(List<String>) 제거 → 대신 UI가 필드별 enum을 읽어 조립(이 태스크에선 activeHints 삭제). `GuideStep.message`(String) 제거 → `GuideStepKind`만으로 표현(position은 `target`으로 방향 표현). ready는 `GuideStepKind.ready`.
- 참고: 이전 태스크들로 `TiltInfo.hint`=`TiltHint`, `crop`에 message 없음, `thirds.isAligned` 존재.

- [ ] **Step 1: guide_metrics 테스트 재작성**

`test/analysis/guide_metrics_test.dart`를 enum 기반으로 교체. `activeHints`를 삭제하므로, 대신 필드 접근을 검증하는 테스트로 단순화:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/guide_metrics.dart';
import 'package:ttongson_camera/analysis/tilt.dart';
import 'package:ttongson_camera/analysis/thirds.dart';
import 'package:ttongson_camera/analysis/headroom.dart';
import 'package:ttongson_camera/analysis/crop.dart';
import 'package:ttongson_camera/analysis/angle_zoom.dart';

void main() {
  test('GuideMetrics는 각 분석 결과를 그대로 보관한다', () {
    final m = GuideMetrics(
      tilt: const TiltInfo(rollDegrees: 5, isLevel: false, hint: TiltHint.lowerLeft),
      crop: const CropWarning(top: true, bottom: false, left: false, right: false),
      headroom: const HeadroomAdvice(ratio: 0.3, hint: HeadroomHint.lowerCamera),
      thirds: const ThirdsAlignment(
        currentX: 0.2, currentY: 0.2, targetX: 0.333, targetY: 0.333,
        distance: 0.15, score: 0.6, isAligned: false,
        moveRight: true, moveLeft: false, moveUp: false, moveDown: true,
      ),
      angle: const AngleAdvice(pitchDegrees: 20, hint: AngleHint.eyeLevelDown),
      zoom: const ZoomAdvice(subjectRatio: 0.2, hint: ZoomHint.closer),
    );
    expect(m.tilt.hint, TiltHint.lowerLeft);
    expect(m.crop!.any, isTrue);
    expect(m.headroom!.hint, HeadroomHint.lowerCamera);
    expect(m.thirds!.isAligned, isFalse);
    expect(m.angle.hint, AngleHint.eyeLevelDown);
    expect(m.zoom!.hint, ZoomHint.closer);
  });
}
```

- [ ] **Step 2: guide_metrics 구현 — activeHints 제거**

`lib/analysis/guide_metrics.dart`에서 `List<String> get activeHints { ... }` 블록 전체 삭제. 필드/생성자만 유지.

- [ ] **Step 3: guide_step 테스트 재작성 (message → kind)**

`test/analysis/guide_step_test.dart`에서 `s.message` 단언을 kind 단언으로 교체:
```dart
    // level 단계
    expect(s.kind, GuideStepKind.level);
    // ready 단계
    expect(s.kind, GuideStepKind.ready);
```
(position 테스트의 `s.target!.currentX` 단언은 유지. `expect(s.message, '왼쪽을 내리세요')` 및 `expect(s.message, '찍으세요!')` 라인 삭제.)

- [ ] **Step 4: guide_step 구현 — message 필드 제거**

`lib/analysis/guide_step.dart` 교체:
```dart
// lib/analysis/guide_step.dart
// 순수 Dart — Flutter/plugin import 금지.
import 'guide_metrics.dart';
import 'thirds.dart';

enum GuideStepKind { level, crop, distance, position, headroom, angle, ready }

class GuideStep {
  final GuideStepKind kind;
  final ThirdsAlignment? target; // position 단계에서만 채움
  const GuideStep({required this.kind, this.target});
}

GuideStep computeCurrentStep(GuideMetrics m) {
  if (!m.tilt.isLevel) return const GuideStep(kind: GuideStepKind.level);
  final crop = m.crop;
  if (crop != null && crop.any) return const GuideStep(kind: GuideStepKind.crop);
  final zoom = m.zoom;
  if (zoom != null && zoom.hint != ZoomHint.none) {
    return const GuideStep(kind: GuideStepKind.distance);
  }
  final thirds = m.thirds;
  if (thirds != null && !thirds.isAligned) {
    return GuideStep(kind: GuideStepKind.position, target: thirds);
  }
  final headroom = m.headroom;
  if (headroom != null && headroom.hint != HeadroomHint.none) {
    return const GuideStep(kind: GuideStepKind.headroom);
  }
  if (m.angle.hint != AngleHint.none) {
    return const GuideStep(kind: GuideStepKind.angle);
  }
  return const GuideStep(kind: GuideStepKind.ready);
}
```
`import 'angle_zoom.dart';`가 필요하면 추가(ZoomHint/AngleHint/HeadroomHint 참조). 실제로는 `guide_metrics.dart`가 이미 이들을 export하지 않으므로 `import 'angle_zoom.dart';`와 `import 'headroom.dart';` 추가.

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/analysis/guide_metrics_test.dart test/analysis/guide_step_test.dart`
Expected: PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/analysis/guide_metrics.dart lib/analysis/guide_step.dart test/analysis/guide_metrics_test.dart test/analysis/guide_step_test.dart
git commit -m "refactor(analysis): guide_metrics/guide_step를 표시문구 없는 구조값으로"
```

---

## Task 10: guide_text.dart — enum→로케일 문자열 매핑 (TDD)

**Files:**
- Create: `lib/l10n/guide_text.dart`
- Create: `test/l10n/guide_text_test.dart`
- Modify: `lib/l10n/app_ko.arb`, `app_en.arb`, `app_ja.arb`, `app_zh.arb` (guide 키 추가)

**Interfaces:**
- Consumes: analysis enum(`TiltHint`, `HeadroomHint`, `AngleHint`, `ZoomHint`), `CropWarning`, `ThirdsAlignment`, `GuideStep`/`GuideStepKind`, `AppLocalizations`.
- Produces: `String? tiltHintText(AppLocalizations l10n, TiltHint h)`, `String cropText(AppLocalizations l10n, CropWarning c)`, `String? headroomText(...)`, `String? angleText(...)`, `String? zoomText(...)`, `String thirdsMoveText(AppLocalizations l10n, ThirdsAlignment t)`, `String stepText(AppLocalizations l10n, GuideStep step)`.

- [ ] **Step 1: ARB에 guide 키 추가 (4개 언어)**

`app_ko.arb`에 추가:
```json
  "guideLevelLowerLeft": "왼쪽을 내리세요",
  "guideLevelLowerRight": "오른쪽을 내리세요",
  "guideHeadroomRaise": "카메라를 살짝 올리세요",
  "guideHeadroomLower": "카메라를 살짝 내리세요",
  "guideAngleEyeLevelDown": "카메라를 눈높이로 내리세요",
  "guideAngleEyeLevelUp": "카메라를 눈높이로 올리세요",
  "guideAngleFrontalDown": "카메라를 수평으로 내리세요",
  "guideAngleFrontalUp": "카메라를 수평으로 올리세요",
  "guideZoomCloser": "조금 다가가거나 확대하세요",
  "guideZoomFarther": "조금 물러나거나 축소하세요",
  "guideMoveRight": "오른쪽으로",
  "guideMoveLeft": "왼쪽으로",
  "guideMoveUp": "위로",
  "guideMoveDown": "아래로",
  "guideMoveSeparator": " · ",
  "guideMovePrompt": "여기로 옮기세요",
  "guideReady": "찍으세요!",
  "cropTop": "위",
  "cropBottom": "아래",
  "cropLeft": "왼쪽",
  "cropRight": "오른쪽",
  "cropSeparator": "/",
  "cropCut": "{sides}이(가) 잘렸어요"
```
`cropCut`에 placeholder 메타 추가:
```json
  "@cropCut": { "placeholders": { "sides": { "type": "String" } } }
```
`app_en.arb`/`app_ja.arb`/`app_zh.arb`에 동일 키를 번역 초안으로 추가(용어집 준수). 예 en: `"guideReady": "Shoot!"`, `"guideMoveRight": "right"`, `"cropCut": "{sides} is cut off"`; ja: `"guideReady": "撮ろう！"`, `"cropCut": "{sides}が切れています"`; zh: `"guideReady": "拍吧！"`, `"cropCut": "{sides}被截掉了"`. (전체 키 번역은 Task 18에서 최종 검수.)

- [ ] **Step 2: 실패 테스트 작성**

`test/l10n/guide_text_test.dart`:
```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ttongson_camera/analysis/tilt.dart';
import 'package:ttongson_camera/analysis/crop.dart';
import 'package:ttongson_camera/analysis/angle_zoom.dart';
import 'package:ttongson_camera/analysis/thirds.dart';
import 'package:ttongson_camera/l10n/guide_text.dart';

void main() {
  late AppLocalizations ko;
  setUpAll(() async {
    ko = await AppLocalizations.delegate.load(const Locale('ko'));
  });

  test('tilt 힌트 매핑', () {
    expect(tiltHintText(ko, TiltHint.none), isNull);
    expect(tiltHintText(ko, TiltHint.lowerLeft), '왼쪽을 내리세요');
    expect(tiltHintText(ko, TiltHint.lowerRight), '오른쪽을 내리세요');
  });

  test('crop 다중 변 조립', () {
    final c = const CropWarning(top: true, bottom: true, left: false, right: false);
    expect(cropText(ko, c), '위/아래이(가) 잘렸어요');
  });

  test('zoom/angle/headroom 매핑', () {
    expect(zoomText(ko, ZoomHint.closer), '조금 다가가거나 확대하세요');
    expect(angleText(ko, AngleHint.eyeLevelDown), '카메라를 눈높이로 내리세요');
    expect(headroomText(ko, HeadroomHint.raiseCamera), '카메라를 살짝 올리세요');
  });

  test('thirds 이동 방향 조립', () {
    final t = const ThirdsAlignment(
      currentX: 0.2, currentY: 0.2, targetX: 0.333, targetY: 0.333,
      distance: 0.1, score: 0.6, isAligned: false,
      moveRight: true, moveLeft: false, moveUp: false, moveDown: true,
    );
    expect(thirdsMoveText(ko, t), '오른쪽으로 · 아래로');
  });
}
```

- [ ] **Step 3: 실패 확인**

Run: `flutter gen-l10n && flutter test test/l10n/guide_text_test.dart`
Expected: FAIL (guide_text.dart 미존재).

- [ ] **Step 4: guide_text.dart 구현**

`lib/l10n/guide_text.dart`:
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../analysis/tilt.dart';
import '../analysis/headroom.dart';
import '../analysis/angle_zoom.dart';
import '../analysis/crop.dart';
import '../analysis/thirds.dart';

String? tiltHintText(AppLocalizations l, TiltHint h) => switch (h) {
      TiltHint.none => null,
      TiltHint.lowerLeft => l.guideLevelLowerLeft,
      TiltHint.lowerRight => l.guideLevelLowerRight,
    };

String? headroomText(AppLocalizations l, HeadroomHint h) => switch (h) {
      HeadroomHint.none => null,
      HeadroomHint.raiseCamera => l.guideHeadroomRaise,
      HeadroomHint.lowerCamera => l.guideHeadroomLower,
    };

String? angleText(AppLocalizations l, AngleHint h) => switch (h) {
      AngleHint.none => null,
      AngleHint.eyeLevelDown => l.guideAngleEyeLevelDown,
      AngleHint.eyeLevelUp => l.guideAngleEyeLevelUp,
      AngleHint.frontalDown => l.guideAngleFrontalDown,
      AngleHint.frontalUp => l.guideAngleFrontalUp,
    };

String? zoomText(AppLocalizations l, ZoomHint h) => switch (h) {
      ZoomHint.none => null,
      ZoomHint.closer => l.guideZoomCloser,
      ZoomHint.farther => l.guideZoomFarther,
    };

String cropText(AppLocalizations l, CropWarning c) {
  final sides = <String>[];
  if (c.top) sides.add(l.cropTop);
  if (c.bottom) sides.add(l.cropBottom);
  if (c.left) sides.add(l.cropLeft);
  if (c.right) sides.add(l.cropRight);
  return l.cropCut(sides.join(l.cropSeparator));
}

String thirdsMoveText(AppLocalizations l, ThirdsAlignment t) {
  final parts = <String>[];
  if (t.moveRight) parts.add(l.guideMoveRight);
  if (t.moveLeft) parts.add(l.guideMoveLeft);
  if (t.moveDown) parts.add(l.guideMoveDown);
  if (t.moveUp) parts.add(l.guideMoveUp);
  return parts.join(l.guideMoveSeparator);
}
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/l10n/guide_text_test.dart`
Expected: PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/l10n/guide_text.dart test/l10n/guide_text_test.dart lib/l10n/*.arb
git commit -m "feat(i18n): 가이드 enum→로케일 문자열 매핑 레이어"
```

---

## Task 11: camera_screen · guide_overlay 배선

**Files:**
- Modify: `lib/overlay/guide_overlay.dart` (`_paintPosition`의 `t.hint == '좋아요'` → `t.isAligned`)
- Modify: `lib/screens/camera_screen.dart` (activeHints/step.message 대신 guide_text 사용)

**Interfaces:**
- Consumes: `guide_text.dart`의 매핑 함수, `AppLocalizations.of(context)`.

- [ ] **Step 1: guide_overlay 정렬 판정 교체**

`lib/overlay/guide_overlay.dart`의 `_paintPosition`에서:
```dart
    final aligned = t.hint == '좋아요';
```
을
```dart
    final aligned = t.isAligned;
```
로 교체. 파일 상단 `import '../analysis/thirds.dart';`는 유지.

- [ ] **Step 2: camera_screen 힌트/스텝 표시 교체**

`lib/screens/camera_screen.dart` 상단에 import 추가:
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../l10n/guide_text.dart';
```
`_metrics.activeHints`(약 212행)를 사용하는 힌트 위젯 호출부에서, `AppLocalizations.of(context)!`를 `l`로 얻어 각 지표를 매핑한 리스트를 만들어 전달:
```dart
    final l = AppLocalizations.of(context)!;
    final hints = <String>[
      if (tiltHintText(l, _metrics.tilt.hint) != null) tiltHintText(l, _metrics.tilt.hint)!,
      if (_metrics.crop?.any == true) cropText(l, _metrics.crop!),
      if (_metrics.headroom != null && headroomText(l, _metrics.headroom!.hint) != null)
        headroomText(l, _metrics.headroom!.hint)!,
      if (_metrics.thirds != null && !_metrics.thirds!.isAligned) thirdsMoveText(l, _metrics.thirds!),
      if (angleText(l, _metrics.angle.hint) != null) angleText(l, _metrics.angle.hint)!,
      if (_metrics.zoom != null && zoomText(l, _metrics.zoom!.hint) != null)
        zoomText(l, _metrics.zoom!.hint)!,
    ];
    // ... hints: hints 로 전달
```
`_step.message`(약 1093–1094행) 및 하드코딩 `'찍으세요!'`(약 900행) 표시부를 `stepText`로 교체. `stepText`를 guide_text.dart에 추가:
```dart
// pill에는 position("여기로 옮기세요")과 ready("찍으세요!")만 문구가 있다.
// 나머지 단계 문구는 상단 hints 목록이 담당하므로 여기선 빈 문자열.
String stepText(AppLocalizations l, GuideStep s) => switch (s.kind) {
      GuideStepKind.ready => l.guideReady,
      GuideStepKind.position => l.guideMovePrompt,
      _ => '',
    };
```
> 주: 기존엔 `_step.message`가 각 단계 문구를 담았으나, 이제 pill에는 position(`여기로 옮기세요`)과 ready(`찍으세요!`)만 문구가 있고 나머지 단계는 상단 hints 목록이 담당한다. camera_screen의 pill 조건(`_step.kind == ready` / `_step.message.isNotEmpty`)을 `_step.kind`가 position이거나 ready일 때만 pill을 띄우도록 조정:
```dart
                      if (_step.kind == GuideStepKind.ready)
                        _readyBadge()
                      else if (_step.kind == GuideStepKind.position)
                        _stepPill(AppLocalizations.of(context)!.guideMovePrompt),
```
`_readyBadge`의 하드코딩 `'찍으세요!'`도 `AppLocalizations.of(context)!.guideReady`로 교체.

- [ ] **Step 3: 검증**

Run:
```bash
export PATH="/Users/soonbok/flutter/bin:$PATH"
flutter gen-l10n && dart analyze lib test && flutter test
```
Expected: analyze 이슈 없음, 모든 테스트 PASS (analysis 리팩터 완료로 컴파일 성공).

- [ ] **Step 4: 커밋**

```bash
git add lib/overlay/guide_overlay.dart lib/screens/camera_screen.dart lib/l10n/guide_text.dart
git commit -m "feat(i18n): 카메라 오버레이·가이드 힌트 로케일 배선"
```

---

## Task 12: camera_screen 나머지 문자열 추출

**Files:**
- Modify: `lib/screens/camera_screen.dart`
- Modify: `lib/l10n/app_ko.arb`, `app_en.arb`, `app_ja.arb`, `app_zh.arb`

**추출 절차(이 태스크에 적용):** 파일 내 사용자에게 보이는 한국어 리터럴(주석 제외)을 모두 찾아 → ARB 키로 정의(4개 언어) → 코드에서 `AppLocalizations.of(context)!.<key>`로 치환. 치환 문자열은 placeholder 사용.

- [ ] **Step 1: 한국어 UI 문자열 목록화**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && rtk proxy grep -n "Text(\|SnackBar\|title:\|content:" lib/screens/camera_screen.dart`
대상 예(약 356~758행 SnackBar/다이얼로그): `'카메라 전환에 실패했어요'`, `'사진첩을 열 수 없어요'`, `'저장 실패: $e'`, `'구도 추천 안내'`, `'취소'`, `'동의'`, `'추천을 못 받았어요. 다시 시도해 주세요.'`, `'포즈를 불러오지 못했어요'`, `'AI 추천 안내'`, `'추천 시 현재 화면 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.'`, `'Wi-Fi에 연결돼 있지 않아요...'`, `'리모컨 연결 준비에 실패했어요...'`, `'다시 시도'`, `'카메라를 다시 시작하지 못했어요: $e'`, `'카메라를 다시 시작하지 못했어요'` 등.

- [ ] **Step 2: ARB 키 추가 (4개 언어)**

`app_ko.arb`에 예시로 추가(나머지 동일 패턴):
```json
  "cameraSwitchFailed": "카메라 전환에 실패했어요",
  "galleryOpenFailed": "사진첩을 열 수 없어요",
  "saveFailed": "저장 실패: {error}",
  "commonCancel": "취소",
  "commonAgree": "동의",
  "commonRetry": "다시 시도",
  "suggestFailed": "추천을 못 받았어요. 다시 시도해 주세요.",
  "posesLoadFailed": "포즈를 불러오지 못했어요",
  "aiConsentTitle": "AI 추천 안내",
  "aiConsentBody": "추천 시 현재 화면 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.",
  "wifiNotConnected": "Wi-Fi에 연결돼 있지 않아요. 같은 Wi-Fi 또는 핫스팟에 연결해 주세요.",
  "remotePrepFailed": "리모컨 연결 준비에 실패했어요. 잠시 후 다시 시도해 주세요.",
  "cameraRestartFailedDetail": "카메라를 다시 시작하지 못했어요: {error}"
```
`@saveFailed`/`@cameraRestartFailedDetail`에 `error` placeholder 메타 추가. `app_en/ja/zh.arb`에 용어집 준수 번역 초안 추가.

- [ ] **Step 3: 코드 치환**

`camera_screen.dart`의 각 리터럴을 `AppLocalizations.of(context)!.<key>`로 치환. 치환형은 예: `Text('저장 실패: $e')` → `Text(AppLocalizations.of(context)!.saveFailed(e.toString()))`. `const` 위젯은 문자열이 런타임 값이 되므로 `const` 제거.

- [ ] **Step 4: 검증**

Run: `flutter gen-l10n && dart analyze lib test && flutter test`
Expected: 이슈 없음, PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/camera_screen.dart lib/l10n/*.arb
git commit -m "feat(i18n): camera_screen 문자열 추출"
```

---

## Task 13: capture_result_screen 문자열 추출

**Files:**
- Modify: `lib/screens/capture_result_screen.dart`
- Modify: `lib/l10n/*.arb`

**추출 절차:** Task 12 Step 형식과 동일 — 한국어 UI 리터럴 목록화 → ARB 키(4개 언어) → `AppLocalizations` 치환.

- [ ] **Step 1: 문자열 목록화**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && rtk proxy grep -n "'[^']*[가-힣]" lib/screens/capture_result_screen.dart`

- [ ] **Step 2: ARB 키 추가(4개 언어)** — 각 리터럴을 `capture<의미>` 키로 정의, en/ja/zh 초안.

- [ ] **Step 3: 코드 치환** — `AppLocalizations.of(context)!.<key>`.

- [ ] **Step 4: 검증**

Run: `flutter gen-l10n && dart analyze lib test && flutter test`
Expected: 이슈 없음, PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/capture_result_screen.dart lib/l10n/*.arb
git commit -m "feat(i18n): capture_result_screen 문자열 추출"
```

---

## Task 14: 커뮤니티 화면 문자열 추출

**Files:**
- Modify: `lib/community/screens/login_screen.dart`, `signup_screen.dart`, `feed_screen.dart`, `post_detail_screen.dart`, `create_post_screen.dart`, `account_screen.dart`, `mask_editor_screen.dart`, `report_sheet.dart`, `auth_widgets.dart`
- Modify: `lib/community/theme/community_theme.dart` (사용자 문구가 있으면)
- Modify: `lib/l10n/*.arb`

**추출 절차:** 각 파일마다 한국어 UI 리터럴 목록화 → `community<영역><의미>` 키(4개 언어) → `AppLocalizations` 치환. 서비스/리포지토리 예외 문구는 화면 catch 블록에서 로케일화(에러코드가 올라오면 화면에서 매핑).

- [ ] **Step 1: 전체 목록화**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && for f in login signup feed post_detail create_post account mask_editor report_sheet auth_widgets; do echo "== $f =="; rtk proxy grep -n "'[^']*[가-힣]" lib/community/screens/$f.dart; done`

- [ ] **Step 2: ARB 키 추가(4개 언어)** — 로그인/회원가입/피드/상세/작성/계정/신고 등 영역별 키.

- [ ] **Step 3: 코드 치환** — 파일별로 `AppLocalizations` 치환, `const` 제거 필요 시 처리.

- [ ] **Step 4: 검증**

Run: `flutter gen-l10n && dart analyze lib test && flutter test`
Expected: 이슈 없음, PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/community/screens/*.dart lib/community/theme/community_theme.dart lib/l10n/*.arb
git commit -m "feat(i18n): 커뮤니티 화면 문자열 추출"
```

---

## Task 15: 리모컨·기타 위젯 문자열 추출

**Files:**
- Modify: `lib/screens/remote_control_screen.dart`, `lib/screens/remote_pairing_screen.dart`
- Modify: `lib/overlay/mode_selector.dart`, `lib/poses/pose_picker.dart`, `lib/camera/gallery_launcher.dart`
- Modify: `lib/l10n/*.arb`

**추출 절차:** 각 파일 한국어 UI 리터럴 목록화 → `remote<의미>`/`mode<의미>`/`pose<의미>` 키(4개 언어) → `AppLocalizations` 치환.

- [ ] **Step 1: 전체 목록화**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && for f in screens/remote_control_screen screens/remote_pairing_screen overlay/mode_selector poses/pose_picker camera/gallery_launcher; do echo "== $f =="; rtk proxy grep -n "'[^']*[가-힣]" lib/$f.dart; done`

- [ ] **Step 2: ARB 키 추가(4개 언어)**

- [ ] **Step 3: 코드 치환** — `gallery_launcher.dart`가 BuildContext 없이 문구를 만든다면, 호출하는 화면에서 문구를 주입하도록 시그니처를 조정하거나 에러코드를 반환하도록 변경.

- [ ] **Step 4: 검증**

Run: `flutter gen-l10n && dart analyze lib test && flutter test`
Expected: 이슈 없음, PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/remote_*.dart lib/overlay/mode_selector.dart lib/poses/pose_picker.dart lib/camera/gallery_launcher.dart lib/l10n/*.arb
git commit -m "feat(i18n): 리모컨·모드·포즈 화면 문자열 추출"
```

---

## Task 16: nickname_generator 로케일별 단어 목록 (TDD)

**Files:**
- Modify: `lib/community/nickname_generator.dart`
- Modify: 호출부(닉네임 생성 지점 — `user_repository.dart` 또는 `auth_service.dart`의 `ensureProfile`)
- Test: `test/community/nickname_generator_test.dart`

**Interfaces:**
- Produces: `String generateNickname({Random? random, String localeCode = 'ko'})`. localeCode에 맞는 형용사·동물 목록 사용, 미지원 코드는 ko 폴백.

- [ ] **Step 1: 실패 테스트 작성**

`test/community/nickname_generator_test.dart` (기존 있으면 확장):
```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/nickname_generator.dart';

void main() {
  test('ko는 한국어 형용사+동물', () {
    final n = generateNickname(random: Random(1), localeCode: 'ko');
    expect(RegExp(r'[가-힣]').hasMatch(n), isTrue);
  });
  test('en은 영어 단어', () {
    final n = generateNickname(random: Random(1), localeCode: 'en');
    expect(RegExp(r'[A-Za-z]').hasMatch(n), isTrue);
    expect(RegExp(r'[가-힣]').hasMatch(n), isFalse);
  });
  test('미지원 로케일은 ko 폴백', () {
    final n = generateNickname(random: Random(1), localeCode: 'xx');
    expect(RegExp(r'[가-힣]').hasMatch(n), isTrue);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/community/nickname_generator_test.dart`
Expected: FAIL (localeCode 파라미터 없음).

- [ ] **Step 3: 구현**

`lib/community/nickname_generator.dart`에 로케일별 목록 추가하고 함수 시그니처 확장:
```dart
const _adjKo = ['귀여운','용감한','느긋한','엉뚱한','따뜻한','수줍은','씩씩한','나른한'];
const _animalKo = ['너구리','수달','고양이','판다','여우','펭귄','고슴도치','알파카'];
const _adjEn = ['Cute','Brave','Chill','Quirky','Warm','Shy','Bold','Sleepy'];
const _animalEn = ['Raccoon','Otter','Cat','Panda','Fox','Penguin','Hedgehog','Alpaca'];
const _adjJa = ['かわいい','ゆうかんな','のんびり','ふしぎな','あたたかい','てれや','げんきな','ねむい'];
const _animalJa = ['たぬき','かわうそ','ねこ','パンダ','きつね','ペンギン','はりねずみ','アルパカ'];
const _adjZh = ['可爱的','勇敢的','悠闲的','古怪的','温暖的','害羞的','活泼的','慵懒的'];
const _animalZh = ['浣熊','水獭','猫','熊猫','狐狸','企鹅','刺猬','羊驼'];

String generateNickname({Random? random, String localeCode = 'ko'}) {
  final r = random ?? Random();
  final (adjs, animals) = switch (localeCode) {
    'en' => (_adjEn, _animalEn),
    'ja' => (_adjJa, _animalJa),
    'zh' => (_adjZh, _animalZh),
    _ => (_adjKo, _animalKo),
  };
  final adj = adjs[r.nextInt(adjs.length)];
  final animal = animals[r.nextInt(animals.length)];
  final number = r.nextInt(10000);
  final sep = localeCode == 'en' ? ' ' : '';
  return '$adj$sep$animal$number';
}
```
(기존 `nicknameAdjectives`/`nicknameAnimals` 참조처가 있으면 `_adjKo`/`_animalKo`로 정리하거나 하위호환 export 유지.)

- [ ] **Step 4: 호출부에 로케일 전달**

닉네임 생성 지점에서 현재 로케일을 전달. BuildContext가 있는 회원가입 흐름이면 `Localizations.localeOf(context).languageCode`를 서비스로 넘긴다. context가 없으면 `PlatformDispatcher.instance.locale.languageCode`(dart:ui) 사용.

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/community/nickname_generator_test.dart && dart analyze lib test`
Expected: PASS, 이슈 없음.

- [ ] **Step 6: 커밋**

```bash
git add lib/community/nickname_generator.dart lib/community/user_repository.dart test/community/nickname_generator_test.dart
git commit -m "feat(i18n): 닉네임 생성 로케일별 단어 목록"
```

---

## Task 17: 날짜/숫자 포맷 로케일화

**Files:**
- Modify: 날짜 표시 지점(피드/상세의 타임스탬프 포맷 위치 — `lib/community/screens/feed_screen.dart`·`post_detail_screen.dart` 또는 공용 포맷 유틸)

- [ ] **Step 1: 날짜 포맷 지점 확인**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && rtk proxy grep -rn "DateFormat\|intl\|\.year\|\.month\|toString().*날짜\|분 전\|시간 전" lib/community`

- [ ] **Step 2: intl DateFormat로 교체**

한국어 하드코딩 상대시간/날짜 문구가 있으면 `intl`의 `DateFormat`(로케일 인자 = `Localizations.localeOf(context).toString()`)로 교체. "N분 전" 류 상대표현은 ARB에 복수/치환 키로 정의:
```json
  "timeMinutesAgo": "{count}분 전",
  "@timeMinutesAgo": { "placeholders": { "count": { "type": "int" } } }
```
(en/ja/zh 초안 추가.)

- [ ] **Step 3: 검증**

Run: `flutter gen-l10n && dart analyze lib test && flutter test`
Expected: 이슈 없음, PASS.

- [ ] **Step 4: 커밋**

```bash
git add lib/community lib/l10n/*.arb
git commit -m "feat(i18n): 날짜/상대시간 표시 로케일화"
```

---

## Task 18: 번역 최종 검수 + gen-l10n 무경고 + CLAUDE.md 갱신

**Files:**
- Modify: `lib/l10n/app_en.arb`, `app_ja.arb`, `app_zh.arb`
- Modify: `CLAUDE.md`

- [ ] **Step 1: 누락 키 점검**

Run:
```bash
export PATH="/Users/soonbok/flutter/bin:$PATH"
flutter gen-l10n 2>&1 | tee /tmp/genl10n.log
```
Expected: "Untranslated message" 경고 목록 확인. 경고에 나온 키를 en/ja/zh ARB에 채운다.

- [ ] **Step 2: 용어집 대조 검수**

en/ja/zh 전 키를 용어집(Global 섹션)과 대조해 일관성 확인·수정. ja는 へたっぴ 톤(친근한 반말체) 유지, zh는 간체.

- [ ] **Step 3: CLAUDE.md 규약 갱신**

`CLAUDE.md`의 `- 정렬 판정 문자열은 '좋아요'로 통일...` 줄을 다음으로 교체:
```
- 정렬 판정은 `ThirdsAlignment.isAligned` 불리언으로 통일(GuideMetrics·GuidePainter가 이 값으로 분기). 표시문구는 `lib/l10n/guide_text.dart`가 로케일별로 매핑한다.
```
스택 섹션에 다국어 한 줄 추가:
```
- 다국어: `flutter_localizations`+`intl`(gen-l10n). 지원 ko/en/ja/zh(간체), 미지원→ko 폴백. 문자열은 `lib/l10n/app_*.arb`.
```

- [ ] **Step 4: 무경고 확인**

Run: `flutter gen-l10n 2>&1 | grep -i untranslated || echo "no untranslated"`
Expected: `no untranslated`.

- [ ] **Step 5: 커밋**

```bash
git add lib/l10n/*.arb CLAUDE.md
git commit -m "feat(i18n): 번역 검수 완료 + 규약 문서 갱신"
```

---

## Task 19: 전체 검증 + 수동 기기 확인

**Files:** 없음(검증 전용)

- [ ] **Step 1: 완료 게이트**

Run:
```bash
export PATH="/Users/soonbok/flutter/bin:$PATH"
tool/verify.sh
```
Expected: format 검사 통과 + `dart analyze lib test` 이슈 없음 + `flutter test` 전체 PASS.

- [ ] **Step 2: 남은 한국어 UI 리터럴 스캔**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && rtk proxy grep -rn "Text('[^']*[가-힣]\|content: Text('[^']*[가-힣]\|'[^']*[가-힣][^']*'" lib --include="*.dart" | rtk proxy grep -v "l10n\|//"`
Expected: 사용자 노출 리터럴이 남아있지 않음(주석·로그 제외). 남으면 해당 화면 태스크 절차로 추출.

- [ ] **Step 3: 수동 기기 검증**

기기/시뮬레이터 언어를 en → ja → zh(간체)로 바꿔가며:
- 홈 화면 아이콘 이름: Ddongson Camera / へたっぴカメラ / 手残相机
- 카메라 가이드 힌트(수평·잘림·위치·줌·각도·"찍으세요!") 번역 표시
- 커뮤니티 로그인/피드/작성/계정 문구 번역
- 미지원 언어(예: 프랑스어) 설정 시 한국어 폴백
확인 후 이슈 있으면 해당 태스크로 회귀.

- [ ] **Step 4: 최종 커밋(문서 상태)**

```bash
git add -A && git commit -m "chore(i18n): 다국어 지원 완료 검증" --allow-empty
```
