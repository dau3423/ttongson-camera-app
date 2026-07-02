import 'dart:math' as math;

class ThirdsAlignment {
  final double targetX;
  final double targetY;
  final double distance;
  final double score;
  final String hint;
  const ThirdsAlignment({
    required this.targetX,
    required this.targetY,
    required this.distance,
    required this.score,
    required this.hint,
  });
}

const _thirds = [1 / 3, 2 / 3];

/// 피사체 중심(cx,cy)에 대해 가장 가까운 3분할 교차점과 정렬 지표를 계산.
ThirdsAlignment computeThirds(double cx, double cy,
    {double alignedTolerance = 0.05}) {
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
  final score = 1 - (math.min(bestD / 0.4, 1.0) as double);
  final dx = bestX - cx;
  final dy = bestY - cy;
  final parts = <String>[];
  if (dx > alignedTolerance) {
    parts.add('오른쪽으로');
  } else if (dx < -alignedTolerance) {
    parts.add('왼쪽으로');
  }
  if (dy > alignedTolerance) {
    parts.add('아래로');
  } else if (dy < -alignedTolerance) {
    parts.add('위로');
  }
  final hint = parts.isEmpty ? '좋아요' : parts.join(' · ');
  return ThirdsAlignment(
    targetX: bestX,
    targetY: bestY,
    distance: bestD,
    score: score,
    hint: hint,
  );
}
