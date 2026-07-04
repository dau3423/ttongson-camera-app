// lib/cloud/advice_consent.dart
import 'package:shared_preferences/shared_preferences.dart';

/// 클라우드 구도 추천(프레임 전송) 동의 여부를 저장.
class AdviceConsentStore {
  static const _key = 'cloud_advice_consented';

  Future<bool> hasConsented() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setConsented() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
