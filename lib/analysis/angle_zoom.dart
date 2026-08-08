import 'dart:math' as math;

enum AngleHint { none, eyeLevelUp, eyeLevelDown, frontalUp, frontalDown }

enum ZoomHint { none, closer, farther }

class AngleAdvice {
  final double pitchDegrees;
  final AngleHint hint;
  const AngleAdvice({required this.pitchDegrees, required this.hint});
}

class ZoomAdvice {
  final double subjectRatio;
  final ZoomHint hint;
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
  AngleHint hint = AngleHint.none;
  if (guide == AngleGuide.eyeLevel) {
    if (pitchDegrees > tolerance) {
      hint = AngleHint.eyeLevelDown;
    } else if (pitchDegrees < -tolerance) {
      hint = AngleHint.eyeLevelUp;
    }
  } else if (guide == AngleGuide.frontal) {
    if (pitchDegrees > tolerance) {
      hint = AngleHint.frontalDown;
    } else if (pitchDegrees < -tolerance) {
      hint = AngleHint.frontalUp;
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
  final ZoomHint hint;
  if (subjectHeightRatio < idealMin) {
    hint = ZoomHint.closer;
  } else if (subjectHeightRatio > idealMax) {
    hint = ZoomHint.farther;
  } else {
    hint = ZoomHint.none;
  }
  return ZoomAdvice(subjectRatio: subjectHeightRatio, hint: hint);
}
