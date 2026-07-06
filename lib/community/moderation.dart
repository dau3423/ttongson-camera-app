// lib/community/moderation.dart
// 순수 Dart — Flutter/plugin import 금지.

/// 차단한 작성자 또는 내가 신고한 항목을 제외한 리스트를 반환한다.
/// 피드(Post)·댓글(Comment) 공용.
List<T> visibleItems<T>(
  List<T> items, {
  required String Function(T) authorUidOf,
  required String Function(T) idOf,
  required Set<String> blockedAuthors,
  required Set<String> reportedIds,
}) {
  return items
      .where(
        (it) =>
            !blockedAuthors.contains(authorUidOf(it)) &&
            !reportedIds.contains(idOf(it)),
      )
      .toList();
}
