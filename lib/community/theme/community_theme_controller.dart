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
