/// 인물이 들어갈 목표 영역(정규화 0~1, 원점 좌상단).
class TargetBox {
  final double x;
  final double y;
  final double width;
  final double height;
  const TargetBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get right => x + width;
  double get bottom => y + height;
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
}

/// 클라우드 구도 추천 결과. 방어적 파싱 — 누락/이상 값에도 견고.
class CompositionAdvice {
  final String headline;
  final TargetBox? targetBox;
  final String rationale;

  const CompositionAdvice({
    required this.headline,
    required this.targetBox,
    required this.rationale,
  });

  factory CompositionAdvice.fromJson(Map<String, dynamic> json) {
    return CompositionAdvice(
      headline: (json['headline'] as String?) ?? '',
      targetBox: _parseTargetBox(json['targetBox']),
      rationale: (json['rationale'] as String?) ?? '',
    );
  }

  static TargetBox? _parseTargetBox(dynamic raw) {
    if (raw is! Map) return null;
    final x = raw['x'];
    final y = raw['y'];
    final w = raw['width'];
    final h = raw['height'];
    if (x is! num || y is! num || w is! num || h is! num) return null;
    double c(num v) => v.toDouble().clamp(0.0, 1.0);
    return TargetBox(x: c(x), y: c(y), width: c(w), height: c(h));
  }
}
