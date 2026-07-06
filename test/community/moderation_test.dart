import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/moderation.dart';

class _Item {
  final String id;
  final String author;
  const _Item(this.id, this.author);
}

void main() {
  const items = [_Item('p1', 'a'), _Item('p2', 'b'), _Item('p3', 'c')];

  List<_Item> run(Set<String> blocked, Set<String> reported) => visibleItems(
    items,
    authorUidOf: (i) => i.author,
    idOf: (i) => i.id,
    blockedAuthors: blocked,
    reportedIds: reported,
  );

  test('빈 집합이면 전부 표시', () {
    expect(run({}, {}).length, 3);
  });

  test('차단한 작성자 제외', () {
    expect(run({'b'}, {}).map((i) => i.id).toList(), ['p1', 'p3']);
  });

  test('내가 신고한 id 제외', () {
    expect(run({}, {'p1'}).map((i) => i.id).toList(), ['p2', 'p3']);
  });

  test('차단+신고 둘 다 제외', () {
    expect(run({'c'}, {'p1'}).map((i) => i.id).toList(), ['p2']);
  });
}
