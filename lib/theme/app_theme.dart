import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 앱 전역 다크 테마. 커뮤니티/인증 화면이 이 표면·강조색을 상속한다.
/// (촬영 화면은 자체 검은 배경으로 별도 구성)
ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Color(0xFF0B0C0E),
    secondary: AppColors.accent,
    surface: AppColors.surfaceApp,
    onSurface: Color(0xFFF4F1EA),
    error: AppColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppFonts.body,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surfaceApp,
    canvasColor: AppColors.surfaceApp,
    dividerColor: const Color(0x1AFFFFFF),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceApp,
      foregroundColor: Color(0xFFF4F1EA),
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFFF4F1EA),
      contentTextStyle: TextStyle(color: Color(0xFF0B0C0E)),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: Color(0x55FFC107),
      selectionHandleColor: AppColors.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x0DFFFFFF),
      hintStyle: const TextStyle(color: Color(0x66F4F1EA)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x26FFFFFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x26FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
  );
}
