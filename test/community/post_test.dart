import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/post.dart';

void main() {
  test('toCreateMap: 카운터는 0, hidden false, createdAt 제외', () {
    const p = Post(
      id: '',
      authorUid: 'u1',
      authorName: '귀여운너구리1',
      imageUrl: 'https://x/y.jpg',
      caption: '역광에서 살짝 밑에서',
    );
    final m = p.toCreateMap(imageUrl: 'https://x/y.jpg');
    expect(m['authorUid'], 'u1');
    expect(m['authorName'], '귀여운너구리1');
    expect(m['imageUrl'], 'https://x/y.jpg');
    expect(m['caption'], '역광에서 살짝 밑에서');
    expect(m['likeCount'], 0);
    expect(m['commentCount'], 0);
    expect(m['reportCount'], 0);
    expect(m['hidden'], false);
    expect(m.containsKey('createdAt'), isFalse);
  });

  test('fromData: 복원(createdAt DateTime, 카운터 유지)', () {
    final now = DateTime(2026, 7, 6);
    final p = Post.fromData('post9', {
      'authorUid': 'u2',
      'authorName': '느긋한수달2',
      'imageUrl': 'https://a/b.jpg',
      'caption': '가운데 정렬',
      'createdAt': now,
      'likeCount': 5,
      'commentCount': 2,
    });
    expect(p.id, 'post9');
    expect(p.authorName, '느긋한수달2');
    expect(p.caption, '가운데 정렬');
    expect(p.createdAt, now);
    expect(p.likeCount, 5);
    expect(p.commentCount, 2);
  });

  test('fromData: 카운터 누락 시 0', () {
    final p = Post.fromData('p', {
      'authorUid': 'u',
      'authorName': 'n',
      'imageUrl': 'i',
      'caption': 'c',
    });
    expect(p.likeCount, 0);
    expect(p.commentCount, 0);
  });
}
