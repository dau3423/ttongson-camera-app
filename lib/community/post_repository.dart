// lib/community/post_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'models/post.dart';

/// Firestore /posts + Storage 접근. 판단 로직 없음.
class PostRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  PostRepository({FirebaseFirestore? db, FirebaseStorage? storage})
    : _db = db ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  /// 이미지를 Storage에 올리고 게시물 문서를 생성한다.
  Future<Post> createPost({
    required String uid,
    required String authorName,
    required File image,
    required String caption,
  }) async {
    final ref = _db.collection('posts').doc();
    final postId = ref.id;
    final storageRef = _storage.ref('post_images/$uid/$postId.jpg');
    await storageRef.putFile(
      image,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final imageUrl = await storageRef.getDownloadURL();
    final post = Post(
      id: postId,
      authorUid: uid,
      authorName: authorName,
      imageUrl: imageUrl,
      caption: caption,
    );
    await ref.set({
      ...post.toCreateMap(imageUrl: imageUrl),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return post;
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
  Future<void> toggleLike({required String postId, required String uid}) async {
    final ref = _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid);
    final snap = await ref.get();
    if (snap.exists) {
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

  Map<String, dynamic> _withDate(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    final ts = data['createdAt'];
    data['createdAt'] = ts is Timestamp ? ts.toDate() : null;
    return data;
  }
}
