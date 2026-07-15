// lib/community/models/post.dart
// 순수 Dart — Flutter/plugin import 금지.
import '../../models/shooting_mode.dart';

class Post {
  final String id;
  final String authorUid;
  final String authorName;
  final String imageUrl;
  final String caption;
  final ShootingMode? mode; // 촬영 모드(인물/자연/사물). 과거 글은 null.
  final DateTime? createdAt;
  final int likeCount;
  final int commentCount;
  const Post({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.imageUrl,
    required this.caption,
    this.mode,
    this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  Map<String, dynamic> toCreateMap({required String imageUrl}) => {
    'authorUid': authorUid,
    'authorName': authorName,
    'imageUrl': imageUrl,
    'caption': caption,
    'mode': mode?.wire,
    'likeCount': 0,
    'commentCount': 0,
    'reportCount': 0,
    'hidden': false,
  };

  factory Post.fromData(String id, Map<String, dynamic> data) => Post(
    id: id,
    authorUid: (data['authorUid'] as String?) ?? '',
    authorName: (data['authorName'] as String?) ?? '',
    imageUrl: (data['imageUrl'] as String?) ?? '',
    caption: (data['caption'] as String?) ?? '',
    mode: ShootingModeWire.fromWire(data['mode'] as String?),
    createdAt: data['createdAt'] as DateTime?,
    likeCount: (data['likeCount'] as int?) ?? 0,
    commentCount: (data['commentCount'] as int?) ?? 0,
  );
}
