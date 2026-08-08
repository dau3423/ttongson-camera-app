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
