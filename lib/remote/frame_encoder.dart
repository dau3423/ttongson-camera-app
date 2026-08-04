// 카메라 프레임(BGRA8888/NV21)을 리모컨 프리뷰용 축소 JPEG로 변환한다.
// 순수 Dart(package:image) — Flutter/camera plugin import 금지.
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../cloud/advice_image.dart' show fitWithin;

/// iOS BGRA8888 프레임 → 이미지. bytesPerRow의 행 패딩을 건너뛴다.
img.Image imageFromBgra8888({
  required int width,
  required int height,
  required Uint8List bytes,
  required int bytesPerRow,
}) {
  final out = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    final row = y * bytesPerRow;
    for (var x = 0; x < width; x++) {
      final i = row + x * 4;
      out.setPixelRgb(x, y, bytes[i + 2], bytes[i + 1], bytes[i]);
    }
  }
  return out;
}

/// Android NV21 프레임 → 이미지. full-range BT.601 근사.
img.Image imageFromNv21({
  required int width,
  required int height,
  required Uint8List nv21,
}) {
  final out = img.Image(width: width, height: height);
  final ySize = width * height;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final yy = nv21[y * width + x];
      final vuIndex = ySize + (y >> 1) * width + (x & ~1);
      final v = nv21[vuIndex] - 128;
      final u = nv21[vuIndex + 1] - 128;
      final r = (yy + 1.402 * v).round().clamp(0, 255);
      final g = (yy - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
      final b = (yy + 1.772 * u).round().clamp(0, 255);
      out.setPixelRgb(x, y, r, g, b);
    }
  }
  return out;
}

/// 회전 → 반전 → 축소 → JPEG 인코딩.
Uint8List encodePreviewJpeg(
  img.Image src, {
  int maxLongEdge = 480,
  int quality = 60,
  int rotationDegrees = 0,
  bool mirror = false,
}) {
  var im = src;
  if (rotationDegrees != 0) {
    im = img.copyRotate(im, angle: rotationDegrees);
  }
  if (mirror) {
    im = img.flipHorizontal(im);
  }
  final target = fitWithin(im.width, im.height, maxLongEdge);
  if (target.width != im.width || target.height != im.height) {
    im = img.copyResize(im, width: target.width, height: target.height);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}
