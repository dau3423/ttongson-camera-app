import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

const _text = Color(0xFFF4F1EA);

/// 로그인/회원가입 공용 배경 — 상단 라디얼 그라디언트.
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.1,
          colors: [Color(0xFF1C2026), AppColors.surfaceApp],
        ),
      ),
      child: child,
    );
  }
}

/// 필드 위 앰버 라벨(모노 느낌, 자간 넓게).
class AuthLabel extends StatelessWidget {
  final String text;
  const AuthLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          letterSpacing: 1,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 다크 입력 필드. [trailing]로 비밀번호 표시 토글 등을 얹는다.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: _text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        suffixIcon: trailing,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
      ),
    );
  }
}

/// 앰버 배경 · 검정 글씨 CTA 버튼.
class AmberButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const AmberButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.surfaceApp,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// 아웃라인 소셜 버튼(Apple/카카오).
class AuthOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _text,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: Color(0x26FFFFFF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// 로그인/가입 성공 전체 오버레이(원형 아이콘 + 문구 + CTA).
class AuthSuccessOverlay extends StatelessWidget {
  final Color circleColor;
  final String emoji;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onCta;
  const AuthSuccessOverlay({
    super.key,
    required this.circleColor,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xF50B0C0E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 38)),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: const TextStyle(
                  color: _text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0x8CF4F1EA), fontSize: 14),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.surfaceApp,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 13,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  cta,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
