import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/advice_image.dart';

void main() {
  test('긴 변이 한계를 넘으면 비율 유지 축소 (가로)', () {
    final s = fitWithin(4000, 3000, 1080);
    expect(s.width, 1080);
    expect(s.height, 810); // 3000 * 1080/4000
  });

  test('긴 변이 한계를 넘으면 비율 유지 축소 (세로)', () {
    final s = fitWithin(3000, 4000, 1080);
    expect(s.height, 1080);
    expect(s.width, 810);
  });

  test('이미 작으면 그대로 (업스케일 금지)', () {
    final s = fitWithin(800, 600, 1080);
    expect(s.width, 800);
    expect(s.height, 600);
  });
}
