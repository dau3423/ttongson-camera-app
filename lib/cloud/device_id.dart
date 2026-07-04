// lib/cloud/device_id.dart
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// 기기별 안정 식별자(레이트리밋 키). 최초 1회 생성해 SharedPreferences에 보관.
/// 계정/인증이 아니며 프라이버시 목적으로만 사용(개인정보 아님).
class DeviceId {
  static const _key = 'device_id';

  Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _randomId();
    await prefs.setString(_key, id);
    return id;
  }

  String _randomId() {
    // dart:math Random.secure 기반 16바이트 hex (UUID 형식 불필요, 충돌만 회피).
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
