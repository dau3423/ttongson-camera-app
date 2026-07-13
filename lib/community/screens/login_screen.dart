import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../auth_service.dart';
import '../models/user_profile.dart';
import 'auth_widgets.dart';
import 'signup_screen.dart';

const _text = Color(0xFFF4F1EA);
const _muted = Color(0x80F4F1EA);

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
      setState(() => _err = '이메일과 비밀번호를 입력해주세요.');
      return;
    }
    if (!isValidEmail(email)) {
      setState(() => _err = '올바른 이메일 형식이 아니에요.');
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
          _err = emailFlow ? _emailErrorMessage(e.code) : '로그인에 실패했어요.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = '로그인에 실패했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  String _emailErrorMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return '이메일 또는 비밀번호가 올바르지 않아요.';
      case 'invalid-email':
        return '올바른 이메일 형식이 아니에요.';
      case 'user-disabled':
        return '사용할 수 없는 계정이에요.';
      default:
        return '로그인에 실패했어요. 다시 시도해 주세요.';
    }
  }

  Future<bool?> _confirmRejoin() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('탈퇴한 계정이에요'),
        content: const Text('이 계정은 탈퇴 처리됐어요. 다시 가입할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('재가입'),
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
    return Scaffold(
      body: AuthBackground(
        child: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(30, 56, 30, 40),
                children: [
                  const Text(
                    '다시 오셨네요',
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
                    '똥손도 프로처럼 · 로그인하고 이어서 찍기',
                    style: TextStyle(color: _muted, fontSize: 14),
                  ),
                  const SizedBox(height: 36),
                  const AuthLabel('이메일'),
                  AuthField(
                    controller: _email,
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 18),
                  const AuthLabel('비밀번호'),
                  AuthField(
                    controller: _pw,
                    hint: '••••••••',
                    obscure: !_showPw,
                    trailing: IconButton(
                      icon: Icon(
                        _showPw ? Icons.visibility : Icons.visibility_off,
                        color: _muted,
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
                  AmberButton(label: '로그인', onTap: _busy ? null : _emailLogin),
                  const SizedBox(height: 26),
                  const _OrDivider(),
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
                        label: '카카오',
                        onTap: _busy
                            ? null
                            : () => _run(widget.auth.signInWithKakao),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: GestureDetector(
                      onTap: _busy ? null : _goSignup,
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: Color(0x8CF4F1EA),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(text: '아직 계정이 없으신가요? '),
                            TextSpan(
                              text: '회원가입',
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
                  circleColor: AppColors.accent,
                  emoji: '📷',
                  title: '환영합니다!',
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0x1AFFFFFF))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는',
            style: TextStyle(color: Color(0x66F4F1EA), fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: Color(0x1AFFFFFF))),
      ],
    );
  }
}
