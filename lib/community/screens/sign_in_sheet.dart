import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'login_screen.dart';

/// 로그인 게이트. 로그인/가입 성공 시 true 반환.
/// (기존 바텀시트 → 다크 디자인 전체화면 LoginScreen으로 대체. 호출부 계약 유지.)
Future<bool> showSignInSheet(BuildContext context, AuthService auth) async {
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LoginScreen(auth: auth),
    ),
  );
  return ok ?? false;
}
