import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/analysis/crop.dart';

void main() {
  test('여백 안에 있으면 잘림 없음', () {
    final w = detectCrop(
        const PersonBox(left: 0.2, top: 0.1, width: 0.5, height: 0.7));
    expect(w.any, isFalse);
    expect(w.message, '');
  });

  test('상단에 닿으면 위 잘림 감지', () {
    final w = detectCrop(
        const PersonBox(left: 0.2, top: 0.0, width: 0.5, height: 0.7));
    expect(w.top, isTrue);
    expect(w.message, contains('위'));
  });

  test('여러 변이 잘리면 메시지에 모두 포함', () {
    final w = detectCrop(
        const PersonBox(left: 0.0, top: 0.0, width: 1.0, height: 1.0));
    expect(w.top && w.bottom && w.left && w.right, isTrue);
    expect(w.message, contains('위'));
    expect(w.message, contains('아래'));
  });
}
