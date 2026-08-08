import 'dart:math' as math;

class ThirdsAlignment {
  final double currentX;
  final double currentY;
  final double targetX;
  final double targetY;
  final double distance;
  final double score;
  final bool isAligned;
  final bool moveRight;
  final bool moveLeft;
  final bool moveUp;
  final bool moveDown;
  const ThirdsAlignment({
    required this.currentX,
    required this.currentY,
    required this.targetX,
    required this.targetY,
    required this.distance,
    required this.score,
    required this.isAligned,
    required this.moveRight,
    required this.moveLeft,
    required this.moveUp,
    required this.moveDown,
  });
}

const _thirds = [1 / 3, 2 / 3];

/// 피사체 중심(cx,cy)에 대해 가장 가까운 3분할 교차점과 정렬 지표를 계산.
ThirdsAlignment computeThirds(
  double cx,
  double cy, {
  double alignedTolerance = 0.05,
}) {
  double bestX = _thirds[0], bestY = _thirds[0], bestD = double.infinity;
  for (final tx in _thirds) {
    for (final ty in _thirds) {
      final d = math.sqrt(math.pow(tx - cx, 2) + math.pow(ty - cy, 2));
      if (d < bestD) {
        bestD = d;
        bestX = tx;
        bestY = ty;
      }
    }
  }
  final score = 1.0 - math.min(bestD / 0.4, 1.0);
  final dx = bestX - cx;
  final dy = bestY - cy;
  final moveRight = dx > alignedTolerance;
  final moveLeft = dx < -alignedTolerance;
  final moveDown = dy > alignedTolerance;
  final moveUp = dy < -alignedTolerance;
  final isAligned = !moveRight && !moveLeft && !moveUp && !moveDown;
  return ThirdsAlignment(
    currentX: cx,
    currentY: cy,
    targetX: bestX,
    targetY: bestY,
    distance: bestD,
    score: score,
    isAligned: isAligned,
    moveRight: moveRight,
    moveLeft: moveLeft,
    moveUp: moveUp,
    moveDown: moveDown,
  );
}
