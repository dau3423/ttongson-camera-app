// lib/community/models/post.dart
// 순수 Dart — Flutter/plugin import 금지.
import '../../models/shooting_mode.dart';

class Post {
  final String id;
  final String authorUid;
  final String authorName;
  final List<String> imageUrls;
  final String caption;
  final ShootingMode? mode; // 촬영 모드(인물/자연/사물). 과거 글은 null.
  final DateTime? createdAt;
  final int likeCount;
  final int commentCount;
  const Post({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.imageUrls,
    required this.caption,
    this.mode,
    this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  /// 피드 커버·레거시 필드용 첫 이미지. 비어 있으면 ''.
  String get coverUrl => imageUrls.isNotEmpty ? imageUrls.first : '';

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  /// imageUrls(정식)와 imageUrl(=첫 장, 아직 업데이트 안 한 클라 호환)을 함께 기록.
  Map<String, dynamic> toCreateMap({required List<String> imageUrls}) => {
    'authorUid': authorUid,
    'authorName': authorName,
    'imageUrls': imageUrls,
    'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
    'caption': caption,
    'mode': mode?.wire,
    'likeCount': 0,
    'commentCount': 0,
    'reportCount': 0,
    'hidden': false,
  };

  factory Post.fromData(String id, Map<String, dynamic> data) {
    final raw = data['imageUrls'];
    final List<String> urls;
    if (raw is List) {
      urls = raw.whereType<String>().where((s) => s.isNotEmpty).toList();
    } else {
      final single = (data['imageUrl'] as String?) ?? '';
      urls = single.isEmpty ? const [] : [single];
    }
    return Post(
      id: id,
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      imageUrls: urls,
      caption: (data['caption'] as String?) ?? '',
      mode: ShootingModeWire.fromWire(data['mode'] as String?),
      createdAt: data['createdAt'] as DateTime?,
      likeCount: (data['likeCount'] as int?) ?? 0,
      commentCount: (data['commentCount'] as int?) ?? 0,
    );
  }
}
