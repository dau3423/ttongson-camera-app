import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../auth_service.dart';

/// 로그인 유도 바텀시트. 로그인 성공 시 true 반환.
Future<bool> showSignInSheet(BuildContext context, AuthService auth) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SignInSheet(auth: auth),
  );
  return ok ?? false;
}

class _SignInSheet extends StatefulWidget {
  final AuthService auth;
  const _SignInSheet({required this.auth});
  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() signIn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final user = await signIn();
      if (mounted) Navigator.pop(context, user != null);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 드래그 핸들
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // 앱 아이콘
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('📸', style: TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 16),
              const Text(
                '똥손카메라 로그인',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '구도 추천과 커뮤니티를 이용하려면\n로그인이 필요해요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              _ProviderButton(
                label: 'Google로 계속하기',
                icon: Icons.g_mobiledata,
                iconColor: const Color(0xFFEA4335), // Google 레드
                background: Colors.white,
                foreground: Colors.black87,
                bordered: true,
                onTap: _busy ? null : () => _run(widget.auth.signInWithGoogle),
              ),
              // Apple 로그인은 애플 기기에서만 노출.
              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                _ProviderButton(
                  label: 'Apple로 계속하기',
                  icon: Icons.apple,
                  background: Colors.black,
                  foreground: Colors.white,
                  bordered: false,
                  onTap: _busy ? null : () => _run(widget.auth.signInWithApple),
                ),
              ],
              SizedBox(
                height: 28,
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool bordered;
  final Color? iconColor;
  final VoidCallback? onTap;
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.bordered,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: bordered
                ? const BorderSide(color: Colors.black12)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
