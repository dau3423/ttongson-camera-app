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
    final w = context.dependOnInheritedWidgetOfExactType<CommunityTheme>();
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
