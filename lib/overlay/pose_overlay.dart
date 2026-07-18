import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 선택 포즈 실루엣을 프리뷰 위에 앰버 틴트·반투명으로 얹는다(가이드 전용, 터치 통과).
class PoseOverlay extends StatelessWidget {
  final String asset;
  const PoseOverlay({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.35,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            color: AppColors.accent,
            colorBlendMode: BlendMode.srcIn,
            // 에셋이 아직 없으면(사용자 미생성) 조용히 숨김.
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
