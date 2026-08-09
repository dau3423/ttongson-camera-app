import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../auth_service.dart';
import '../models/user_profile.dart';
import '../theme/community_theme.dart';
import 'auth_widgets.dart';

/// 이메일 회원가입 화면. 가입 성공 시 pop(true).
class SignupScreen extends StatefulWidget {
  final AuthService auth;
  const SignupScreen({super.key, required this.auth});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nick = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _agree = false;
  bool _busy = false;
  String? _err;
  bool _done = false;

  @override
  void dispose() {
    _nick.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_busy) return;
    final l = AppLocalizations.of(context)!;
    final nick = _nick.text.trim();
    final email = _email.text.trim();
    final pw = _pw.text;
    if (nick.isEmpty || email.isEmpty || pw.isEmpty) {
      setState(() => _err = l.authAllFieldsRequired);
      return;
    }
    if (!isValidNickname(nick)) {
      setState(() => _err = l.authNicknameInvalid);
      return;
    }
    if (!isValidEmail(email)) {
      setState(() => _err = l.authInvalidEmail);
      return;
    }
    if (!isValidPassword(pw)) {
      setState(() => _err = l.authWeakPassword);
      return;
    }
    if (!_agree) {
      setState(() => _err = l.authAgreeRequired);
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await widget.auth.signUpWithEmail(
        email: email,
        password: pw,
        nickname: nick,
      );
      if (mounted) setState(() => _done = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = _signupErrorMessage(e.code);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = l.authSignupFailed;
        });
      }
    }
  }

  String _signupErrorMessage(String code) {
    final l = AppLocalizations.of(context)!;
    switch (code) {
      case 'email-already-in-use':
        return l.authEmailInUse;
      case 'invalid-email':
        return l.authInvalidEmail;
      case 'weak-password':
        return l.authWeakPasswordServer;
      default:
        return l.authSignupFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    final l = AppLocalizations.of(context)!;
    return Theme(
      data: CommunityTheme.themeOf(context),
      child: Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        extendBodyBehindAppBar: true,
        body: AuthBackground(
          child: Stack(
            children: [
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(30, 40, 30, 40),
                  children: [
                    Text(
                      l.authSignupTitle,
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
                      l.authSignupSubtitle,
                      style: TextStyle(color: p.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    AuthLabel(l.authNicknameLabel),
                    AuthField(controller: _nick, hint: l.authNicknameHint),
                    const SizedBox(height: 16),
                    AuthLabel(l.authEmailLabel),
                    AuthField(
                      controller: _email,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    AuthLabel(l.authPasswordLabel),
                    AuthField(
                      controller: _pw,
                      hint: l.authPasswordHint,
                      obscure: true,
                    ),
                    const SizedBox(height: 20),
                    _AgreeRow(
                      checked: _agree,
                      onTap: () => setState(() => _agree = !_agree),
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
                    const SizedBox(height: 14),
                    AmberButton(
                      label: l.authSignupButton,
                      onTap: _busy ? null : _signup,
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: GestureDetector(
                        onTap: _busy ? null : () => Navigator.pop(context),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: p.textMuted, fontSize: 14),
                            children: [
                              TextSpan(text: l.authHaveAccount),
                              TextSpan(
                                text: l.authSigninLink,
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
                    circleColor: AppColors.ready,
                    emoji: '🎉',
                    title: l.authSignupSuccess,
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

class _AgreeRow extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  const _AgreeRow({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: checked ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: checked ? AppColors.accent : p.border,
                width: 1.5,
              ),
            ),
            child: checked
                ? const Icon(Icons.check, size: 15, color: AppColors.surfaceApp)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.authAgreeTerms,
              style: TextStyle(
                color: p.text.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
