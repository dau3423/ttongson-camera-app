// lib/edit/mood_processor.dart
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../analysis/mood_adjust.dart';

/// 각 픽셀에 adjustRgb를 적용한 새 이미지를 반환(원본 불변).
img.Image applyMoodToImage(img.Image src, MoodParams p) {
  final out = src.clone();
  for (final pixel in out) {
    final (r, g, b) = adjustRgb(
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
      p,
    );
    pixel.setRgb(r, g, b);
  }
  return out;
}

/// src 이미지를 보정해 JPEG 임시 파일로 저장하고 경로 File을 반환.
/// 디코드→방향 반영→EXIF 제거→보정→인코드. 픽셀 처리는 아이솔레이트에서.
Future<File> applyMood(File src, MoodParams p) async {
  final bytes = await src.readAsBytes();
  final jpeg = await Isolate.run(() => _process(bytes, p));
  final dir = await getTemporaryDirectory();
  final out = File(
    '${dir.path}/mood_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await out.writeAsBytes(jpeg);
  return out;
}

Uint8List _process(Uint8List bytes, MoodParams p) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('이미지 디코딩 실패');
  }
  final baked = img.bakeOrientation(decoded);
  baked.exif = img.ExifData();
  final adjusted = applyMoodToImage(baked, p);
  return img.encodeJpg(adjusted, quality: 90);
}
