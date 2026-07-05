import 'package:shared_preferences/shared_preferences.dart';
import '../models/shooting_mode.dart';

/// 선택한 촬영 모드를 로컬에 저장/복원한다(판단 없음).
class ModeStore {
  static const _key = 'shooting_mode';

  Future<ShootingMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ShootingModeWire.fromWire(prefs.getString(_key)) ??
        ShootingMode.person;
  }

  Future<void> save(ShootingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.wire);
  }
}
