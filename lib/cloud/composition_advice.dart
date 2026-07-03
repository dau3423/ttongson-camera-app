enum AdviceAxis { move, tilt, zoom, angle }

AdviceAxis? _axisFromString(String? s) {
  switch (s) {
    case 'move':
      return AdviceAxis.move;
    case 'tilt':
      return AdviceAxis.tilt;
    case 'zoom':
      return AdviceAxis.zoom;
    case 'angle':
      return AdviceAxis.angle;
    default:
      return null;
  }
}

class AdviceDirection {
  final AdviceAxis axis;
  final String instruction;
  const AdviceDirection({required this.axis, required this.instruction});
}

/// 클라우드 구도 추천 결과. 방어적 파싱 — 누락/이상 값에도 견고.
class CompositionAdvice {
  final String headline;
  final List<AdviceDirection> directions;
  final String rationale;

  const CompositionAdvice({
    required this.headline,
    required this.directions,
    required this.rationale,
  });

  factory CompositionAdvice.fromJson(Map<String, dynamic> json) {
    final rawDirs = json['directions'];
    final directions = <AdviceDirection>[];
    if (rawDirs is List) {
      for (final d in rawDirs) {
        if (d is Map) {
          final axis = _axisFromString(d['axis'] as String?);
          final instruction = d['instruction'];
          if (axis != null && instruction is String) {
            directions.add(AdviceDirection(axis: axis, instruction: instruction));
          }
        }
      }
    }
    return CompositionAdvice(
      headline: (json['headline'] as String?) ?? '',
      directions: directions,
      rationale: (json['rationale'] as String?) ?? '',
    );
  }
}
