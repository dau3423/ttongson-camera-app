import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/mood_advisor.dart';

void main() {
  test('서버 응답 맵을 MoodParams로 파싱(범위 클램프)', () {
    final p = moodParamsFromResult({
      'brightness': 2.0,
      'contrast': 0.1,
      'saturation': -5.0,
      'temperature': 0.2,
      'tint': 0.0,
      'grayscale': true,
    });
    expect(p.brightness, 1.0);
    expect(p.saturation, -1.0);
    expect(p.grayscale, isTrue);
  });
}
