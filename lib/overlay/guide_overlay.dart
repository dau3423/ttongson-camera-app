import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analysis/guide_metrics.dart';
import '../analysis/guide_step.dart';
import '../analysis/thirds.dart';

class GuideOverlay extends StatelessWidget {
  final GuideMetrics metrics;
  final GuideStep step;
  final bool showGrid;
  const GuideOverlay({
    super.key,
    required this.metrics,
    required this.step,
    this.showGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GuidePainter(metrics: metrics, step: step, showGrid: showGrid),
      size: Size.infinite,
    );
  }
}

class GuidePainter extends CustomPainter {
  final GuideMetrics metrics;
  final GuideStep step;
  final bool showGrid;
  GuidePainter({
    required this.metrics,
    required this.step,
    required this.showGrid,
  });

  static const _good = Color(0xAA69F0AE); // 초록
  static const _warn = Color(0xAAFF5252); // 빨강
  static const _amber = Color(0xEEFFC107); // 목표 안내
  static const _neutral = Color(0x88FFFFFF);
  static const _marker = Color(0xEEFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) _paintGrid(canvas, size);
    _paintLevel(canvas, size);
    _paintPerson(canvas, size);
    if (step.kind == GuideStepKind.position && step.target != null) {
      _paintPosition(canvas, size, step.target!);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _neutral
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), p);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), p);
    }
  }

  void _paintLevel(Canvas canvas, Size size) {
    final level = metrics.tilt.isLevel;
    final p = Paint()
      ..color = level ? _good : _warn
      ..strokeWidth = 3;
    final cy = size.height / 2;
    final cx = size.width / 2;
    final rad = metrics.tilt.rollDegrees * math.pi / 180;
    final half = size.width * 0.15;
    final dxr = half * math.cos(rad);
    final dyr = half * math.sin(rad);
    canvas.drawLine(Offset(cx - dxr, cy - dyr), Offset(cx + dxr, cy + dyr), p);
  }

  void _paintPerson(Canvas canvas, Size size) {
    final person = metrics.person;
    if (person == null) return;
    // 잘림 단계면 빨강, 모두 통과(ready)면 초록, 그 외 중립.
    final color = step.kind == GuideStepKind.crop
        ? _warn
        : step.kind == GuideStepKind.ready
        ? _good
        : _neutral;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = step.kind == GuideStepKind.ready ? 3 : 2
      ..color = color;
    canvas.drawRect(
      Rect.fromLTWH(
        person.left * size.width,
        person.top * size.height,
        person.width * size.width,
        person.height * size.height,
      ),
      p,
    );
  }

  void _paintPosition(Canvas canvas, Size size, ThirdsAlignment t) {
    final aligned = t.hint == '좋아요';
    final tgt = Offset(t.targetX * size.width, t.targetY * size.height);
    final color = aligned ? _good : _amber;
    // 목표 링 + 중앙 점
    canvas.drawCircle(
      tgt,
      aligned ? 22 : 16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
    canvas.drawCircle(tgt, 4, Paint()..color = color);
    if (aligned) return;
    // 현재 마커 + 화살표(현재 → 목표)
    final cur = Offset(t.currentX * size.width, t.currentY * size.height);
    canvas.drawCircle(cur, 6, Paint()..color = _marker);
    _paintArrow(canvas, cur, tgt, color);
  }

  void _paintArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, p);
    final angle = (to - from).direction;
    const headLen = 16.0;
    const spread = 0.5; // rad
    canvas.drawLine(to, to - Offset.fromDirection(angle - spread, headLen), p);
    canvas.drawLine(to, to - Offset.fromDirection(angle + spread, headLen), p);
  }

  @override
  bool shouldRepaint(covariant GuidePainter old) =>
      old.metrics != metrics || old.step != step || old.showGrid != showGrid;
}
