// lib/community/post_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/shooting_mode.dart';
import 'models/post.dart';
import 'models/comment.dart';

/// Firestore /posts + Storage 접근. 판단 로직 없음.
class PostRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  PostRepository({FirebaseFirestore? db, FirebaseStorage? storage})
    : _db = db ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  /// 이미지 N장을 Storage에 병렬 업로드하고 게시물 문서를 생성한다(1~10장).
  /// 병렬(Future.wait)이라 네트워크 지연이 겹쳐 직렬보다 빠르며, 순서는 인덱스로 보존.
  Future<Post> createPost({
    required String uid,
    required String authorName,
    required List<File> images,
    required String caption,
    ShootingMode? mode,
  }) async {
    final ref = _db.collection('posts').doc();
    final postId = ref.id;
    final urls = await Future.wait([
      for (var i = 0; i < images.length; i++)
        _uploadPostImage(uid: uid, postId: postId, index: i, file: images[i]),
    ]);
    final post = Post(
      id: postId,
      authorUid: uid,
      authorName: authorName,
      imageUrls: urls,
      caption: caption,
      mode: mode,
    );
    await ref.set({
      ...post.toCreateMap(imageUrls: urls),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return post;
  }

  Future<String> _uploadPostImage({
    required String uid,
    required String postId,
    required int index,
    required File file,
  }) async {
    final ref = _storage.ref('post_images/$uid/${postId}_$index.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// 본인 게시물 삭제 — Storage 이미지(가능하면)와 Firestore 문서를 제거한다.
  /// 이미지 삭제 실패(이미 없음·URL 파싱 불가 등)는 무시하고 문서 삭제를 우선한다.
  /// 이미지 경로는 download URL에서 역참조해 구/신 저장 경로 모두 대응한다.
  Future<void> deletePost(Post post) async {
    await Future.wait([for (final url in post.imageUrls) _deleteByUrl(url)]);
    await _db.collection('posts').doc(post.id).delete();
  }

  Future<void> _deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // 이미 삭제됐거나 refFromURL로 열 수 없는 URL — 문서 삭제가 우선.
    }
  }

  /// 최신순 피드(숨김 제외).
  Stream<List<Post>> feed({int limit = 30}) {
    return _db
        .collection('posts')
        .where('hidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (q) => q.docs
              .map((d) => Post.fromData(d.id, _withDate(d.data())))
              .toList(),
        );
  }

  /// 좋아요 토글(문서 생성/삭제). likeCount는 함수가 관리.
  /// [liked]는 현재(토글 전) 상태 — get() 왕복 없이 바로 반영해 지연을 없앤다.
  Future<void> toggleLike({
    required String postId,
    required String uid,
    required bool liked,
  }) async {
    final ref = _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid);
    if (liked) {
      await ref.delete();
    } else {
      await ref.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }

  Stream<bool> likedByMe({required String postId, required String uid}) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists);
  }

  /// 게시물에 댓글을 추가한다. commentCount는 함수가 관리.
  Future<void> addComment({
    required String postId,
    required String uid,
    required String authorName,
    required String text,
    String? authorPhotoUrl,
  }) async {
    final comment = Comment(
      id: '',
      authorUid: uid,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      text: text,
    );
    await _db.collection('posts').doc(postId).collection('comments').add({
      ...comment.toCreateMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 댓글 목록(숨김 제외, 오래된 순).
  Stream<List<Comment>> comments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .where('hidden', isEqualTo: false)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (q) => q.docs
              .map((d) => Comment.fromData(d.id, _withDate(d.data())))
              .toList(),
        );
  }

  /// 댓글 삭제(본인 것만 — 규칙으로 강제).
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  /// 게시물 신고(대상별 1건, 문서 id=uid). reportCount/hidden은 함수가 관리.
  Future<void> reportPost({
    required String postId,
    required String uid,
    required String reason,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('reports')
        .doc(uid)
        .set({
          'reporterUid': uid,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// 댓글 신고(대상별 1건, 문서 id=uid).
  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String uid,
    required String reason,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('reports')
        .doc(uid)
        .set({
          'reporterUid': uid,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// 내가 신고한 게시물 id 집합(collectionGroup). 경로가 posts/{id}/reports/{uid}인 것.
  Stream<Set<String>> myReportedPostIds(String uid) {
    return _db
        .collectionGroup('reports')
        .where('reporterUid', isEqualTo: uid)
        .snapshots()
        .map((q) {
          final ids = <String>{};
          for (final d in q.docs) {
            final target = d.reference.parent.parent; // post 또는 comment 문서
            if (target != null && target.parent.id == 'posts') {
              ids.add(target.id);
            }
          }
          return ids;
        });
  }

  /// 내가 신고한 댓글 id 집합(collectionGroup). 경로가 .../comments/{id}/reports/{uid}인 것.
  Stream<Set<String>> myReportedCommentIds(String uid) {
    return _db
        .collectionGroup('reports')
        .where('reporterUid', isEqualTo: uid)
        .snapshots()
        .map((q) {
          final ids = <String>{};
          for (final d in q.docs) {
            final target = d.reference.parent.parent; // post 또는 comment 문서
            if (target != null && target.parent.id == 'comments') {
              ids.add(target.id);
            }
          }
          return ids;
        });
  }

  Map<String, dynamic> _withDate(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    final ts = data['createdAt'];
    data['createdAt'] = ts is Timestamp ? ts.toDate() : null;
    return data;
  }
}
