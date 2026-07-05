// lib/analysis/guide_step.dart
// 순수 Dart — Flutter/plugin import 금지.
import 'guide_metrics.dart';
import 'thirds.dart';

enum GuideStepKind { level, crop, distance, position, headroom, angle, ready }

/// 지금 사용자가 해야 할 단 하나의 행동.
class GuideStep {
  final GuideStepKind kind;
  final String message;
  final ThirdsAlignment? target; // position 단계에서만 채움(현재점·목표점)
  const GuideStep({required this.kind, required this.message, this.target});
}

const _aligned = '좋아요';
const _readyMessage = '찍으세요!';

/// 우선순위대로 가장 급한(활성) 단계 하나를 고른다. 없으면 ready.
GuideStep computeCurrentStep(GuideMetrics m) {
  if (!m.tilt.isLevel) {
    return GuideStep(kind: GuideStepKind.level, message: m.tilt.hint);
  }
  final crop = m.crop;
  if (crop != null && crop.any) {
    return GuideStep(kind: GuideStepKind.crop, message: crop.message);
  }
  final zoom = m.zoom;
  if (zoom != null && zoom.hint.isNotEmpty) {
    return GuideStep(kind: GuideStepKind.distance, message: zoom.hint);
  }
  final thirds = m.thirds;
  if (thirds != null && thirds.hint != _aligned) {
    return GuideStep(
      kind: GuideStepKind.position,
      message: '여기로 옮기세요',
      target: thirds,
    );
  }
  final headroom = m.headroom;
  if (headroom != null && headroom.hint.isNotEmpty) {
    return GuideStep(kind: GuideStepKind.headroom, message: headroom.hint);
  }
  if (m.angle.hint.isNotEmpty) {
    return GuideStep(kind: GuideStepKind.angle, message: m.angle.hint);
  }
  return const GuideStep(kind: GuideStepKind.ready, message: _readyMessage);
}
