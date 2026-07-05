import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/box_normalize.dart';

void main() {
  test('회전 0/180은 원본 크기로 정규화(폭/높이 그대로)', () {
    final s0 = uprightSize(1280, 720, 0);
    expect(s0.w, 1280);
    expect(s0.h, 720);
    final s180 = uprightSize(1280, 720, 180);
    expect(s180.w, 1280);
    expect(s180.h, 720);
  });

  test('회전 90/270은 폭/높이를 뒤바꿔 세운다', () {
    final s90 = uprightSize(1280, 720, 90);
    expect(s90.w, 720);
    expect(s90.h, 1280);
    final s270 = uprightSize(1280, 720, 270);
    expect(s270.w, 720);
    expect(s270.h, 1280);
  });

  test('90도에서는 세운 크기(720x1280) 기준으로 정규화', () {
    // 세운 이미지 720(가로) x 1280(세로). 박스 (left=360,top=640,w=180,h=320)
    // → 정규화 (0.5, 0.5, 0.25, 0.25)
    final b = normalizeBox(360, 640, 180, 320, 1280, 720, 90);
    expect(b.left, closeTo(0.5, 1e-9));
    expect(b.top, closeTo(0.5, 1e-9));
    expect(b.width, closeTo(0.25, 1e-9));
    expect(b.height, closeTo(0.25, 1e-9));
  });

  test('0도에서는 원본 크기 기준으로 정규화', () {
    final b = normalizeBox(640, 360, 128, 72, 1280, 720, 0);
    expect(b.left, closeTo(0.5, 1e-9));
    expect(b.top, closeTo(0.5, 1e-9));
    expect(b.width, closeTo(0.1, 1e-9));
    expect(b.height, closeTo(0.1, 1e-9));
  });

  test('범위를 벗어나면 0~1로 clamp', () {
    final b = normalizeBox(-50, -50, 100000, 100000, 1280, 720, 90);
    expect(b.left, 0.0);
    expect(b.top, 0.0);
    expect(b.width, 1.0);
    expect(b.height, 1.0);
  });
}
