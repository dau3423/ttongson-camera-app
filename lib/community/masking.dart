// lib/community/masking.dart
// 순수 Dart — Flutter/plugin/image import 금지.
import 'models/mask_region.dart';

/// 정수 픽셀 사각형(순수 값 타입).
class IntRect {
  final int left;
  final int top;
  final int width;
  final int height;
  const IntRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  int get right => left + width;
  int get bottom => top + height;

  @override
  bool operator ==(Object other) =>
      other is IntRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// 정규화 영역을 이미지 픽셀 사각형으로 변환하고 경계로 clamp.
IntRect pixelRect(MaskRegion r, int imgW, int imgH) {
  var l = (r.left * imgW).floor();
  var t = (r.top * imgH).floor();
  var right = (r.right * imgW).ceil();
  var bottom = (r.bottom * imgH).ceil();
  if (l < 0) l = 0;
  if (t < 0) t = 0;
  if (right > imgW) right = imgW;
  if (bottom > imgH) bottom = imgH;
  final w = right - l < 0 ? 0 : right - l;
  final h = bottom - t < 0 ? 0 : bottom - t;
  return IntRect(left: l, top: t, width: w, height: h);
}

/// 영역 긴 변이 약 targetBlocks개 블록으로 픽셀화되도록 블록 크기 계산.
int mosaicBlockSize(
  int rectW,
  int rectH, {
  int targetBlocks = 12,
  int minBlock = 4,
}) {
  final longEdge = rectW > rectH ? rectW : rectH;
  var b = (longEdge / targetBlocks).floor();
  if (b < minBlock) b = minBlock;
  if (b < 1) b = 1;
  return b;
}

/// 감지된 픽셀 박스를 정규화 MaskRegion(isAuto: true)으로. 0~1로 clamp.
MaskRegion faceBoxToRegion(
  double boxLeft,
  double boxTop,
  double boxWidth,
  double boxHeight,
  int imgW,
  int imgH,
) {
  var l = boxLeft / imgW;
  var t = boxTop / imgH;
  var w = boxWidth / imgW;
  var h = boxHeight / imgH;
  if (l < 0) {
    w += l;
    l = 0;
  }
  if (t < 0) {
    h += t;
    t = 0;
  }
  if (l + w > 1) w = 1 - l;
  if (t + h > 1) h = 1 - t;
  if (w < 0) w = 0;
  if (h < 0) h = 0;
  return MaskRegion(left: l, top: t, width: w, height: h, isAuto: true);
}

/// 축소 치수(순수 값 타입).
class Dimensions {
  final int width;
  final int height;
  const Dimensions(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      other is Dimensions && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// 최장변이 상한을 넘으면 비율 유지 축소, 아니면 원본 유지(업스케일 금지).
Dimensions fitDimensions(int w, int h, int maxLongSide) {
  final longEdge = w > h ? w : h;
  if (longEdge <= maxLongSide) return Dimensions(w, h);
  final scale = maxLongSide / longEdge;
  return Dimensions((w * scale).round(), (h * scale).round());
}
