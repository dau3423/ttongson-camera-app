import '../models/person_box.dart';

class HeadroomAdvice {
  final double ratio;
  final String hint;
  const HeadroomAdvice({required this.ratio, required this.hint});
}

/// 인물 머리 위 여백 비율을 계산하고 카메라 상하 조정을 안내.
HeadroomAdvice computeHeadroom(
  PersonBox person, {
  double idealMin = 0.05,
  double idealMax = 0.15,
}) {
  final ratio = person.top;
  String hint;
  if (ratio < idealMin) {
    hint = '카메라를 살짝 올리세요';
  } else if (ratio > idealMax) {
    hint = '카메라를 살짝 내리세요';
  } else {
    hint = '';
  }
  return HeadroomAdvice(ratio: ratio, hint: hint);
}
