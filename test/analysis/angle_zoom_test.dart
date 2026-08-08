// test/analysis/angle_zoom_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/angle_zoom.dart';

void main() {
  group('pitch', () {
    test('세로 파지면 pitch≈0', () {
      expect(computePitch(9.8, 0.0).abs(), lessThan(0.01));
    });
    test('뒤로 젖히면 pitch 양수', () {
      expect(computePitch(9.8, 9.8), closeTo(45.0, 0.5));
    });
  });

  group('angle advice', () {
    test('guide=none 이면 안내 없음', () {
      expect(computeAngle(40, guide: AngleGuide.none).hint, AngleHint.none);
    });
    test('인물(eyeLevel) 눈높이면 안내 없음', () {
      expect(computeAngle(0, guide: AngleGuide.eyeLevel).hint, AngleHint.none);
    });
    test('인물(eyeLevel) 위를 향하면 눈높이로 내리라고', () {
      expect(
        computeAngle(30, guide: AngleGuide.eyeLevel).hint,
        AngleHint.eyeLevelDown,
      );
    });
    test('인물(eyeLevel) 아래를 향하면 눈높이로 올리라고', () {
      expect(
        computeAngle(-30, guide: AngleGuide.eyeLevel).hint,
        AngleHint.eyeLevelUp,
      );
    });
    test('정면(frontal) 위를 향하면 수평으로 내리라고', () {
      expect(
        computeAngle(30, guide: AngleGuide.frontal).hint,
        AngleHint.frontalDown,
      );
    });
    test('정면(frontal) 아래를 향하면 수평으로 올리라고', () {
      expect(
        computeAngle(-30, guide: AngleGuide.frontal).hint,
        AngleHint.frontalUp,
      );
    });
    test('정면(frontal) 수평이면 안내 없음', () {
      expect(computeAngle(0, guide: AngleGuide.frontal).hint, AngleHint.none);
    });
  });

  group('zoom advice', () {
    test('피사체가 작으면 다가가거나 확대 안내', () {
      expect(computeZoom(0.3).hint, ZoomHint.closer);
    });
    test('피사체가 크면 물러나거나 축소 안내', () {
      expect(computeZoom(0.9).hint, ZoomHint.farther);
    });
    test('적정 크기면 안내 없음', () {
      expect(computeZoom(0.65).hint, ZoomHint.none);
    });
  });
}
