import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/user_profile.dart';

void main() {
  test('parseLoginType: 유효값 파싱, 이상/누락은 google 폴백', () {
    expect(parseLoginType('google'), LoginType.google);
    expect(parseLoginType('apple'), LoginType.apple);
    expect(parseLoginType('kakao'), LoginType.kakao);
    expect(parseLoginType(null), LoginType.google);
    expect(parseLoginType('xxx'), LoginType.google);
  });

  test('toCreateMap: 필드 매핑, loginType은 소문자 이름, createdAt 제외', () {
    const p = UserProfile(
      uid: 'u1',
      userId: 'a@b.com',
      nickname: '귀여운너구리1',
      loginType: LoginType.apple,
      photoUrl: 'http://x/y.png',
    );
    final m = p.toCreateMap();
    expect(m['uid'], 'u1');
    expect(m['userId'], 'a@b.com');
    expect(m['nickname'], '귀여운너구리1');
    expect(m['loginType'], 'apple');
    expect(m['photoUrl'], 'http://x/y.png');
    expect(m.containsKey('createdAt'), isFalse);
  });

  test('userId/photoUrl 은 null 허용', () {
    const p = UserProfile(
      uid: 'u1',
      nickname: '느긋한수달2',
      loginType: LoginType.kakao,
    );
    final m = p.toCreateMap();
    expect(m['userId'], isNull);
    expect(m['photoUrl'], isNull);
    expect(m['loginType'], 'kakao');
  });

  test('fromData: 복원(누락 필드는 안전한 기본값)', () {
    final now = DateTime(2026, 7, 5);
    final p = UserProfile.fromData('u9', {
      'userId': null,
      'nickname': '씩씩한판다7',
      'loginType': 'google',
      'createdAt': now,
      'photoUrl': null,
    });
    expect(p.uid, 'u9');
    expect(p.userId, isNull);
    expect(p.nickname, '씩씩한판다7');
    expect(p.loginType, LoginType.google);
    expect(p.createdAt, now);
    expect(p.photoUrl, isNull);
  });

  test('fromData: deleteDate 복원 + isWithdrawn', () {
    final active = UserProfile.fromData('u', {'nickname': 'n'});
    expect(active.deleteDate, isNull);
    expect(active.isWithdrawn, isFalse);

    final now = DateTime(2026, 7, 7);
    final gone = UserProfile.fromData('u', {
      'nickname': 'n',
      'deleteDate': now,
    });
    expect(gone.deleteDate, now);
    expect(gone.isWithdrawn, isTrue);
  });

  test('isValidNickname: 트림 후 1~20자', () {
    expect(isValidNickname(''), isFalse);
    expect(isValidNickname('   '), isFalse);
    expect(isValidNickname('a'), isTrue);
    expect(isValidNickname('  가  '), isTrue);
    expect(isValidNickname('a' * 20), isTrue);
    expect(isValidNickname('a' * 21), isFalse);
  });
}
