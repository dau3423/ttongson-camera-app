import 'dart:math' as math;

class TiltInfo {
  final double rollDegrees;
  final bool isLevel;
  final String hint;
  const TiltInfo({
    required this.rollDegrees,
    required this.isLevel,
    required this.hint,
  });
}

/// 가속도계 x,y로 좌우 기울기(roll)를 계산한다.
/// 세로 파지(x≈0,y≈9.8) 기준 0도. 양수=오른쪽으로 기움.
TiltInfo computeTilt(double accelX, double accelY,
    {double levelToleranceDeg = 1.5}) {
  final roll = math.atan2(accelX, accelY) * 180 / math.pi;
  final level = roll.abs() <= levelToleranceDeg;
  String hint;
  if (level) {
    hint = '';
  } else if (roll > 0) {
    hint = '왼쪽을 내리세요';
  } else {
    hint = '오른쪽을 내리세요';
  }
  return TiltInfo(rollDegrees: roll, isLevel: level, hint: hint);
}
