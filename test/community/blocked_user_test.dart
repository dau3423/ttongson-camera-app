import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/blocked_user.dart';

void main() {
  test('fromData: blockedName을 name으로', () {
    final b = BlockedUser.fromData('u1', {'blockedName': '귀여운너구리1'});
    expect(b.uid, 'u1');
    expect(b.name, '귀여운너구리1');
  });

  test('fromData: 이름 누락 시 빈 문자열', () {
    final b = BlockedUser.fromData('u2', {});
    expect(b.uid, 'u2');
    expect(b.name, '');
  });
}
