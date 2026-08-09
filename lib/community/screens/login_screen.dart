import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:ttongson_camera/l10n/app_localizations.dart';
import '../auth_service.dart';
import '../models/user_profile.dart';
import '../theme/community_theme.dart';
import 'auth_widgets.dart';
import 'signup_screen.dart';

/// 이메일/소셜 로그인 화면. 로그인 성공 시 pop(true).
class LoginScreen extends StatefulWidget {
  final AuthService auth;
  const LoginScreen({super.key, required this.auth});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _showPw = false;
  bool _busy = false;
  String? _err;
  bool _done = false;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _emailLogin() async {
    final email = _email.text.trim();
    final pw = _pw.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _err = AppLocalizations.of(context)!.authEmailEmpty);
      return;
    }
    if (!isValidEmail(email)) {
      setState(() => _err = AppLocalizations.of(context)!.authInvalidEmail);
      return;
    }
    await _run(
      () => widget.auth.signInWithEmail(email: email, password: pw),
      emailFlow: true,
    );
  }

  /// 공통 로그인 실행: 취소(null)·탈퇴 계정·성공을 처리한다.
  Future<void> _run(
    Future<User?> Function() signIn, {
    bool emailFlow = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final user = await signIn();
      if (user == null) {
        if (mounted) setState(() => _busy = false);
        return; // 사용자 취소
      }
      final profile = await widget.auth.myProfile();
      if (!mounted) return;
      if (profile?.isWithdrawn ?? false) {
        final rejoin = await _confirmRejoin();
        if (!mounted) return;
        if (rejoin == true) {
          await widget.auth.rejoin();
        } else {
          await widget.auth.signOut();
          if (mounted) setState(() => _busy = false);
          return;
        }
      }
      if (mounted) setState(() => _done = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = emailFlow
              ? _emailErrorMessage(e.code)
              : AppLocalizations.of(context)!.authLoginFailed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = AppLocalizations.of(context)!.authLoginFailedRetry;
        });
      }
    }
  }

  String _emailErrorMessage(String code) {
    final l = AppLocalizations.of(context)!;
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return l.authWrongCredential;
      case 'invalid-email':
        return l.authInvalidEmail;
      case 'user-disabled':
        return l.authAccountDisabled;
      default:
        return l.authLoginFailedRetry;
    }
  }

  Future<bool?> _confirmRejoin() {
    final l = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.authWithdrawnTitle),
        content: Text(l.authWithdrawnBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.authRejoin),
          ),
        ],
      ),
    );
  }

  Future<void> _goSignup() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SignupScreen(auth: widget.auth)),
    );
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    final l = AppLocalizations.of(context)!;
    return Theme(
      data: CommunityTheme.themeOf(context),
      child: Scaffold(
        body: AuthBackground(
          child: Stack(
            children: [
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(30, 56, 30, 40),
                  children: [
                    Text(
                      l.authWelcomeBack,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        color: p.text,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.authLoginSubtitle,
                      style: TextStyle(color: p.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 36),
                    AuthLabel(l.authEmailLabel),
                    AuthField(
                      controller: _email,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    AuthLabel(l.authPasswordLabel),
                    AuthField(
                      controller: _pw,
                      hint: '••••••••',
                      obscure: !_showPw,
                      trailing: IconButton(
                        icon: Icon(
                          _showPw ? Icons.visibility : Icons.visibility_off,
                          color: p.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _showPw = !_showPw),
                      ),
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _err!,
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    AmberButton(
                      label: l.authLoginButton,
                      onTap: _busy ? null : _emailLogin,
                    ),
                    const SizedBox(height: 26),
                    _OrDivider(),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        if (Platform.isIOS) ...[
                          AuthOutlineButton(
                            label: 'Apple',
                            onTap: _busy
                                ? null
                                : () => _run(widget.auth.signInWithApple),
                          ),
                          const SizedBox(width: 10),
                        ],
                        AuthOutlineButton(
                          label: l.authKakao,
                          onTap: _busy
                              ? null
                              : () => _run(widget.auth.signInWithKakao),
                        ),
                        const SizedBox(width: 10),
                        AuthOutlineButton(
                          label: 'Google',
                          onTap: _busy
                              ? null
                              : () => _run(widget.auth.signInWithGoogle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: GestureDetector(
                        onTap: _busy ? null : _goSignup,
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: p.textMuted, fontSize: 14),
                            children: [
                              TextSpan(text: l.authNoAccount),
                              TextSpan(
                                text: l.authSignupLink,
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (_done)
                Positioned.fill(
                  child: AuthSuccessOverlay(
                    circleColor: AppColors.accent,
                    emoji: '📷',
                    title: l.authLoginSuccess,
                    subtitle: l.authLoginSuccessSubtitle,
                    cta: l.authLoginSuccessCta,
                    onCta: () => Navigator.pop(context, true),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(child: Divider(color: p.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            l.authOrDivider,
            style: TextStyle(color: p.textMuted, fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: p.divider)),
      ],
    );
  }
}
