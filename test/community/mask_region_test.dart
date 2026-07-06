import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/mask_region.dart';

void main() {
  test('기본값: isAuto false, enabled true, right/bottom 계산', () {
    const r = MaskRegion(left: 0.1, top: 0.2, width: 0.3, height: 0.4);
    expect(r.isAuto, isFalse);
    expect(r.enabled, isTrue);
    expect(r.right, closeTo(0.4, 1e-9));
    expect(r.bottom, closeTo(0.6, 1e-9));
  });

  test('copyWith(enabled) 은 나머지 필드를 보존', () {
    const r = MaskRegion(
      left: 0.1,
      top: 0.2,
      width: 0.3,
      height: 0.4,
      isAuto: true,
    );
    final off = r.copyWith(enabled: false);
    expect(off.enabled, isFalse);
    expect(off.isAuto, isTrue);
    expect(off.left, 0.1);
    expect(off.width, 0.3);
  });

  test('동등성: 모든 필드가 같으면 ==', () {
    const a = MaskRegion(
      left: 0,
      top: 0,
      width: 0.5,
      height: 0.5,
      isAuto: true,
    );
    const b = MaskRegion(
      left: 0,
      top: 0,
      width: 0.5,
      height: 0.5,
      isAuto: true,
    );
    const c = MaskRegion(left: 0, top: 0, width: 0.5, height: 0.5);
    expect(a, equals(b));
    expect(a == c, isFalse);
  });
}
