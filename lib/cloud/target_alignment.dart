import 'dart:math' as math;
import '../models/person_box.dart';
import 'composition_advice.dart';

class AlignmentResult {
  final double score;
  final bool aligned;
  final double dx;
  final double dy;
  const AlignmentResult({
    required this.score,
    required this.aligned,
    required this.dx,
    required this.dy,
  });
}

/// 현재 인물 박스와 목표 박스의 정렬을 IoU로 계산한다. 순수 함수.
AlignmentResult computeAlignment(
  PersonBox current,
  TargetBox target, {
  double alignThreshold = 0.6,
}) {
  final ix1 = math.max(current.left, target.x);
  final iy1 = math.max(current.top, target.y);
  final ix2 = math.min(current.right, target.right);
  final iy2 = math.min(current.bottom, target.bottom);
  final iw = math.max(0.0, ix2 - ix1);
  final ih = math.max(0.0, iy2 - iy1);
  final inter = iw * ih;
  final union =
      current.width * current.height + target.width * target.height - inter;
  final score = union <= 0 ? 0.0 : inter / union;
  final dx = target.centerX - current.centerX;
  final dy = target.centerY - current.centerY;
  return AlignmentResult(
    score: score,
    aligned: score >= alignThreshold,
    dx: dx,
    dy: dy,
  );
}
