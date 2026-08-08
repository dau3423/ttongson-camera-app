import 'dart:math' as math;

enum TiltHint { none, lowerLeft, lowerRight }

class TiltInfo {
  final double rollDegrees;
  final bool isLevel;
  final TiltHint hint;
  const TiltInfo({
    required this.rollDegrees,
    required this.isLevel,
    required this.hint,
  });
}

/// 가속도계 x,y로 좌우 기울기(roll)를 계산한다.
/// 세로 파지(x≈0,y≈9.8) 기준 0도. 양수=오른쪽으로 기움.
TiltInfo computeTilt(
  double accelX,
  double accelY, {
  double levelToleranceDeg = 1.5,
}) {
  final roll = math.atan2(accelX, accelY) * 180 / math.pi;
  final level = roll.abs() <= levelToleranceDeg;
  final TiltHint hint;
  if (level) {
    hint = TiltHint.none;
  } else if (roll > 0) {
    hint = TiltHint.lowerLeft;
  } else {
    hint = TiltHint.lowerRight;
  }
  return TiltInfo(rollDegrees: roll, isLevel: level, hint: hint);
}
