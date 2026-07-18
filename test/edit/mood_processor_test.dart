import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ttongson_camera/analysis/mood_adjust.dart';
import 'package:ttongson_camera/edit/mood_processor.dart';

void main() {
  test('identity 파라미터는 픽셀 값을 유지', () {
    final src = img.Image(width: 2, height: 2);
    src.setPixelRgb(0, 0, 100, 150, 200);
    src.setPixelRgb(1, 1, 10, 20, 30);
    final out = applyMoodToImage(src, MoodParams.identity);
    final p = out.getPixel(0, 0);
    expect([p.r.toInt(), p.g.toInt(), p.b.toInt()], [100, 150, 200]);
  });

  test('grayscale 프리셋은 R=G=B로 만든다', () {
    final src = img.Image(width: 1, height: 1);
    src.setPixelRgb(0, 0, 200, 100, 0);
    final out = applyMoodToImage(src, const MoodParams(grayscale: true));
    final p = out.getPixel(0, 0);
    expect(p.r.toInt(), p.g.toInt());
    expect(p.g.toInt(), p.b.toInt());
  });

  test('원본 이미지는 변형하지 않는다(새 이미지 반환)', () {
    final src = img.Image(width: 1, height: 1);
    src.setPixelRgb(0, 0, 100, 100, 100);
    applyMoodToImage(src, const MoodParams(brightness: 1.0));
    final p = src.getPixel(0, 0);
    expect(p.r.toInt(), 100); // 원본 불변
  });
}
