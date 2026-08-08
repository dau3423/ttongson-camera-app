import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/tilt.dart';

void main() {
  test('완벽히 수평이면 rollDegrees≈0, isLevel=true, hint 없음', () {
    final t = computeTilt(0.0, 9.8);
    expect(t.rollDegrees.abs(), lessThan(0.01));
    expect(t.isLevel, isTrue);
    expect(t.hint, TiltHint.none);
  });

  test('오른쪽으로 기울면 rollDegrees 양수, hint는 왼쪽을 내리라고 안내', () {
    final t = computeTilt(9.8, 9.8); // 45도
    expect(t.rollDegrees, closeTo(45.0, 0.5));
    expect(t.isLevel, isFalse);
    expect(t.hint, TiltHint.lowerLeft);
  });

  test('왼쪽으로 기울면 rollDegrees 음수, hint는 오른쪽을 내리라고 안내', () {
    final t = computeTilt(-9.8, 9.8); // -45도
    expect(t.rollDegrees, closeTo(-45.0, 0.5));
    expect(t.hint, TiltHint.lowerRight);
  });

  test('허용오차 내 미세 기울기는 수평으로 판정', () {
    final t = computeTilt(0.17, 9.8); // 약 1.0도
    expect(t.rollDegrees.abs(), lessThan(1.5));
    expect(t.isLevel, isTrue);
    expect(t.hint, TiltHint.none);
  });
}
