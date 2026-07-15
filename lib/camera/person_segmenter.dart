import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

/// 세그멘테이션 결과 마스크. [bgAlpha]는 픽셀별 **배경** 불투명도(0~255),
/// row-major(width×height). 인물(전경)일수록 0, 배경일수록 255.
class SegMask {
  final int width;
  final int height;
  final Uint8List bgAlpha;
  const SegMask(this.width, this.height, this.bgAlpha);
}

/// ML Kit Selfie Segmentation 래퍼(플러그인 의존). 프리뷰용 stream 모드.
class PersonSegmenter {
  final SelfieSegmenter _seg = SelfieSegmenter(
    mode: SegmenterMode.stream,
    enableRawSizeMask: true,
  );

  Future<SegMask?> process(CameraImage image, int rotationDegrees) async {
    final input = _toInputImage(image, rotationDegrees);
    if (input == null) return null;
    final mask = await _seg.processImage(input);
    if (mask == null) return null;
    return _toSegMask(mask);
  }

  static SegMask _toSegMask(SegmentationMask mask) {
    final n = mask.width * mask.height;
    final conf = mask.confidences;
    final bg = Uint8List(n);
    for (var i = 0; i < n; i++) {
      // 전경(인물) 신뢰도 → 배경 알파(1-fg).
      final a = ((1.0 - conf[i]) * 255).round();
      bg[i] = a < 0 ? 0 : (a > 255 ? 255 : a);
    }
    return SegMask(mask.width, mask.height, bg);
  }

  InputImage? _toInputImage(CameraImage image, int rotationDegrees) {
    final rotation =
        InputImageRotationValue.fromRawValue(rotationDegrees) ??
        InputImageRotation.rotation0deg;
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw as int) ??
        InputImageFormat.nv21;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void dispose() => _seg.close();
}
