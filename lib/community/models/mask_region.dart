// lib/community/models/mask_region.dart
// 순수 Dart — Flutter/plugin/image import 금지.

/// 정규화(0.0~1.0, 원점 좌상단) 좌표계의 가림 영역.
class MaskRegion {
  final double left;
  final double top;
  final double width;
  final double height;

  /// 얼굴 자동 감지로 만든 영역인지.
  final bool isAuto;

  /// 처리 대상 여부. enabled 영역만 모자이크로 합성한다.
  final bool enabled;

  const MaskRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.isAuto = false,
    this.enabled = true,
  });

  double get right => left + width;
  double get bottom => top + height;

  MaskRegion copyWith({bool? enabled}) => MaskRegion(
    left: left,
    top: top,
    width: width,
    height: height,
    isAuto: isAuto,
    enabled: enabled ?? this.enabled,
  );

  @override
  bool operator ==(Object other) =>
      other is MaskRegion &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height &&
      other.isAuto == isAuto &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(left, top, width, height, isAuto, enabled);
}
