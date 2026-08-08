import '../models/person_box.dart';

enum HeadroomHint { none, raiseCamera, lowerCamera }

class HeadroomAdvice {
  final double ratio;
  final HeadroomHint hint;
  const HeadroomAdvice({required this.ratio, required this.hint});
}

/// 인물 머리 위 여백 비율을 계산하고 카메라 상하 조정을 안내.
HeadroomAdvice computeHeadroom(
  PersonBox person, {
  double idealMin = 0.05,
  double idealMax = 0.15,
}) {
  final ratio = person.top;
  final HeadroomHint hint;
  if (ratio < idealMin) {
    hint = HeadroomHint.raiseCamera;
  } else if (ratio > idealMax) {
    hint = HeadroomHint.lowerCamera;
  } else {
    hint = HeadroomHint.none;
  }
  return HeadroomAdvice(ratio: ratio, hint: hint);
}
