import '../models/person_box.dart';

class CropWarning {
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  const CropWarning({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  bool get any => top || bottom || left || right;

  String get message {
    if (!any) return '';
    final sides = <String>[];
    if (top) sides.add('위');
    if (bottom) sides.add('아래');
    if (left) sides.add('왼쪽');
    if (right) sides.add('오른쪽');
    return '${sides.join('/')}이(가) 잘렸어요';
  }
}

/// 인물 경계가 프레임 가장자리에 닿아 잘렸는지 감지.
CropWarning detectCrop(PersonBox person, {double margin = 0.02}) {
  return CropWarning(
    top: person.top <= margin,
    bottom: person.bottom >= 1 - margin,
    left: person.left <= margin,
    right: person.right >= 1 - margin,
  );
}
