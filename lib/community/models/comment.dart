// lib/community/models/comment.dart
// 순수 Dart — Flutter/plugin import 금지.

class Comment {
  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime? createdAt;
  const Comment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    this.createdAt,
  });

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  /// reportCount/hidden은 함수 전용이지만 생성 기본값(0/false)은 규칙이 요구한다.
  Map<String, dynamic> toCreateMap() => {
    'authorUid': authorUid,
    'authorName': authorName,
    'text': text,
    'reportCount': 0,
    'hidden': false,
  };

  factory Comment.fromData(String id, Map<String, dynamic> data) => Comment(
    id: id,
    authorUid: (data['authorUid'] as String?) ?? '',
    authorName: (data['authorName'] as String?) ?? '',
    text: (data['text'] as String?) ?? '',
    createdAt: data['createdAt'] as DateTime?,
  );
}
