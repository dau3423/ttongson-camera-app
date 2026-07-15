import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analysis/guide_metrics.dart';
import '../analysis/guide_step.dart';
import '../analysis/thirds.dart';
import '../theme/app_colors.dart';

class GuideOverlay extends StatelessWidget {
  final GuideMetrics metrics;
  final GuideStep step;
  final bool showGrid;

  /// 사물/자연 모드처럼 얼굴 랜드마크가 없을 때, 감지된 피사체 박스를
  /// 은은하게 상시 표시해 "인식되고 있음"을 알린다.
  final bool showSubjectBox;
  const GuideOverlay({
    super.key,
    required this.metrics,
    required this.step,
    this.showGrid = true,
    this.showSubjectBox = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GuidePainter(
        metrics: metrics,
        step: step,
        showGrid: showGrid,
        showSubjectBox: showSubjectBox,
      ),
      size: Size.infinite,
    );
  }
}

class GuidePainter extends CustomPainter {
  final GuideMetrics metrics;
  final GuideStep step;
  final bool showGrid;
  final bool showSubjectBox;
  GuidePainter({
    required this.metrics,
    required this.step,
    required this.showGrid,
    this.showSubjectBox = false,
  });

  static final _good = AppColors.ready.withValues(alpha: 0.85);
  static final _warn = AppColors.warn.withValues(alpha: 0.85);
  static final _amber = AppColors.accent.withValues(alpha: 0.93);
  static const _neutral = Color(0x66FFFFFF); // 격자 흰선 0.4
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
    final color = level ? _good : _warn;
    final cy = size.height / 2;
    final cx = size.width / 2;
    final rad = metrics.tilt.rollDegrees * math.pi / 180;
    // 길이 고정(스펙 120~150px), 화면 폭이 좁으면 폭에 맞춰 축소.
    final half = math.min(65.0, size.width * 0.2);
    final dxr = half * math.cos(rad);
    final dyr = half * math.sin(rad);
    final a = Offset(cx - dxr, cy - dyr);
    final b = Offset(cx + dxr, cy + dyr);
    // glow(발광) 먼저 깔고 그 위에 실선.
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintPerson(Canvas canvas, Size size) {
    final person = metrics.person;
    if (person == null) return;
    // '잘림' 경고일 때는 빨간 박스로 무엇이 잘렸는지 보여준다.
    // 그 외엔 평소 화면을 비우되(인물 모드), 사물/자연 모드는 감지 피드백을 위해
    // 은은한 흰 박스를 상시 표시한다.
    final isCrop = step.kind == GuideStepKind.crop;
    if (!isCrop && !showSubjectBox) return;
    final rect = Rect.fromLTWH(
      person.left * size.width,
      person.top * size.height,
      person.width * size.width,
      person.height * size.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    if (!isCrop) {
      canvas.drawRRect(rrect, Paint()..color = const Color(0x14FFFFFF));
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = isCrop ? _warn : _neutral,
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
      old.metrics != metrics ||
      old.step != step ||
      old.showGrid != showGrid ||
      old.showSubjectBox != showSubjectBox;
}
