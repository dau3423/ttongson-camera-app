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
