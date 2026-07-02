import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analysis/guide_metrics.dart';

class GuideOverlay extends StatelessWidget {
  final GuideMetrics metrics;
  final bool showGrid;
  const GuideOverlay({super.key, required this.metrics, this.showGrid = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GuidePainter(metrics: metrics, showGrid: showGrid),
      size: Size.infinite,
    );
  }
}

class GuidePainter extends CustomPainter {
  final GuideMetrics metrics;
  final bool showGrid;
  GuidePainter({required this.metrics, required this.showGrid});

  static const _good = Color(0xAA69F0AE); // greenAccent 반투명
  static const _warn = Color(0xAAFF5252); // redAccent 반투명
  static const _neutral = Color(0x88FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) _paintGrid(canvas, size);
    _paintLevel(canvas, size);
    _paintPerson(canvas, size);
    _paintThirdsTarget(canvas, size);
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
    // 화면 중앙, roll만큼 회전한 짧은 수평선.
    final rad = metrics.tilt.rollDegrees * math.pi / 180;
    final half = size.width * 0.15;
    final dxr = half * math.cos(rad);
    final dyr = half * math.sin(rad);
    canvas.drawLine(
        Offset(cx - dxr, cy - dyr), Offset(cx + dxr, cy + dyr), p);
  }

  void _paintPerson(Canvas canvas, Size size) {
    final person = metrics.person;
    if (person == null) return;
    final cropped = metrics.crop?.any ?? false;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = cropped ? _warn : _good;
    canvas.drawRect(
      Rect.fromLTWH(person.left * size.width, person.top * size.height,
          person.width * size.width, person.height * size.height),
      p,
    );
  }

  void _paintThirdsTarget(Canvas canvas, Size size) {
    final thirds = metrics.thirds;
    if (thirds == null) return;
    final aligned = thirds.hint == '좋아요';
    final p = Paint()..color = aligned ? _good : _warn;
    canvas.drawCircle(
      Offset(thirds.targetX * size.width, thirds.targetY * size.height),
      8,
      p,
    );
  }

  @override
  bool shouldRepaint(covariant GuidePainter old) =>
      old.metrics != metrics || old.showGrid != showGrid;
}
