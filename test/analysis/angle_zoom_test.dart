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
    test('인물 없으면 각도 안내 없음', () {
      expect(computeAngle(40, hasPerson: false).hint, '');
    });
    test('인물 촬영 시 눈높이면 안내 없음', () {
      expect(computeAngle(0, hasPerson: true).hint, '');
    });
    test('많이 젖혀 위를 향하면 눈높이로 내리라고 안내', () {
      expect(computeAngle(30, hasPerson: true).hint, '카메라를 눈높이로 내리세요');
    });
    test('많이 숙여 아래를 향하면 눈높이로 올리라고 안내', () {
      expect(computeAngle(-30, hasPerson: true).hint, '카메라를 눈높이로 올리세요');
    });
  });

  group('zoom advice', () {
    test('피사체가 작으면 다가가거나 확대 안내', () {
      expect(computeZoom(0.3).hint, '조금 다가가거나 확대하세요');
    });
    test('피사체가 크면 물러나거나 축소 안내', () {
      expect(computeZoom(0.9).hint, '조금 물러나거나 축소하세요');
    });
    test('적정 크기면 안내 없음', () {
      expect(computeZoom(0.65).hint, '');
    });
  });
}
