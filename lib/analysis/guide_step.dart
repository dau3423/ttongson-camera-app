// lib/analysis/guide_step.dart
// 순수 Dart — Flutter/plugin import 금지.
import 'guide_metrics.dart';
import 'thirds.dart';
import 'angle_zoom.dart';
import 'headroom.dart';

enum GuideStepKind { level, crop, distance, position, headroom, angle, ready }

class GuideStep {
  final GuideStepKind kind;
  final ThirdsAlignment? target; // position 단계에서만 채움
  const GuideStep({required this.kind, this.target});
}

/// 우선순위대로 가장 급한(활성) 단계 하나를 고른다. 없으면 ready.
GuideStep computeCurrentStep(GuideMetrics m) {
  if (!m.tilt.isLevel) {
    return const GuideStep(kind: GuideStepKind.level);
  }
  final crop = m.crop;
  if (crop != null && crop.any) {
    return const GuideStep(kind: GuideStepKind.crop);
  }
  final zoom = m.zoom;
  if (zoom != null && zoom.hint != ZoomHint.none) {
    return const GuideStep(kind: GuideStepKind.distance);
  }
  final thirds = m.thirds;
  if (thirds != null && !thirds.isAligned) {
    return GuideStep(kind: GuideStepKind.position, target: thirds);
  }
  final headroom = m.headroom;
  if (headroom != null && headroom.hint != HeadroomHint.none) {
    return const GuideStep(kind: GuideStepKind.headroom);
  }
  if (m.angle.hint != AngleHint.none) {
    return const GuideStep(kind: GuideStepKind.angle);
  }
  return const GuideStep(kind: GuideStepKind.ready);
}
