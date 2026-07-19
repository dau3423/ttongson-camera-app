import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/describe_advisor.dart';

void main() {
  test('서버 결과 맵을 PhotoDescription으로 파싱', () {
    final d = photoDescriptionFromResult({
      'name': '노을 커피',
      'tags': ['커피', '노을'],
    });
    expect(d.name, '노을 커피');
    expect(d.tags, ['커피', '노을']);
  });

  test('name 비문자열·tags 비배열이면 방어', () {
    final d = photoDescriptionFromResult({'name': 3, 'tags': 'no'});
    expect(d.name, '');
    expect(d.tags, isEmpty);
  });

  test('tags 안의 비문자열은 제거', () {
    final d = photoDescriptionFromResult({
      'name': 'x',
      'tags': ['a', 5, 'b'],
    });
    expect(d.tags, ['a', 'b']);
  });
}
