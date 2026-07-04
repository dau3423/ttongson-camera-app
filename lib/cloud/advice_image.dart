import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

class ScaledSize {
  final int width;
  final int height;
  const ScaledSize({required this.width, required this.height});
}

/// 긴 변이 maxLongEdge를 넘으면 비율 유지 축소, 아니면 원본 유지(업스케일 금지).
ScaledSize fitWithin(int width, int height, int maxLongEdge) {
  final longEdge = width > height ? width : height;
  if (longEdge <= maxLongEdge) {
    return ScaledSize(width: width, height: height);
  }
  final scale = maxLongEdge / longEdge;
  return ScaledSize(
    width: (width * scale).round(),
    height: (height * scale).round(),
  );
}

/// srcPath 이미지를 다운사이즈·JPEG로 재인코딩해 임시 파일 경로를 반환.
Future<String> encodeDownsizedJpeg(
  String srcPath, {
  int maxLongEdge = 1080,
  int quality = 80,
}) async {
  final bytes = await File(srcPath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('이미지 디코딩 실패: $srcPath');
  }
  final target = fitWithin(decoded.width, decoded.height, maxLongEdge);
  final resized =
      (target.width == decoded.width && target.height == decoded.height)
      ? decoded
      : img.copyResize(decoded, width: target.width, height: target.height);
  final jpeg = img.encodeJpg(resized, quality: quality);
  final outPath = '$srcPath.advice.jpg';
  await File(outPath).writeAsBytes(jpeg);
  return outPath;
}

/// 파일을 base64 문자열로 인코딩.
Future<String> fileToBase64(String path) async {
  final bytes = await File(path).readAsBytes();
  return base64Encode(bytes);
}
