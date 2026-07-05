// lib/analysis/box_normalize.dart
// 순수 Dart — Flutter/plugin import 금지.
import '../models/person_box.dart';

/// 회전을 반영해 '똑바로 세운' 이미지 크기(w,h)를 돌려준다.
/// ML Kit은 metadata.rotation으로 세운 좌표계의 박스를 반환하므로,
/// 정규화도 반드시 이 세운 크기 기준이어야 한다(90/270에서 폭·높이가 뒤바뀜).
({double w, double h}) uprightSize(int imgW, int imgH, int rotationDegrees) {
  final rotated = rotationDegrees == 90 || rotationDegrees == 270;
  return (
    w: (rotated ? imgH : imgW).toDouble(),
    h: (rotated ? imgW : imgH).toDouble(),
  );
}

/// 픽셀 좌표(세운 좌표계) 박스를 정규화 [PersonBox](0~1)로 변환한다.
PersonBox normalizeBox(
  double left,
  double top,
  double width,
  double height,
  int imgW,
  int imgH,
  int rotationDegrees,
) {
  final s = uprightSize(imgW, imgH, rotationDegrees);
  return PersonBox(
    left: (left / s.w).clamp(0.0, 1.0),
    top: (top / s.h).clamp(0.0, 1.0),
    width: (width / s.w).clamp(0.0, 1.0),
    height: (height / s.h).clamp(0.0, 1.0),
  );
}
