import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/person_box.dart';
import '../theme/app_colors.dart';
import 'composition_advice.dart';
import 'target_alignment.dart';

/// 프레임 대비 현재 인물→목표 위치를 작은 개요도로 보여준다.
class AdviceMinimap extends StatelessWidget {
  final TargetBox target;
  final PersonBox? current;
  final AlignmentResult? alignment;
  const AdviceMinimap({
    super.key,
    required this.target,
    this.current,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(6),
      child: CustomPaint(
        painter: _MinimapPainter(target, current, alignment),
        size: Size.infinite,
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final TargetBox target;
  final PersonBox? current;
  final AlignmentResult? alignment;
  _MinimapPainter(this.target, this.current, this.alignment);

  // 정렬 완료=그린, 미정렬=앰버. 현재 인물 박스는 회색.
  static final _good = AppColors.ready.withValues(alpha: 0.93);
  static final _pending = AppColors.accent.withValues(alpha: 0.93);
  static final _goodFill = AppColors.ready.withValues(alpha: 0.33);
  static const _grey = Color(0xBBBBBBBB);

  @override
  void paint(Canvas canvas, Size size) {
    // 프레임 테두리
    final frame = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x88FFFFFF),
    );

    final aligned = alignment?.aligned ?? false;
    final line = aligned ? _good : _pending;

    // 목표 박스
    final t = Rect.fromLTWH(
      target.x * size.width,
      target.y * size.height,
      target.width * size.width,
      target.height * size.height,
    );
    if (aligned) canvas.drawRect(t, Paint()..color = _goodFill);
    canvas.drawRect(
      t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = line,
    );

    // 현재 인물 + 화살표
    final cur = current;
    if (cur != null) {
      final c = Rect.fromLTWH(
        cur.left * size.width,
        cur.top * size.height,
        cur.width * size.width,
        cur.height * size.height,
      );
      canvas.drawRect(
        c,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _grey,
      );
      if (!aligned) {
        final from = Offset(
          cur.centerX * size.width,
          cur.centerY * size.height,
        );
        final to = Offset(
          target.centerX * size.width,
          target.centerY * size.height,
        );
        final p = Paint()
          ..color = line
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, p);
        final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
        const head = 7.0;
        canvas.drawLine(
          to,
          to +
              Offset(
                math.cos(angle + math.pi - 0.4) * head,
                math.sin(angle + math.pi - 0.4) * head,
              ),
          p,
        );
        canvas.drawLine(
          to,
          to +
              Offset(
                math.cos(angle + math.pi + 0.4) * head,
                math.sin(angle + math.pi + 0.4) * head,
              ),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter old) =>
      old.target != target ||
      old.current != current ||
      old.alignment != alignment;
}
