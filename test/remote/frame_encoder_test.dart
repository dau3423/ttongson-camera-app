import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ttongson_camera/remote/frame_encoder.dart';

void main() {
  test('BGRA: 2x1 픽셀 값과 stride 처리', () {
    // 1행 stride 12바이트(8바이트 픽셀 + 4바이트 패딩). B,G,R,A 순.
    final bytes = Uint8List.fromList([
      255, 0, 0, 255, // 파랑
      0, 255, 0, 255, // 초록
      0, 0, 0, 0, // 패딩
    ]);
    final im = imageFromBgra8888(
      width: 2,
      height: 1,
      bytes: bytes,
      bytesPerRow: 12,
    );
    expect(im.width, 2);
    final p0 = im.getPixel(0, 0);
    expect([p0.r, p0.g, p0.b], [0, 0, 255]);
    final p1 = im.getPixel(1, 0);
    expect([p1.r, p1.g, p1.b], [0, 255, 0]);
  });

  test('NV21: 회색(Y=128,U=V=128)은 RGB(128,128,128)', () {
    // 2x2: Y 4바이트 + VU 2바이트
    final nv21 = Uint8List.fromList([128, 128, 128, 128, 128, 128]);
    final im = imageFromNv21(width: 2, height: 2, nv21: nv21);
    final p = im.getPixel(1, 1);
    expect([p.r, p.g, p.b], [128, 128, 128]);
  });

  test('encodePreviewJpeg: 긴 변 480 축소 + 유효한 JPEG', () {
    final src = img.Image(width: 1920, height: 1080);
    final jpeg = encodePreviewJpeg(src);
    final decoded = img.decodeJpg(jpeg);
    expect(decoded, isNotNull);
    expect(decoded!.width, 480);
    expect(decoded.height, 270);
  });

  test('encodePreviewJpeg: 회전 90도면 가로세로 교환', () {
    final src = img.Image(width: 1920, height: 1080);
    final jpeg = encodePreviewJpeg(src, rotationDegrees: 90);
    final decoded = img.decodeJpg(jpeg)!;
    expect(decoded.width, 270);
    expect(decoded.height, 480);
  });
}
