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
