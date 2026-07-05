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

enum AngleGuide { none, eyeLevel, frontal }

/// 촬영 각도를 모드에 맞게 안내한다.
/// eyeLevel(인물): 눈높이 기준. frontal(사물·자연): 정면·수평 기준.
AngleAdvice computeAngle(
  double pitchDegrees, {
  AngleGuide guide = AngleGuide.none,
  double tolerance = 10,
}) {
  String hint = '';
  if (guide == AngleGuide.eyeLevel) {
    if (pitchDegrees > tolerance) {
      hint = '카메라를 눈높이로 내리세요';
    } else if (pitchDegrees < -tolerance) {
      hint = '카메라를 눈높이로 올리세요';
    }
  } else if (guide == AngleGuide.frontal) {
    if (pitchDegrees > tolerance) {
      hint = '카메라를 수평으로 내리세요';
    } else if (pitchDegrees < -tolerance) {
      hint = '카메라를 수평으로 올리세요';
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
