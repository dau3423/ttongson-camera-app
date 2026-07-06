import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/comment.dart';

void main() {
  test('toCreateMap: reportCount 0, hidden false, createdAt 제외', () {
    const c = Comment(
      id: '',
      authorUid: 'u1',
      authorName: '귀여운너구리1',
      text: '구도 좋네요',
    );
    final m = c.toCreateMap();
    expect(m['authorUid'], 'u1');
    expect(m['authorName'], '귀여운너구리1');
    expect(m['text'], '구도 좋네요');
    expect(m['reportCount'], 0);
    expect(m['hidden'], false);
    expect(m.containsKey('createdAt'), isFalse);
  });

  test('fromData: 복원(createdAt DateTime)', () {
    final now = DateTime(2026, 7, 6);
    final c = Comment.fromData('c9', {
      'authorUid': 'u2',
      'authorName': '느긋한수달2',
      'text': '역광이 멋져요',
      'createdAt': now,
    });
    expect(c.id, 'c9');
    expect(c.authorName, '느긋한수달2');
    expect(c.text, '역광이 멋져요');
    expect(c.createdAt, now);
  });

  test('fromData: 누락 필드는 안전한 기본값', () {
    final c = Comment.fromData('c', {});
    expect(c.authorUid, '');
    expect(c.text, '');
    expect(c.createdAt, isNull);
  });
}
