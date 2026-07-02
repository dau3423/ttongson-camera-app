/// 정규화(0.0~1.0) 좌표계의 인물 경계 상자. 원점은 좌상단.
class PersonBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const PersonBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}
