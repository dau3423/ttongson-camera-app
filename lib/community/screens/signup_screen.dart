import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../auth_service.dart';
import '../models/user_profile.dart';
import 'auth_widgets.dart';

const _text = Color(0xFFF4F1EA);
const _muted = Color(0x80F4F1EA);

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
    final nick = _nick.text.trim();
    final email = _email.text.trim();
    final pw = _pw.text;
    if (nick.isEmpty || email.isEmpty || pw.isEmpty) {
      setState(() => _err = '모든 항목을 입력해주세요.');
      return;
    }
    if (!isValidNickname(nick)) {
      setState(() => _err = '닉네임은 1~20자로 입력해주세요.');
      return;
    }
    if (!isValidEmail(email)) {
      setState(() => _err = '올바른 이메일 형식이 아니에요.');
      return;
    }
    if (!isValidPassword(pw)) {
      setState(() => _err = '비밀번호는 8자 이상이어야 해요.');
      return;
    }
    if (!_agree) {
      setState(() => _err = '약관에 동의해주세요.');
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
          _err = '가입에 실패했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  String _signupErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '이미 가입된 이메일이에요. 로그인해 주세요.';
      case 'invalid-email':
        return '올바른 이메일 형식이 아니에요.';
      case 'weak-password':
        return '비밀번호가 너무 약해요. 8자 이상으로 해주세요.';
      default:
        return '가입에 실패했어요. 다시 시도해 주세요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: AuthBackground(
        child: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(30, 40, 30, 40),
                children: [
                  const Text(
                    '가입하기',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      color: _text,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '30초면 충분해요',
                    style: TextStyle(color: _muted, fontSize: 14),
                  ),
                  const SizedBox(height: 30),
                  const AuthLabel('닉네임'),
                  AuthField(controller: _nick, hint: '똥손탈출러'),
                  const SizedBox(height: 16),
                  const AuthLabel('이메일'),
                  AuthField(
                    controller: _email,
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  const AuthLabel('비밀번호'),
                  AuthField(controller: _pw, hint: '8자 이상', obscure: true),
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
                    label: '가입하고 시작하기',
                    onTap: _busy ? null : _signup,
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: GestureDetector(
                      onTap: _busy ? null : () => Navigator.pop(context),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: Color(0x8CF4F1EA),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(text: '이미 계정이 있으신가요? '),
                            TextSpan(
                              text: '로그인',
                              style: TextStyle(
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
                  title: '가입 완료!',
                  subtitle: '이제 촬영을 시작해볼까요?',
                  cta: '촬영하러 가기',
                  onCta: () => Navigator.pop(context, true),
                ),
              ),
          ],
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
                color: checked ? AppColors.accent : const Color(0x4DFFFFFF),
                width: 1.5,
              ),
            ),
            child: checked
                ? const Icon(Icons.check, size: 15, color: AppColors.surfaceApp)
                : null,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '이용약관 및 개인정보 처리방침에 동의합니다',
              style: TextStyle(color: Color(0xB3F4F1EA), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
