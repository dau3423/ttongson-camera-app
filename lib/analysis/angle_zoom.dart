import 'dart:math' as math;

class AngleAdvice {
  final double pitchDegrees;
  final String hint;
  const AngleAdvice({required this.pitchDegrees, required this.hint});
}

class ZoomAdvice {
  final double subjectRatio;
  final String hint;
  const ZoomAdvice({required this.subjectRatio, required this.hint});
}

/// 가속도계 y,z로 상하 기울기(pitch)를 계산. 세로 파지 기준 0도, 양수=위를 향함.
double computePitch(double accelY, double accelZ) {
  return math.atan2(accelZ, accelY) * 180 / math.pi;
}

/// 인물 촬영 시 눈높이 대비 촬영 각도를 안내.
AngleAdvice computeAngle(
  double pitchDegrees, {
  bool hasPerson = false,
  double eyeLevelTolerance = 10,
}) {
  String hint = '';
  if (hasPerson) {
    if (pitchDegrees > eyeLevelTolerance) {
      hint = '카메라를 눈높이로 내리세요';
    } else if (pitchDegrees < -eyeLevelTolerance) {
      hint = '카메라를 눈높이로 올리세요';
    }
  }
  return AngleAdvice(pitchDegrees: pitchDegrees, hint: hint);
}

/// 피사체 높이 비율로 줌/거리 조정을 안내.
ZoomAdvice computeZoom(
  double subjectHeightRatio, {
  double idealMin = 0.5,
  double idealMax = 0.8,
}) {
  String hint;
  if (subjectHeightRatio < idealMin) {
    hint = '조금 다가가거나 확대하세요';
  } else if (subjectHeightRatio > idealMax) {
    hint = '조금 물러나거나 축소하세요';
  } else {
    hint = '';
  }
  return ZoomAdvice(subjectRatio: subjectHeightRatio, hint: hint);
}
