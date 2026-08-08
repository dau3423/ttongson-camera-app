# 다국어(i18n) 지원 설계 — ko · en · ja · zh-Hans

작성일: 2026-08-09

## 1. 목표

똥손카메라를 한국어 외에 **영어·일본어·중국어(간체)** 로 표시한다. 기기 언어를
자동으로 따르고, 미지원 언어에서는 **한국어로 폴백**한다. 앱 내 언어 선택 UI는
만들지 않는다(YAGNI). 전체 앱(카메라 코어 + 커뮤니티 + 리모컨)을 대상으로 한다.

### 로케일별 앱 이름 (홈 화면 아이콘 라벨)

| 로케일 | 앱 이름 |
|---|---|
| ko (기준) | 똥손카메라 |
| en | Ddongson Camera |
| ja | へたっぴカメラ |
| zh (간체) | 手残相机 |

번역 초안은 담당자(Claude)가 작성하고 사용자가 검수한다.

## 2. 접근법

Flutter 공식 **`gen-l10n` + ARB** 방식(`flutter_localizations` + `intl`)을 사용한다.
런타임 언어 전환이 필요 없으므로 외부 패키지(easy_localization 등)는 도입하지 않는다.

- `l10n.yaml` + `lib/l10n/app_ko.arb`(템플릿/기준) · `app_en.arb` · `app_ja.arb` · `app_zh.arb`
- `flutter gen-l10n`으로 `AppLocalizations` 생성 → `AppLocalizations.of(context)!.key`로 참조.
- 미번역 키는 템플릿(ko) 값으로 폴백된다.

### 2.1 MaterialApp 배선

```dart
MaterialApp(
  onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales, // ko, en, ja, zh
  // localeResolutionCallback로 미지원 언어 → ko 폴백 보장
  ...
)
```

`title:` 하드코딩 문자열은 `onGenerateTitle`으로 대체한다.

## 3. 문자열 아키텍처

### 3.1 위젯/화면 (BuildContext 있음)

`camera_screen`, `capture_result_screen`, `community/screens/*`, `remote_*_screen`,
`mode_selector`, `pose_picker` 등 대부분의 사용자 문구는 `AppLocalizations.of(context)`로
직접 참조한다.

### 3.2 `analysis/` 순수 Dart (BuildContext 없음) — 판정값/표시문구 분리

`analysis/`는 Flutter/plugin import가 금지된 순수 계산부다. 현재 각 분석 함수가
**한국어 힌트 문자열을 직접 생성**하고 있어(예: `'왼쪽을 내리세요'`), 이를 로컬라이즈
하려면 표시문구를 계산부에서 제거해야 한다. 이는 프로젝트의 "계산↔렌더 분리" 원칙을
강화하는 방향이다.

각 분석 클래스의 `String hint`/`message` 필드를 **의미값 enum**으로 교체한다:

| 파일 | 기존 | 변경 |
|---|---|---|
| `tilt.dart` | `String hint` | `enum TiltHint { none, lowerLeft, lowerRight }` |
| `headroom.dart` | `String hint` | `enum HeadroomHint { none, raiseCamera, lowerCamera }` |
| `angle_zoom.dart` (Angle) | `String hint` | `enum AngleHint { none, eyeLevelUp, eyeLevelDown, frontalUp, frontalDown }` |
| `angle_zoom.dart` (Zoom) | `String hint` | `enum ZoomHint { none, closer, farther }` |
| `thirds.dart` | `String hint` (`'좋아요'` 센티넬 포함) | 방향 집합(`moveLeft/right/up/down`) + `bool isAligned` |
| `crop.dart` | `String get message` | 이미 `top/bottom/left/right` 불리언 보유 → enum 불필요, `message` getter 제거 |
| `guide_step.dart` | `String message` | 이미 `GuideStepKind` 보유 → `message` 필드 제거, kind로 렌더 |
| `guide_metrics.dart` | `activeHints` (문자열 목록) | enum/구조값 목록으로 변경, 문자열화는 UI에서 |

`'좋아요'` 센티넬 규약(CLAUDE.md)은 **`bool isAligned` 판정값으로 통일**로 바꾼다.
분기 로직이 더 이상 특정 문자열에 의존하지 않는다.

### 3.3 UI 매핑 레이어

analysis enum → 로컬라이즈 문자열 변환을 담당하는 매핑 함수를 위젯 레이어에 둔다
(예: `lib/l10n/guide_text.dart`). `AppLocalizations`와 enum을 입력받아 표시문자열을
반환하는 순수 함수로 작성해 단위 테스트한다.

`guide_overlay.dart`(CustomPainter)는 판단하지 않는다는 원칙을 유지한다. 화면 위젯이
매핑 레이어로 문자열을 만들어 painter에 주입한다.

### 3.4 컨텍스트 없는 서비스/리포지토리

`auth_service`, `post_repository`, `user_repository` 등은 대부분 예외를 rethrow하고
사용자 문구는 화면(SnackBar)에서 붙인다 → 화면에서 로컬라이즈한다. 문자열 값이
계산부에서 올라와야 하는 소수 지점은 **에러코드/enum**으로 올려 UI에서 번역한다.

## 4. 네이티브 앱 이름

### 4.1 Android

- `AndroidManifest.xml`: `android:label="@string/app_name"`로 변경.
- `res/values/strings.xml`(ko 기본) = `똥손카메라`
- `res/values-en/strings.xml` = `Ddongson Camera`
- `res/values-ja/strings.xml` = `へたっぴカメラ`
- `res/values-zh/strings.xml` = `手残相机` (Flutter `supportedLocales`의 `zh`와 일치시켜 `values-zh` 사용)

### 4.2 iOS

- `Info.plist`에 `CFBundleLocalizations` 배열(`ko`, `en`, `ja`, `zh-Hans`) 추가.
- `ko.lproj` · `en.lproj` · `ja.lproj` · `zh-Hans.lproj`의 `InfoPlist.strings`에
  `CFBundleDisplayName` 지정.

## 5. 특수 처리

- **`nickname_generator`**: 닉네임은 가입 시 1회 생성되어 서버에 영속된다. **생성 시점
  로케일**의 단어 목록(형용사·동물)을 사용하도록 en/ja/zh 목록을 추가한다. 기존 사용자
  닉네임은 그대로 둔다. 순수 Dart 유지(로케일 코드를 인자로 주입).
- **날짜/숫자**: 피드 타임스탬프 등은 `intl`의 `DateFormat`을 현재 로케일로 포맷.
- **문서**: CLAUDE.md의 `'좋아요'` 문자열 통일 규약을 `isAligned` 판정값 규약으로 갱신.

## 6. 테스트 · 검증

- `analysis/` 리팩터는 **엄격 TDD**: 기존 문자열 단언 테스트를 enum 단언으로 재작성
  (실패 테스트 → 최소 구현 → 통과 → 커밋).
- UI 매핑 함수(`guide_text.dart` 등)도 순수 함수로 두어 로케일별 매핑 단위 테스트.
- ARB 키 누락 시 `flutter gen-l10n` 경고가 나지 않도록 4개 언어 키를 맞춘다.
- 완료 게이트: `tool/verify.sh`(format + `dart analyze lib test` + `flutter test`) 통과.
- 실기기 수동 검증: 기기 언어를 en/ja/zh로 바꿔 앱 이름·주요 화면·가이드 힌트 확인.

## 7. 구현 단계

- **P1 배관**: `intl`/`flutter_localizations` 의존성, `l10n.yaml`, `MaterialApp` 배선,
  네이티브 앱 이름(Android/iOS), 빈 ARB 골격.
- **P2 analysis 리팩터**: 각 분석 클래스 enum화(TDD) + `guide_text.dart` 매핑 레이어 +
  `guide_overlay`/`camera_screen` 배선.
- **P3 화면 문자열 추출**: camera/capture/community/remote 등 화면 문구를 ARB 키로 추출·치환.
- **P4 특수처리 + 번역**: nickname 로케일별 목록, 날짜 포맷, 4개 언어 번역 초안 채우기·검수.

## 8. 범위 밖 (Non-goals)

- 앱 내 언어 선택 UI (기기 언어 자동만).
- 중국어 번체(zh-Hant) 지원.
- 서버/Firestore에 저장된 사용자 생성 콘텐츠(게시글 본문 등)의 자동 번역.
- 기존 사용자 닉네임의 소급 로케일 변경.
