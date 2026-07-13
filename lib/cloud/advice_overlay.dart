// lib/cloud/advice_overlay.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'composition_advice.dart';

/// 클라우드 구도 추천 카드(축소판) — headline + rationale만 표시.
class AdviceOverlay extends StatelessWidget {
  final CompositionAdvice advice;
  final VoidCallback onClose;
  const AdviceOverlay({super.key, required this.advice, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 170,
      child: Material(
        color: AppColors.scrimAdvice,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.star,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      advice.headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),
              if (advice.rationale.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    advice.rationale,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
