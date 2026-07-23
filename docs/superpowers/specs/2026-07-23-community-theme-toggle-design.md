# 커뮤니티 화면 화이트/블랙 테마 선택 — 설계

작성일: 2026-07-23

## 목표

커뮤니티 화면(피드·게시글 상세·내 프로필·글쓰기·로그인·회원가입·차단 목록·마스크 편집기 및 관련 다이얼로그/시트)에서 사용자가 **라이트(화이트)·다크(블랙) 테마를 선택**할 수 있게 한다. 촬영 화면은 지금처럼 항상 검은 배경을 유지한다.

## 결정 사항 (사용자 확정)

- **적용 범위**: 커뮤니티 화면만. 촬영 화면(`camera_screen`)·`capture_result_screen`은 영향 없음.
- **토글 위치**: 계정(내 프로필) 화면 `account_screen`.
- **기본값**: 기기 설정 따라감(System). 선택지는 `시스템 설정 / 라이트 / 다크`.
- **저장**: 사용자가 고른 값은 기기에 저장되어 다음 실행에도 유지(`shared_preferences`).

## 현재 상태 (조사 결과)

- 앱 전역이 다크 테마 하나(`lib/theme/app_theme.dart` `buildAppTheme()`)로 구성. 촬영 화면은 별도로 자기 검은 배경을 직접 그림.
- 커뮤니티 화면들은 색을 **하드코딩**한다: 크림 텍스트 `Color(0xFFF4F1EA)`, 흐린 변형 `Color(0x80F4F1EA)`, 표면 `AppColors.surfaceApp`(0xFF0B0C0E)·`AppColors.surfaceCard`(0xFF1C1E22), 구분선 `0x1AFFFFFF` 등. `Theme.of(context)`를 읽는 곳은 없음(커뮤니티 화면 기준 `Theme.of`/`colorScheme` 참조 0건).
- 브랜드/의미 색(앰버 `accent` 0xFFFFC107, 에러 `error`, ready `0xFF69F0AE` 등)은 라이트·다크 양쪽에서 판독 가능 → **양쪽 공유**, 변경하지 않음.
- 커뮤니티 진입: `camera_screen.dart:599`에서 `FeedScreen`을 루트 Navigator에 push. 이후 `AccountScreen`, `PostDetailScreen`, `BlockedUsersScreen` 등은 각 화면에서 다시 push.
- `shared_preferences ^2.5.5` 이미 의존성에 존재(추가 불필요).

## 접근: 표면 색을 테마 기반으로 전환 (A안)

**핵심 원리**: 뒤집어야 하는 것은 표면·텍스트 색뿐이다. 브랜드 색은 공유한다. 컨트롤러를 루트 Navigator 위에 두어 모든 커뮤니티 경로(중첩 push 포함)가 현재 테마를 읽게 하고, 각 커뮤니티 화면은 지역 `Theme`로 감싸 팔레트에서 색을 가져온다. 촬영 화면은 컨트롤러를 무시한다.

### 구성 요소

1. **`lib/community/theme/community_theme_controller.dart`**
   - `enum CommunityThemeMode { system, light, dark }`.
   - `class CommunityThemeController extends ChangeNotifier`
     - `CommunityThemeMode mode` (초기 `system`).
     - `Future<void> load()` — `SharedPreferences`에서 키 `community_theme_mode`(문자열) 읽어 반영. 값이 없으면 `system`. 실패는 조용히 무시하고 `system` 유지.
     - `Future<void> setMode(CommunityThemeMode)` — 상태 갱신 → `notifyListeners()` → 저장.
   - 순수 저장/알림 로직만. 색·위젯 판단 없음.

2. **`lib/community/theme/community_theme.dart`** (색 토큰 + Material ThemeData 조립)
   - `class CommunityPalette` — 표면 계열 토큰만 보유: `surface`, `surfaceCard`, `text`, `textMuted`, `divider`, `inputFill`, `border`. 브랜드 색은 `AppColors` 재사용.
     - `CommunityPalette.dark` — 현재 값(0xFF0B0C0E / 0xFF1C1E22 / 0xFFF4F1EA / 0x80F4F1EA / 0x1AFFFFFF …) 그대로.
     - `CommunityPalette.light` — 화이트 계열(예: surface `0xFFF7F5F0`, card `0xFFFFFFFF`, text `0xFF17181B`, muted `0x8017181B`, divider `0x14000000`). 정확한 헥스는 구현 시 대비(가독성) 확인 후 확정.
   - `ThemeData buildCommunityTheme(Brightness)` — 팔레트로 `ColorScheme`·`scaffoldBackgroundColor`·AppBar/Card/ListTile/Dialog/BottomSheet/Input/SnackBar 테마를 구성(기존 `buildAppTheme` 구조 재사용, 표면·전경색만 팔레트에서 주입). 브랜드 색(accent/error)은 양쪽 동일.
   - `class CommunityTheme extends InheritedNotifier<CommunityThemeController>` + `static CommunityTheme of(BuildContext)`.
     - `Brightness effectiveBrightness(BuildContext)` — `mode == system`이면 `MediaQuery.platformBrightnessOf(context)`, 아니면 light/dark.
     - `CommunityPalette paletteOf(BuildContext)` / `ThemeData themeOf(BuildContext)` 편의 접근자.

3. **`lib/main.dart`**
   - 앱 시작 시 `CommunityThemeController` 생성 후 `load()` 호출(await; 실패해도 진행).
   - `MaterialApp.builder`에서 자식을 `CommunityTheme(controller: …, child: child!)`로 감싼다 → **Navigator 위**에 위치하므로 모든 라우트가 접근 가능. 촬영 화면은 이 값을 읽지 않으므로 영향 없음.
   - 전역 `MaterialApp.theme`는 지금의 다크 유지(촬영/기타 기본 표면용).

4. **커뮤니티 화면 리팩터링**
   - 대상: `feed_screen`, `post_detail_screen`, `account_screen`, `create_post_screen`, `login_screen`, `signup_screen`, `blocked_users_screen`, `mask_editor_screen`, `auth_widgets`, `confirm_dialog`, `report_sheet`, `sign_in_sheet`, `like_button`(색 참조가 있는 것만).
   - 각 화면 `build`에서 최상위 위젯을 `Theme(data: CommunityTheme.of(context).themeOf(context), child: Scaffold(...))`로 감싼다. 이로써 Material 위젯(AppBar/Card/Dialog/Input 등)은 자동 적응.
   - 하드코딩된 표면·텍스트 색(`_text`, `_muted`, `AppColors.surfaceApp/surfaceCard`, 구분선 리터럴 등)을 `final p = CommunityTheme.of(context).paletteOf(context);` 후 `p.text`, `p.textMuted`, `p.surface`, `p.surfaceCard` … 로 교체.
   - 파일 상단의 `const _text = …` 같은 컴파일타임 상수는 팔레트가 런타임 값이므로 지역 변수 조회로 전환.
   - 브랜드 색(`AppColors.accent`/`error`/`ready` 등) 및 앰버 그라디언트 커버 등은 그대로 둔다.

5. **테마 선택 UI (`account_screen`)**
   - "화면 테마" `ListTile` 추가(아이콘 `Icons.brightness_6`, trailing에 현재 모드 라벨).
   - 탭 시 선택 시트/다이얼로그(`시스템 설정` / `라이트` / `다크`) → `CommunityTheme.of(context).controller.setMode(...)`.
   - 현재 선택에 체크 표시. 선택 즉시 커뮤니티 화면 전체 리빌드로 반영.

## 데이터 흐름

1. 앱 시작 → `controller.load()`로 저장된 모드 복원(없으면 `system`).
2. `MaterialApp.builder`가 `CommunityTheme`(InheritedNotifier)로 트리 상단을 감쌈.
3. 커뮤니티 화면 `build` → `CommunityTheme.of(context)`로 유효 밝기·팔레트·ThemeData 조회 → `Theme`로 감싸고 팔레트 색 사용.
4. 계정 화면에서 모드 변경 → `setMode` → `notifyListeners` + 저장 → InheritedNotifier 의존 화면들 리빌드 → 새 테마 반영.
5. `system` 모드일 때 OS 라이트/다크 변경 → `MediaQuery.platformBrightness` 변화 → 커뮤니티 화면 자동 리빌드.

## 경계와 책임 (단위 분리)

- `community_theme_controller.dart`: 상태·영속화만. 색/위젯 모름. 단위 테스트 가능(모드 전환·저장/복원).
- `community_theme.dart`: 밝기→팔레트→ThemeData 매핑(순수 함수적). InheritedNotifier 배선.
- 각 화면: 팔레트를 **소비**만 한다. 테마 판단 로직을 화면에 넣지 않는다.

## 테스트 전략

- **컨트롤러 단위 테스트**(순수 로직): 기본값 `system`, `setMode` 후 값 반영·`notifyListeners` 호출, `SharedPreferences.setMockInitialValues`로 저장/복원 왕복. 잘못된 저장값은 `system`으로 폴백.
- **팔레트 매핑 테스트**: `buildCommunityTheme(light/dark)`의 `scaffoldBackgroundColor`·`colorScheme.brightness`가 기대와 일치, 브랜드 색 동일성.
- **화면 렌더링/전환**: 단위 테스트 무의미 → 기기 수동 검증(라이트/다크/시스템 전환, 각 커뮤니티 화면 가독성, 촬영 화면이 검은색 유지되는지).

## 완료 정의

- 계정 화면에 "화면 테마" 선택(시스템/라이트/다크)이 있고, 선택 즉시 커뮤니티 화면 전체(내 프로필 포함)가 해당 테마로 바뀐다.
- 선택값이 앱 재실행 후에도 유지된다.
- `system` 모드에서 OS 테마를 따라간다.
- 촬영 화면은 항상 검은 배경.
- 라이트 테마에서 텍스트·표면 대비가 충분해 모든 커뮤니티 화면이 판독 가능.
- `tool/verify.sh`(format+analyze+test) 통과. `dart analyze lib test` 무이슈.

## 비목표 (YAGNI)

- 촬영/결과 화면 테마화.
- 브랜드 색의 테마별 분기.
- 사용자 지정 색/추가 테마(세피아 등).
- 화면 전환 애니메이션(기본 리빌드로 충분).
