import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/mood_adjust.dart';

void main() {
  group('MoodParams.fromJson', () {
    test('범위를 벗어난 값은 -1~1로 클램프', () {
      final p = MoodParams.fromJson({
        'brightness': 5.0,
        'contrast': -9.0,
        'saturation': 0.3,
        'temperature': 2.0,
        'tint': -3.0,
        'grayscale': true,
      });
      expect(p.brightness, 1.0);
      expect(p.contrast, -1.0);
      expect(p.saturation, 0.3);
      expect(p.temperature, 1.0);
      expect(p.tint, -1.0);
      expect(p.grayscale, isTrue);
    });

    test('누락/이상 타입은 0 또는 false로 방어', () {
      final p = MoodParams.fromJson({'brightness': 'x'});
      expect(p.brightness, 0.0);
      expect(p.contrast, 0.0);
      expect(p.grayscale, isFalse);
    });
  });

  group('adjustRgb', () {
    test('identity 파라미터는 픽셀을 바꾸지 않음', () {
      final (r, g, b) = adjustRgb(100, 150, 200, MoodParams.identity);
      expect([r, g, b], [100, 150, 200]);
    });

    test('밝기 +1이면 밝아지고 0~255로 클램프', () {
      final (r, _, _) = adjustRgb(
        200,
        200,
        200,
        const MoodParams(brightness: 1.0),
      );
      expect(r, 255);
    });

    test('밝기 -1이면 어두워지고 0 아래로 안 내려감', () {
      final (r, _, _) = adjustRgb(
        50,
        50,
        50,
        const MoodParams(brightness: -1.0),
      );
      expect(r, 0);
    });

    test('채도 -1이면 회색(모든 채널이 luminance로 수렴)', () {
      final (r, g, b) = adjustRgb(
        200,
        100,
        0,
        const MoodParams(saturation: -1.0),
      );
      expect(r, g);
      expect(g, b);
    });

    test('색온도 양수는 R을 올리고 B를 낮춤(웜)', () {
      final (r, _, b) = adjustRgb(
        120,
        120,
        120,
        const MoodParams(temperature: 0.5),
      );
      expect(r, greaterThan(120));
      expect(b, lessThan(120));
    });

    test('grayscale=true면 R=G=B', () {
      final (r, g, b) = adjustRgb(
        200,
        100,
        0,
        const MoodParams(grayscale: true),
      );
      expect(r, g);
      expect(g, b);
    });
  });
}
