import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// 촬영된 정지 이미지에 인물 세그멘테이션 기반 배경 흐림을 적용해
/// 새 JPEG 임시 파일을 만든다. 세그 실패 시 원본을 그대로 반환.
/// [nowMicros]는 임시 파일명용 타임스탬프(호출측에서 주입).
Future<File> applyPortraitBlur(File src, {required int nowMicros}) async {
  final segmenter = SelfieSegmenter(
    mode: SegmenterMode.single,
    enableRawSizeMask: true,
  );
  try {
    final mask = await segmenter.processImage(
      InputImage.fromFilePath(src.path),
    );
    if (mask == null) return src;
    final bg = _bgAlpha(mask);
    final bytes = await src.readAsBytes();
    final out = await Isolate.run(
      () => _composite(bytes, bg, mask.width, mask.height),
    );
    if (out == null) return src;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/portrait_$nowMicros.jpg');
    await file.writeAsBytes(out);
    return file;
  } catch (_) {
    return src; // 실패 시 원본 저장(비차단)
  } finally {
    await segmenter.close();
  }
}

/// 전경 신뢰도 → 배경 알파(0~255).
Uint8List _bgAlpha(SegmentationMask mask) {
  final n = mask.width * mask.height;
  final conf = mask.confidences;
  final bg = Uint8List(n);
  for (var i = 0; i < n; i++) {
    final a = ((1.0 - conf[i]) * 255).round();
    bg[i] = a < 0 ? 0 : (a > 255 ? 255 : a);
  }
  return bg;
}

/// 아이솔레이트: 디코드→방향 반영→배경 블러 합성→JPEG 인코드.
Uint8List? _composite(Uint8List bytes, Uint8List bgAlpha, int mw, int mh) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final base = img.bakeOrientation(decoded)..exif = img.ExifData();
  final blurred = img.gaussianBlur(base.clone(), radius: 12);
  final iw = base.width;
  final ih = base.height;
  for (var y = 0; y < ih; y++) {
    final my = (y * mh ~/ ih).clamp(0, mh - 1);
    final row = my * mw;
    for (var x = 0; x < iw; x++) {
      final mx = (x * mw ~/ iw).clamp(0, mw - 1);
      final a = bgAlpha[row + mx] / 255.0; // 배경 비중
      if (a <= 0.02) continue; // 전경(인물): 원본 유지
      final fg = base.getPixel(x, y);
      final bl = blurred.getPixel(x, y);
      base.setPixelRgb(
        x,
        y,
        (fg.r * (1 - a) + bl.r * a).round(),
        (fg.g * (1 - a) + bl.g * a).round(),
        (fg.b * (1 - a) + bl.b * a).round(),
      );
    }
  }
  return img.encodeJpg(base, quality: 90);
}
