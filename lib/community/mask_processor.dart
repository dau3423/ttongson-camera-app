// lib/community/mask_processor.dart
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'masking.dart';
import 'models/mask_region.dart';

/// 정지 이미지에서 얼굴을 감지해 자동 가림 영역을 만든다.
/// 감지 실패/미감지/디코딩 실패 시 빈 리스트(비차단).
Future<List<MaskRegion>> detectFaceRegions(File src) async {
  final detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  try {
    final faces = await detector.processImage(
      InputImage.fromFilePath(src.path),
    );
    if (faces.isEmpty) return const [];
    // ML Kit의 얼굴 박스는 EXIF 방향이 반영된 이미지 좌표.
    // 정규화 기준도 방향 반영 크기를 써야 하므로 bakeOrientation 후 크기 사용.
    final bytes = await src.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const [];
    final baked = img.bakeOrientation(decoded);
    final w = baked.width;
    final h = baked.height;
    return faces.map((f) {
      final b = f.boundingBox;
      return faceBoxToRegion(b.left, b.top, b.width, b.height, w, h);
    }).toList();
  } catch (_) {
    return const [];
  } finally {
    await detector.close();
  }
}

/// enabled 영역을 모자이크로 가린 새 JPEG 임시 파일을 만든다.
/// 픽셀 처리는 아이솔레이트에서 수행. 원본은 변경하지 않는다.
Future<File> applyMasks(File src, List<MaskRegion> regions) async {
  final bytes = await src.readAsBytes();
  final enabled = regions.where((r) => r.enabled).toList();
  final jpeg = await Isolate.run(() => _composite(bytes, enabled));
  final dir = await getTemporaryDirectory();
  final out = File(
    '${dir.path}/masked_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await out.writeAsBytes(jpeg);
  return out;
}

/// 아이솔레이트에서 실행: 디코드→방향 반영→축소→모자이크→JPEG 인코드.
Uint8List _composite(Uint8List bytes, List<MaskRegion> regions) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('이미지 디코딩 실패');
  }
  var image = img.bakeOrientation(decoded);
  image.exif = img.ExifData();
  final dim = fitDimensions(image.width, image.height, 1600);
  if (dim.width != image.width || dim.height != image.height) {
    image = img.copyResize(image, width: dim.width, height: dim.height);
  }
  for (final r in regions) {
    final pr = pixelRect(r, image.width, image.height);
    if (pr.width <= 0 || pr.height <= 0) continue;
    _mosaic(image, pr);
  }
  return img.encodeJpg(image, quality: 85);
}

/// 영역을 다운스케일(평균)→업스케일(nearest)로 픽셀화해 원본에 덮어쓴다.
void _mosaic(img.Image image, IntRect pr) {
  final b = mosaicBlockSize(pr.width, pr.height);
  final smallW = (pr.width / b).ceil().clamp(1, pr.width);
  final smallH = (pr.height / b).ceil().clamp(1, pr.height);
  final region = img.copyCrop(
    image,
    x: pr.left,
    y: pr.top,
    width: pr.width,
    height: pr.height,
  );
  final down = img.copyResize(
    region,
    width: smallW,
    height: smallH,
    interpolation: img.Interpolation.average,
  );
  final up = img.copyResize(
    down,
    width: pr.width,
    height: pr.height,
    interpolation: img.Interpolation.nearest,
  );
  img.compositeImage(image, up, dstX: pr.left, dstY: pr.top);
}
