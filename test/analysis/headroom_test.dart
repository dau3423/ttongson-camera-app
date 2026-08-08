import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/analysis/headroom.dart';

PersonBox boxWithTop(double top) =>
    PersonBox(left: 0.3, top: top, width: 0.4, height: 0.5);

void main() {
  test('머리 공간이 너무 좁으면 카메라를 올리라고 안내', () {
    final a = computeHeadroom(boxWithTop(0.01));
    expect(a.ratio, closeTo(0.01, 0.0001));
    expect(a.hint, HeadroomHint.raiseCamera);
  });

  test('머리 공간이 너무 넓으면 카메라를 내리라고 안내', () {
    final a = computeHeadroom(boxWithTop(0.30));
    expect(a.hint, HeadroomHint.lowerCamera);
  });

  test('적정 범위면 힌트 없음', () {
    final a = computeHeadroom(boxWithTop(0.10));
    expect(a.hint, HeadroomHint.none);
  });
}
