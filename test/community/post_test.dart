import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/post.dart';

void main() {
  test('toCreateMap: imageUrls와 레거시 imageUrl(첫 장) 병기, 순서 보존', () {
    const p = Post(
      id: '',
      authorUid: 'u1',
      authorName: '귀여운너구리1',
      imageUrls: ['https://x/0.jpg', 'https://x/1.jpg'],
      caption: '역광에서 살짝 밑에서',
    );
    final m = p.toCreateMap(imageUrls: ['https://x/0.jpg', 'https://x/1.jpg']);
    expect(m['imageUrls'], ['https://x/0.jpg', 'https://x/1.jpg']);
    expect(m['imageUrl'], 'https://x/0.jpg'); // 레거시 = 첫 장
    expect(m['authorUid'], 'u1');
    expect(m['likeCount'], 0);
    expect(m['reportCount'], 0);
    expect(m['hidden'], false);
    expect(m.containsKey('createdAt'), isFalse);
  });

  test('coverUrl: 첫 장', () {
    const p = Post(
      id: 'p',
      authorUid: 'u',
      authorName: 'n',
      imageUrls: ['a', 'b', 'c'],
      caption: 'c',
    );
    expect(p.coverUrl, 'a');
  });

  test('fromData: imageUrls 리스트 우선', () {
    final p = Post.fromData('post9', {
      'authorUid': 'u2',
      'authorName': '느긋한수달2',
      'imageUrls': ['https://a/0.jpg', 'https://a/1.jpg'],
      'imageUrl': 'https://a/0.jpg',
      'caption': '가운데 정렬',
      'likeCount': 5,
      'commentCount': 2,
    });
    expect(p.imageUrls, ['https://a/0.jpg', 'https://a/1.jpg']);
    expect(p.coverUrl, 'https://a/0.jpg');
    expect(p.likeCount, 5);
    expect(p.commentCount, 2);
  });

  test('fromData: imageUrls 없으면 구 imageUrl 폴백(1장)', () {
    final p = Post.fromData('p', {
      'authorUid': 'u',
      'authorName': 'n',
      'imageUrl': 'https://a/b.jpg',
      'caption': 'c',
    });
    expect(p.imageUrls, ['https://a/b.jpg']);
    expect(p.coverUrl, 'https://a/b.jpg');
  });

  test('fromData: 둘 다 없으면 빈 리스트, coverUrl 빈 문자열', () {
    final p = Post.fromData('p', {
      'authorUid': 'u',
      'authorName': 'n',
      'caption': 'c',
    });
    expect(p.imageUrls, isEmpty);
    expect(p.coverUrl, '');
  });
}
