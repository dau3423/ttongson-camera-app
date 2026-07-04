import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/person_box.dart';
import 'composition_advice.dart';
import 'target_alignment.dart';

/// 목표 고스트 박스 + 현재→목표 이동 화살표. 판단 없음(값을 그대로 시각화).
class TargetGuideOverlay extends StatelessWidget {
  final TargetBox target;
  final PersonBox? current;
  final AlignmentResult? alignment;
  const TargetGuideOverlay({
    super.key,
    required this.target,
    this.current,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TargetGuidePainter(target, current, alignment),
      size: Size.infinite,
    );
  }
}

class _TargetGuidePainter extends CustomPainter {
  final TargetBox target;
  final PersonBox? current;
  final AlignmentResult? alignment;
  _TargetGuidePainter(this.target, this.current, this.alignment);

  static const _good = Color(0xEE69F0AE);
  static const _warn = Color(0xEEFF5252);
  static const _goodFill = Color(0x2669F0AE);
  static const _warnFill = Color(0x26FF5252);

  @override
  void paint(Canvas canvas, Size size) {
    final aligned = alignment?.aligned ?? false;
    final line = aligned ? _good : _warn;
    final fill = aligned ? _goodFill : _warnFill;

    final rect = Rect.fromLTWH(
      target.x * size.width,
      target.y * size.height,
      target.width * size.width,
      target.height * size.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = line,
    );

    final cur = current;
    if (cur != null && !aligned) {
      final from = Offset(cur.centerX * size.width, cur.centerY * size.height);
      final to = Offset(
        target.centerX * size.width,
        target.centerY * size.height,
      );
      _drawArrow(canvas, from, to, line);
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, p);
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const head = 20.0;
    final a1 = angle + math.pi - 0.4;
    final a2 = angle + math.pi + 0.4;
    canvas.drawLine(
      to,
      to + Offset(math.cos(a1) * head, math.sin(a1) * head),
      p,
    );
    canvas.drawLine(
      to,
      to + Offset(math.cos(a2) * head, math.sin(a2) * head),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _TargetGuidePainter old) =>
      old.target != target ||
      old.current != current ||
      old.alignment != alignment;
}
