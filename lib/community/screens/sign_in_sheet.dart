import 'package:flutter/material.dart';
import '../auth_service.dart';

/// 로그인 유도 바텀시트. 로그인 성공 시 true 반환.
Future<bool> showSignInSheet(BuildContext context, AuthService auth) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '로그인이 필요해요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('구도 추천과 커뮤니티는 로그인 후 이용할 수 있어요.'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Google로 계속하기'),
              onPressed: () async {
                final user = await auth.signInWithGoogle();
                if (ctx.mounted) Navigator.pop(ctx, user != null);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.apple),
              label: const Text('Apple로 계속하기'),
              onPressed: () async {
                final user = await auth.signInWithApple();
                if (ctx.mounted) Navigator.pop(ctx, user != null);
              },
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
