import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/cloud/composition_advice.dart';
import 'package:ttongson_camera/cloud/target_alignment.dart';

void main() {
  test('완전히 겹치면 score≈1, aligned=true, dx=dy=0', () {
    const current = PersonBox(left: 0.3, top: 0.3, width: 0.4, height: 0.4);
    const target = TargetBox(x: 0.3, y: 0.3, width: 0.4, height: 0.4);
    final r = computeAlignment(current, target);
    expect(r.score, closeTo(1.0, 0.0001));
    expect(r.aligned, isTrue);
    expect(r.dx, closeTo(0.0, 0.0001));
    expect(r.dy, closeTo(0.0, 0.0001));
  });

  test('완전히 떨어져 있으면 score=0, aligned=false, dx/dy는 목표 방향', () {
    const current = PersonBox(left: 0.0, top: 0.0, width: 0.2, height: 0.2);
    const target = TargetBox(x: 0.6, y: 0.6, width: 0.2, height: 0.2);
    final r = computeAlignment(current, target);
    expect(r.score, 0.0);
    expect(r.aligned, isFalse);
    expect(r.dx, closeTo(0.6, 0.0001)); // 0.7 - 0.1
    expect(r.dy, closeTo(0.6, 0.0001));
  });

  test('부분 겹침이면 0<score<1', () {
    const current = PersonBox(left: 0.3, top: 0.3, width: 0.4, height: 0.4);
    const target = TargetBox(x: 0.5, y: 0.3, width: 0.4, height: 0.4);
    final r = computeAlignment(current, target);
    // 교집합 0.2*0.4=0.08, 합집합 0.16+0.16-0.08=0.24 → IoU≈0.333
    expect(r.score, closeTo(0.3333, 0.001));
    expect(r.aligned, isFalse);
    expect(r.dx, closeTo(0.2, 0.0001)); // 0.7 - 0.5
    expect(r.dy, closeTo(0.0, 0.0001));
  });
}
