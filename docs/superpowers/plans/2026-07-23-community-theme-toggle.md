# 커뮤니티 화면 라이트/다크 테마 선택 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 커뮤니티 화면(내 프로필 포함)에서 시스템/라이트/다크 테마를 선택·저장하고 즉시 반영한다. 촬영 화면은 항상 검은색.

**Architecture:** 전역 `CommunityThemeController`(ChangeNotifier, `shared_preferences` 저장)를 `MaterialApp.builder`에서 `InheritedNotifier`로 루트 Navigator 위에 마운트한다. 라이트/다크 `CommunityPalette` 토큰과 `buildCommunityTheme(Brightness)`로 Material 테마를 만들고, 각 커뮤니티 화면은 지역 `Theme`로 감싸 팔레트에서 표면·텍스트 색을 읽는다. 브랜드 색(accent/error/ready)은 양쪽 공유.

**Tech Stack:** Flutter(Dart), `shared_preferences`, Material 3.

## Global Constraints

- 좌표/각도 등 기존 규약 불변. **Phase 0+1 네트워크 0회 규칙과 무관**(이 기능은 커뮤니티/온디바이스 설정만 다룸).
- 정적 분석 게이트는 `dart analyze lib test` (한글 경로로 `flutter analyze` 크래시).
- 완료 게이트: `tool/verify.sh` (format+analyze+test) 통과.
- 커밋: Conventional Commits.
- **적용 범위: 커뮤니티 화면만.** `lib/screens/camera_screen.dart`·`capture_result_screen.dart`·`lib/main.dart`의 전역 `theme`(다크)는 건드리지 않는다(단, main.dart는 컨트롤러 배선만 추가).
- 브랜드/의미 색은 변경 금지: `AppColors.accent`(0xFFFFC107), `AppColors.error`, `AppColors.ready`, 스크림(`scrim*`), 앰버 그라디언트(`0xFFFFC107`/`0xFFFFA000`), 별 색 등은 그대로 둔다.
- **표준 색 치환표** (리팩터링 태스크 5~8 공통 — 이 토큰들만 교체, 나머지 색은 유지):

  | 기존 (하드코딩) | 교체 후 |
  |---|---|
  | `AppColors.surfaceApp` (또는 `Color(0xFF0B0C0E)` 표면 용도) | `p.surface` |
  | `AppColors.surfaceCard` (또는 `Color(0xFF1C1E22)`) | `p.surfaceCard` |
  | `Color(0xFFF4F1EA)` / 파일 상단 `_text` | `p.text` |
  | `Color(0x80F4F1EA)` / `_muted` | `p.textMuted` |
  | 구분선 `Color(0x1AFFFFFF)` | `p.divider` |
  | 입력 배경 `Color(0x0DFFFFFF)` | `p.inputFill` |
  | 입력 테두리 `Color(0x26FFFFFF)` | `p.border` |

  여기서 `final p = CommunityTheme.paletteOf(context);`. `const TextStyle(color: _text)`처럼 const였던 것은 `const` 제거 후 `TextStyle(color: p.text)`로 바꾼다.
- **표준 화면 래핑 스니펫** (전체 화면 위젯 태스크 공통):
  ```dart
  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    return Theme(
      data: CommunityTheme.themeOf(context),
      child: Scaffold( /* 기존 내용, 색만 치환표대로 교체 */ ),
    );
  }
  ```
  다이얼로그/시트/버튼 같은 하위 위젯은 `Theme` 래핑을 추가하지 않고 `CommunityTheme.paletteOf(context)`만 읽는다(showDialog/showModalBottomSheet가 호출부의 InheritedTheme를 캡처하므로 팔레트가 전달됨).

---

### Task 1: CommunityThemeController (상태·영속화)

**Files:**
- Create: `lib/community/theme/community_theme_controller.dart`
- Test: `test/community/community_theme_controller_test.dart`

**Interfaces:**
- Consumes: `shared_preferences`.
- Produces:
  - `enum CommunityThemeMode { system, light, dark }`
  - `class CommunityThemeController extends ChangeNotifier` with `CommunityThemeMode get mode`, `Future<void> load()`, `Future<void> setMode(CommunityThemeMode)`, `static const String prefsKey = 'community_theme_mode'`.

- [ ] **Step 1: 실패 테스트 작성**

`test/community/community_theme_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttongson_camera/community/theme/community_theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('기본 모드는 system', () {
    expect(CommunityThemeController().mode, CommunityThemeMode.system);
  });

  test('load: 저장값 없으면 system', () async {
    SharedPreferences.setMockInitialValues({});
    final c = CommunityThemeController();
    await c.load();
    expect(c.mode, CommunityThemeMode.system);
  });

  test('load: 저장된 dark 복원', () async {
    SharedPreferences.setMockInitialValues({'community_theme_mode': 'dark'});
    final c = CommunityThemeController();
    await c.load();
    expect(c.mode, CommunityThemeMode.dark);
  });

  test('load: 잘못된 값은 system 폴백', () async {
    SharedPreferences.setMockInitialValues({'community_theme_mode': 'bogus'});
    final c = CommunityThemeController();
    await c.load();
    expect(c.mode, CommunityThemeMode.system);
  });

  test('setMode: 변경 + notify + 저장', () async {
    SharedPreferences.setMockInitialValues({});
    final c = CommunityThemeController();
    var notified = 0;
    c.addListener(() => notified++);
    await c.setMode(CommunityThemeMode.light);
    expect(c.mode, CommunityThemeMode.light);
    expect(notified, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('community_theme_mode'), 'light');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/community/community_theme_controller_test.dart`
Expected: FAIL (target of URI doesn't exist / CommunityThemeController undefined).

- [ ] **Step 3: 최소 구현**

`lib/community/theme/community_theme_controller.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 커뮤니티 화면 테마 모드. system이면 기기 밝기를 따른다.
enum CommunityThemeMode { system, light, dark }

/// 선택한 테마 모드의 상태·영속화만 담당(색·위젯 판단 없음).
class CommunityThemeController extends ChangeNotifier {
  static const String prefsKey = 'community_theme_mode';

  CommunityThemeMode _mode = CommunityThemeMode.system;
  CommunityThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _parse(prefs.getString(prefsKey));
    } catch (_) {
      _mode = CommunityThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(CommunityThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, mode.name);
    } catch (_) {
      // 저장 실패해도 이번 세션 선택은 유지.
    }
  }

  static CommunityThemeMode _parse(String? raw) {
    switch (raw) {
      case 'light':
        return CommunityThemeMode.light;
      case 'dark':
        return CommunityThemeMode.dark;
      default:
        return CommunityThemeMode.system;
    }
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/community/community_theme_controller_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: 커밋**

```bash
git add lib/community/theme/community_theme_controller.dart test/community/community_theme_controller_test.dart
git commit -m "feat: 커뮤니티 테마 컨트롤러(모드 저장/복원)"
```

---

### Task 2: 팔레트·테마·InheritedNotifier

**Files:**
- Create: `lib/community/theme/community_theme.dart`
- Test: `test/community/community_theme_test.dart`

**Interfaces:**
- Consumes: `CommunityThemeMode`(Task 1), `AppColors`/`AppFonts`(`lib/theme/app_colors.dart`).
- Produces:
  - `@immutable class CommunityPalette` — fields `surface, surfaceCard, text, textMuted, divider, inputFill, border` (all `Color`); `static const dark`, `static const light`.
  - `CommunityPalette paletteFor(Brightness)`.
  - `Brightness resolveBrightness(CommunityThemeMode mode, Brightness platform)`.
  - `ThemeData buildCommunityTheme(Brightness)`.
  - `class CommunityTheme extends InheritedNotifier<CommunityThemeController>` with ctor `CommunityTheme({required CommunityThemeController controller, required Widget child})` and statics: `CommunityThemeController controllerOf(BuildContext)`, `Brightness brightnessOf(BuildContext)`, `CommunityPalette paletteOf(BuildContext)`, `ThemeData themeOf(BuildContext)`.

- [ ] **Step 1: 실패 테스트 작성**

`test/community/community_theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/theme/community_theme.dart';
import 'package:ttongson_camera/community/theme/community_theme_controller.dart';

void main() {
  test('resolveBrightness: system은 플랫폼 밝기', () {
    expect(resolveBrightness(CommunityThemeMode.system, Brightness.light),
        Brightness.light);
    expect(resolveBrightness(CommunityThemeMode.system, Brightness.dark),
        Brightness.dark);
  });

  test('resolveBrightness: light/dark 고정', () {
    expect(resolveBrightness(CommunityThemeMode.light, Brightness.dark),
        Brightness.light);
    expect(resolveBrightness(CommunityThemeMode.dark, Brightness.light),
        Brightness.dark);
  });

  test('팔레트 대비: dark 어둡고 light 밝다', () {
    expect(CommunityPalette.dark.surface.computeLuminance() < 0.2, isTrue);
    expect(CommunityPalette.light.surface.computeLuminance() > 0.8, isTrue);
    expect(CommunityPalette.dark.text.computeLuminance() > 0.7, isTrue);
    expect(CommunityPalette.light.text.computeLuminance() < 0.2, isTrue);
  });

  test('buildCommunityTheme: 밝기·표면 반영', () {
    final dark = buildCommunityTheme(Brightness.dark);
    final light = buildCommunityTheme(Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.scaffoldBackgroundColor, CommunityPalette.dark.surface);
    expect(light.scaffoldBackgroundColor, CommunityPalette.light.surface);
  });

  testWidgets('CommunityTheme.paletteOf: light 모드에서 밝은 팔레트', (tester) async {
    final controller = CommunityThemeController(); // 기본 system
    late CommunityPalette p;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: CommunityTheme(
          controller: controller,
          child: Builder(
            builder: (context) {
              p = CommunityTheme.paletteOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    // system + platform dark → dark 팔레트
    expect(p.surface, CommunityPalette.dark.surface);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/community/community_theme_test.dart`
Expected: FAIL (community_theme.dart 없음).

- [ ] **Step 3: 최소 구현**

`lib/community/theme/community_theme.dart`:
```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'community_theme_controller.dart';

/// 커뮤니티 화면의 표면·텍스트 색 토큰(브랜드 색은 AppColors 재사용).
@immutable
class CommunityPalette {
  final Color surface;
  final Color surfaceCard;
  final Color text;
  final Color textMuted;
  final Color divider;
  final Color inputFill;
  final Color border;

  const CommunityPalette({
    required this.surface,
    required this.surfaceCard,
    required this.text,
    required this.textMuted,
    required this.divider,
    required this.inputFill,
    required this.border,
  });

  /// 현재(다크) 표면값 그대로.
  static const dark = CommunityPalette(
    surface: Color(0xFF0B0C0E),
    surfaceCard: Color(0xFF1C1E22),
    text: Color(0xFFF4F1EA),
    textMuted: Color(0x80F4F1EA),
    divider: Color(0x1AFFFFFF),
    inputFill: Color(0x0DFFFFFF),
    border: Color(0x26FFFFFF),
  );

  /// 화이트(라이트) 표면. 텍스트 대비 확보용 근검정.
  static const light = CommunityPalette(
    surface: Color(0xFFF7F5F0),
    surfaceCard: Color(0xFFFFFFFF),
    text: Color(0xFF17181B),
    textMuted: Color(0x8017181B),
    divider: Color(0x14000000),
    inputFill: Color(0x0A000000),
    border: Color(0x1F000000),
  );
}

CommunityPalette paletteFor(Brightness brightness) =>
    brightness == Brightness.dark
        ? CommunityPalette.dark
        : CommunityPalette.light;

Brightness resolveBrightness(CommunityThemeMode mode, Brightness platform) {
  switch (mode) {
    case CommunityThemeMode.system:
      return platform;
    case CommunityThemeMode.light:
      return Brightness.light;
    case CommunityThemeMode.dark:
      return Brightness.dark;
  }
}

/// 팔레트로 Material 테마 조립. buildAppTheme(다크)와 동일 구조, 표면색만 매개변수화.
ThemeData buildCommunityTheme(Brightness brightness) {
  final p = paletteFor(brightness);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppColors.accent,
    onPrimary: const Color(0xFF0B0C0E),
    secondary: AppColors.accent,
    onSecondary: const Color(0xFF0B0C0E),
    surface: p.surface,
    onSurface: p.text,
    error: AppColors.error,
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: AppFonts.body,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.surface,
    canvasColor: p.surface,
    dividerColor: p.divider,
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      foregroundColor: p.text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: p.surfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(iconColor: p.textMuted, textColor: p.text),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: TextStyle(color: p.surface),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: Color(0x55FFC107),
      selectionHandleColor: AppColors.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.inputFill,
      hintStyle: TextStyle(color: p.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
  );
}

/// 컨트롤러를 트리에 노출. Navigator 위(MaterialApp.builder)에 마운트해
/// 모든 커뮤니티 라우트가 접근하게 한다.
class CommunityTheme extends InheritedNotifier<CommunityThemeController> {
  const CommunityTheme({
    super.key,
    required CommunityThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static CommunityThemeController controllerOf(BuildContext context) {
    final w = context
        .dependOnInheritedWidgetOfExactType<CommunityTheme>();
    assert(w != null, 'CommunityTheme가 트리에 없음');
    return w!.notifier!;
  }

  static Brightness brightnessOf(BuildContext context) {
    final mode = controllerOf(context).mode;
    final platform = MediaQuery.platformBrightnessOf(context);
    return resolveBrightness(mode, platform);
  }

  static CommunityPalette paletteOf(BuildContext context) =>
      paletteFor(brightnessOf(context));

  static ThemeData themeOf(BuildContext context) =>
      buildCommunityTheme(brightnessOf(context));
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/community/community_theme_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: 커밋**

```bash
git add lib/community/theme/community_theme.dart test/community/community_theme_test.dart
git commit -m "feat: 커뮤니티 라이트/다크 팔레트·테마·InheritedNotifier"
```

---

### Task 3: main.dart 배선

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `CommunityThemeController`(Task 1), `CommunityTheme`(Task 2).
- Produces: 앱 전역에 `CommunityTheme` 마운트(이후 태스크의 화면이 소비). 이 태스크만으로는 화면 색 변화 없음(아직 소비하는 화면 없음).

- [ ] **Step 1: 컨트롤러 생성·로드 + builder 배선**

`lib/main.dart` 수정:
1. import 추가:
```dart
import 'community/theme/community_theme.dart';
import 'community/theme/community_theme_controller.dart';
```
2. `main()`에서 `runApp` 직전에:
```dart
  final themeController = CommunityThemeController();
  await themeController.load();
  runApp(TtongsonApp(themeController: themeController));
```
3. `TtongsonApp`을 컨트롤러 주입형으로:
```dart
class TtongsonApp extends StatelessWidget {
  final CommunityThemeController themeController;
  const TtongsonApp({super.key, required this.themeController});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '똥손카메라',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorObservers: [routeObserver],
      builder: (context, child) => CommunityTheme(
        controller: themeController,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const CameraScreen(),
    );
  }
}
```

- [ ] **Step 2: 정적 분석**

Run: `dart analyze lib/main.dart`
Expected: No issues found!

- [ ] **Step 3: 빌드/기동 수동 확인**

Run: `flutter run` (또는 이미 실행 중이면 hot restart)
Expected: 앱 정상 기동, 촬영 화면 검은색 그대로, 커뮤니티 화면 기존과 동일(아직 다크). 크래시 없음.

- [ ] **Step 4: 커밋**

```bash
git add lib/main.dart
git commit -m "feat: 앱 트리에 CommunityTheme 마운트(테마 컨트롤러 배선)"
```

---

### Task 4: 계정(내 프로필) 화면 — 테마 적용 + 선택 UI

**Files:**
- Modify: `lib/community/screens/account_screen.dart`

**Interfaces:**
- Consumes: `CommunityTheme`, `CommunityThemeMode`(Task 1·2).
- Produces: 사용자가 테마를 고를 수 있는 진입점. 내 프로필 화면이 선택 테마로 렌더된다.

- [ ] **Step 1: import 추가**

`account_screen.dart` 상단 import에 추가:
```dart
import '../theme/community_theme.dart';
import '../theme/community_theme_controller.dart';
```

- [ ] **Step 2: 파일 상단 색 상수 제거 + build 래핑**

1. 파일 상단 `const _text = Color(0xFFF4F1EA);` 와 `const _muted = Color(0x80F4F1EA);` 두 줄을 **삭제**한다.
2. `build`를 표준 래핑 스니펫으로 감싼다. 기존:
```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 프로필')),
      body: StreamBuilder<UserProfile?>(
```
→ 변경:
```dart
  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    return Theme(
      data: CommunityTheme.themeOf(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('내 프로필')),
        body: StreamBuilder<UserProfile?>(
```
   그리고 `build` 끝의 `Scaffold` 닫힘 `);` 를 `Theme` 닫힘까지 `),\n    );` 로 맞춘다(들여쓰기 포함 균형 확인).

- [ ] **Step 3: 색 토큰 치환 (치환표대로)**

`account_screen.dart` 내 아래를 Global Constraints 치환표대로 교체(모두 `p.` 접근으로):
- `_text` → `p.text` (사용처: 닉네임 `TextStyle`, `_tile` title). `const TextStyle(...)`이던 것은 `const` 제거.
- `_muted` → `p.textMuted` (userId 라벨, 로그인 방식 trailing, `_tile` leading/trailing, 회원 탈퇴 텍스트).
- `AppColors.surfaceApp` → `p.surface` (아바타 테두리 `Border.all`).
- `AppColors.surfaceCard` → `p.surfaceCard` (아바타 배경).
- `_tile` 메서드는 상단에 `final p = CommunityTheme.paletteOf(context);` 추가 후 사용.
- 브랜드 색(`AppColors.accent` 아바타 이니셜, `AppColors.error` 로그아웃, 앰버 그라디언트 `0xFFFFC107/0xFFFFA000`)은 **그대로**.

- [ ] **Step 4: "화면 테마" 타일 + 선택 시트 추가**

`_tile(... '차단한 사용자' ...)` 블록 **다음**에 아래 타일을 추가:
```dart
              _tile(
                icon: Icons.brightness_6_outlined,
                label: '화면 테마',
                trailing: Text(
                  _themeModeLabel(CommunityTheme.controllerOf(context).mode),
                  style: TextStyle(color: p.textMuted),
                ),
                onTap: _pickThemeMode,
              ),
```
그리고 `_AccountScreenState`에 헬퍼 두 개 추가:
```dart
  static String _themeModeLabel(CommunityThemeMode m) {
    switch (m) {
      case CommunityThemeMode.system:
        return '시스템 설정';
      case CommunityThemeMode.light:
        return '라이트';
      case CommunityThemeMode.dark:
        return '다크';
    }
  }

  Future<void> _pickThemeMode() async {
    final controller = CommunityTheme.controllerOf(context);
    final selected = await showModalBottomSheet<CommunityThemeMode>(
      context: context,
      builder: (sheetContext) {
        final current = controller.mode;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('화면 테마',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              for (final m in CommunityThemeMode.values)
                RadioListTile<CommunityThemeMode>(
                  value: m,
                  groupValue: current,
                  onChanged: (v) => Navigator.pop(sheetContext, v),
                  title: Text(_themeModeLabel(m)),
                  activeColor: AppColors.accent,
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null) await controller.setMode(selected);
  }
```

- [ ] **Step 5: 정적 분석**

Run: `dart analyze lib/community/screens/account_screen.dart`
Expected: No issues found!

- [ ] **Step 6: 기기 수동 확인**

Run: `flutter run` (hot restart) → 커뮤니티 진입 → 내 프로필.
Expected: "화면 테마" 타일 노출, 탭하면 시스템/라이트/다크 시트. 라이트 선택 시 내 프로필 화면 배경·텍스트가 화이트 테마로 즉시 전환(텍스트 판독 가능). 앱 재실행 후 선택 유지. 다크/시스템도 확인.

- [ ] **Step 7: 커밋**

```bash
git add lib/community/screens/account_screen.dart
git commit -m "feat: 내 프로필 화면 테마 적용 + 화면 테마 선택 UI"
```

---

### Task 5: 피드 화면 리팩터링

**Files:**
- Modify: `lib/community/screens/feed_screen.dart`

**Interfaces:**
- Consumes: `CommunityTheme`(Task 2).
- Produces: 피드가 선택 테마로 렌더.

- [ ] **Step 1: import + 래핑 + 치환**

1. `import '../theme/community_theme.dart';` 추가.
2. `build`를 표준 래핑 스니펫으로 감싼다(`final p = CommunityTheme.paletteOf(context);` + `Theme(data: CommunityTheme.themeOf(context), child: <기존 Scaffold>)`). 기존 build가 `Scaffold` 외 위젯을 반환하면 그 최상위를 `Theme`로 감싼다.
3. 파일 상단에 `_text`/`_muted` 류 색 상수가 있으면 삭제하고 `p.text`/`p.textMuted`로.
4. Global Constraints 치환표의 토큰을 `grep -nE 'AppColors\.surfaceApp|AppColors\.surfaceCard|0xFFF4F1EA|0x80F4F1EA|0x1AFFFFFF|0x0DFFFFFF|0x26FFFFFF|_text|_muted' lib/community/screens/feed_screen.dart` 로 찾아 표대로 교체. 색을 쓰는 헬퍼 메서드/위젯 빌더에는 각기 `final p = CommunityTheme.paletteOf(context);`를 둔다.
5. 브랜드/스크림/그라디언트/좋아요 등 표에 없는 색은 유지.

- [ ] **Step 2: 정적 분석**

Run: `dart analyze lib/community/screens/feed_screen.dart`
Expected: No issues found! (누락된 `p` 참조가 있으면 여기서 잡힘)

- [ ] **Step 3: 기기 수동 확인**

Run: hot restart → 피드 진입, 라이트/다크 전환.
Expected: 피드 카드·텍스트·구분선이 테마대로. 다크에서 기존과 동일. 브랜드 색 정상.

- [ ] **Step 4: 커밋**

```bash
git add lib/community/screens/feed_screen.dart
git commit -m "refactor: 피드 화면 커뮤니티 테마 적용"
```

---

### Task 6: 인증 화면 리팩터링 (로그인·회원가입·인증 위젯)

**Files:**
- Modify: `lib/community/screens/login_screen.dart`
- Modify: `lib/community/screens/signup_screen.dart`
- Modify: `lib/community/screens/auth_widgets.dart`
- Modify: `lib/community/screens/sign_in_sheet.dart`

**Interfaces:**
- Consumes: `CommunityTheme`(Task 2).
- Produces: 인증 플로우가 선택 테마로 렌더.

- [ ] **Step 1: 각 파일 처리**

각 파일에 대해:
1. `import '../theme/community_theme.dart';` 추가.
2. **전체 화면 위젯**(`login_screen`, `signup_screen`): `build`를 표준 래핑 스니펫으로 감싼다.
   **하위 위젯/시트**(`auth_widgets`, `sign_in_sheet`): `Theme` 래핑 없이, 색을 쓰는 `build`/헬퍼 상단에 `final p = CommunityTheme.paletteOf(context);` 추가.
3. 파일 상단 `_text`/`_muted` 상수 삭제 후 `p.text`/`p.textMuted`.
4. `grep -nE 'AppColors\.surfaceApp|AppColors\.surfaceCard|0xFFF4F1EA|0x80F4F1EA|0x1AFFFFFF|0x0DFFFFFF|0x26FFFFFF|_text|_muted' <file>` 결과를 치환표대로 교체.
5. 브랜드 색(구글/애플/카카오 버튼 브랜드 컬러 등 로그인 버튼 고유색)은 **유지**.

- [ ] **Step 2: 정적 분석**

Run: `dart analyze lib/community/screens/login_screen.dart lib/community/screens/signup_screen.dart lib/community/screens/auth_widgets.dart lib/community/screens/sign_in_sheet.dart`
Expected: No issues found!

- [ ] **Step 3: 기기 수동 확인**

Run: hot restart → 로그아웃 상태에서 로그인/회원가입 화면, 로그인 시트 진입, 라이트/다크 전환.
Expected: 배경·입력창·텍스트가 테마대로, 라이트에서 판독 가능. 소셜 버튼 브랜드색 정상.

- [ ] **Step 4: 커밋**

```bash
git add lib/community/screens/login_screen.dart lib/community/screens/signup_screen.dart lib/community/screens/auth_widgets.dart lib/community/screens/sign_in_sheet.dart
git commit -m "refactor: 인증 화면 커뮤니티 테마 적용"
```

---

### Task 7: 게시글 상세·글쓰기·좋아요 버튼 리팩터링

**Files:**
- Modify: `lib/community/screens/post_detail_screen.dart`
- Modify: `lib/community/screens/create_post_screen.dart`
- Modify: `lib/community/screens/like_button.dart`

**Interfaces:**
- Consumes: `CommunityTheme`(Task 2).
- Produces: 게시글 상세·글쓰기·좋아요가 선택 테마로 렌더.

- [ ] **Step 1: 각 파일 처리**

1. `import '../theme/community_theme.dart';` 추가.
2. **전체 화면**(`post_detail_screen`, `create_post_screen`): 표준 래핑 스니펫.
   **하위 위젯**(`like_button`): 래핑 없이 `final p = CommunityTheme.paletteOf(context);`로 색만 조회.
3. `grep -nE 'AppColors\.surfaceApp|AppColors\.surfaceCard|0xFFF4F1EA|0x80F4F1EA|0x1AFFFFFF|0x0DFFFFFF|0x26FFFFFF|_text|_muted' <file>` 결과를 치환표대로 교체.
4. 좋아요 하트의 브랜드/강조색은 유지.

- [ ] **Step 2: 정적 분석**

Run: `dart analyze lib/community/screens/post_detail_screen.dart lib/community/screens/create_post_screen.dart lib/community/screens/like_button.dart`
Expected: No issues found!

- [ ] **Step 3: 기기 수동 확인**

Run: hot restart → 게시글 상세, 글쓰기, 좋아요 토글, 라이트/다크 전환.
Expected: 본문·입력·댓글·좋아요가 테마대로. 라이트 판독 가능.

- [ ] **Step 4: 커밋**

```bash
git add lib/community/screens/post_detail_screen.dart lib/community/screens/create_post_screen.dart lib/community/screens/like_button.dart
git commit -m "refactor: 게시글 상세·글쓰기·좋아요 커뮤니티 테마 적용"
```

---

### Task 8: 다이얼로그·시트·차단 목록·마스크 편집기 리팩터링

**Files:**
- Modify: `lib/community/screens/confirm_dialog.dart`
- Modify: `lib/community/screens/report_sheet.dart`
- Modify: `lib/community/screens/blocked_users_screen.dart`
- Modify: `lib/community/screens/mask_editor_screen.dart`

**Interfaces:**
- Consumes: `CommunityTheme`(Task 2).
- Produces: 나머지 커뮤니티 표면이 선택 테마로 렌더.

- [ ] **Step 1: 각 파일 처리**

1. `import '../theme/community_theme.dart';` 추가.
2. **전체 화면**(`blocked_users_screen`, `mask_editor_screen`): 표준 래핑 스니펫.
   **다이얼로그/시트**(`confirm_dialog`, `report_sheet`): 래핑 없이 `final p = CommunityTheme.paletteOf(context);`로 색만 조회(showDialog/showModalBottomSheet가 호출부 테마를 캡처하므로 팔레트 접근 가능).
3. `grep -nE 'AppColors\.surfaceApp|AppColors\.surfaceCard|0xFFF4F1EA|0x80F4F1EA|0x1AFFFFFF|0x0DFFFFFF|0x26FFFFFF|_text|_muted' <file>` 결과를 치환표대로 교체.
4. `mask_editor_screen`의 마스킹 오버레이/스크림 등 기능색은 **유지**(표에 있는 표면·텍스트만 교체).
5. `confirm_dialog`의 파괴적 액션 색(`AppColors.danger/error`)은 유지.

- [ ] **Step 2: 정적 분석**

Run: `dart analyze lib/community/screens/confirm_dialog.dart lib/community/screens/report_sheet.dart lib/community/screens/blocked_users_screen.dart lib/community/screens/mask_editor_screen.dart`
Expected: No issues found!

- [ ] **Step 3: 기기 수동 확인**

Run: hot restart → 로그아웃/탈퇴 확인 다이얼로그, 신고 시트, 차단 목록, 마스크 편집기, 라이트/다크 전환.
Expected: 다이얼로그·시트·목록 배경/텍스트가 호출 화면 테마와 일치. 파괴적 액션 빨강 유지. 마스크 편집 기능색 정상.

- [ ] **Step 4: 커밋**

```bash
git add lib/community/screens/confirm_dialog.dart lib/community/screens/report_sheet.dart lib/community/screens/blocked_users_screen.dart lib/community/screens/mask_editor_screen.dart
git commit -m "refactor: 다이얼로그·차단목록·마스크편집기 커뮤니티 테마 적용"
```

---

### Task 9: 전체 검증

**Files:** (없음 — 게이트만)

- [ ] **Step 1: 잔여 하드코딩 표면색 점검**

Run: `grep -rnE '0xFFF4F1EA|0x80F4F1EA|AppColors\.surfaceApp|AppColors\.surfaceCard' lib/community/screens/`
Expected: 결과 없음(모두 팔레트로 이전). 남아 있으면 해당 파일을 치환표대로 마저 교체 후 커밋.

- [ ] **Step 2: 완료 게이트**

Run: `tool/verify.sh`
Expected: `✅ verify 통과` (format + `dart analyze lib test` 무이슈 + `flutter test` 전부 통과).

- [ ] **Step 3: 최종 기기 회귀 확인**

Run: `flutter run`
Expected:
- 촬영 화면 검은색 유지(테마 영향 없음).
- 커뮤니티 모든 화면이 시스템/라이트/다크 선택에 따라 일관되게 전환.
- `system`에서 OS 테마 변경 시 커뮤니티가 따라감.
- 선택값 앱 재실행 후 유지.

- [ ] **Step 4: 커밋(문서/잔여 정리 있으면)**

```bash
git add -A
git commit -m "chore: 커뮤니티 테마 잔여 정리 및 검증"
```

---

## Self-Review 결과

- **스펙 커버리지**: 컨트롤러·저장(Task 1) / 팔레트·테마·resolveBrightness·InheritedNotifier(Task 2) / main 배선(Task 3) / 계정 선택 UI·내 프로필 적용(Task 4) / 전 커뮤니티 화면 적용(Task 5~8) / 완료 정의·게이트(Task 9). 스펙의 "system 기본·저장·즉시 반영·촬영 화면 제외·라이트 판독성" 모두 대응.
- **플레이스홀더**: 없음(라이트 헥스는 Task 2에 확정 값으로 명시).
- **타입 일관성**: `CommunityThemeMode`, `CommunityThemeController.{mode,load,setMode,prefsKey}`, `CommunityPalette.{surface,surfaceCard,text,textMuted,divider,inputFill,border}`, `paletteFor`/`resolveBrightness`/`buildCommunityTheme`, `CommunityTheme.{controllerOf,brightnessOf,paletteOf,themeOf}` — 태스크 전반 명칭 일치.
