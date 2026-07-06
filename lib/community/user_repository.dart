// lib/community/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user_profile.dart';
import 'models/blocked_user.dart';
import 'nickname_generator.dart';

/// Firestore /users 접근. 판단 로직 없음(생성/조회만).
class UserRepository {
  final FirebaseFirestore _db;
  UserRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  /// /users/{uid}가 없으면 랜덤 닉네임으로 생성, 있으면 기존 프로필을 반환한다.
  Future<UserProfile> ensureProfile({
    required User user,
    required LoginType loginType,
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    return _db.runTransaction<UserProfile>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.data()!);
        final ts = data['createdAt'];
        data['createdAt'] = ts is Timestamp ? ts.toDate() : null;
        return UserProfile.fromData(user.uid, data);
      }
      final profile = UserProfile(
        uid: user.uid,
        userId: user.email,
        nickname: generateNickname(),
        loginType: loginType,
        photoUrl: user.photoURL,
      );
      tx.set(ref, {
        ...profile.toCreateMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return profile;
    });
  }

  /// /users/{uid} 프로필을 조회한다. 없으면 null.
  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    final data = Map<String, dynamic>.from(snap.data()!);
    final ts = data['createdAt'];
    data['createdAt'] = ts is Timestamp ? ts.toDate() : null;
    return UserProfile.fromData(uid, data);
  }

  /// 사용자 차단(내 blocks/{uid}/blocked/{blockedUid} 문서 생성).
  Future<void> blockUser({
    required String uid,
    required String blockedUid,
    required String blockedName,
  }) async {
    await _db
        .collection('blocks')
        .doc(uid)
        .collection('blocked')
        .doc(blockedUid)
        .set({
          'blockedName': blockedName,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// 차단 해제(문서 삭제).
  Future<void> unblockUser({
    required String uid,
    required String blockedUid,
  }) async {
    await _db
        .collection('blocks')
        .doc(uid)
        .collection('blocked')
        .doc(blockedUid)
        .delete();
  }

  /// 내가 차단한 uid 집합(필터용).
  Stream<Set<String>> blockedUids(String uid) {
    return _db
        .collection('blocks')
        .doc(uid)
        .collection('blocked')
        .snapshots()
        .map((q) => q.docs.map((d) => d.id).toSet());
  }

  /// 내가 차단한 사용자 목록(목록 화면용, 최신순).
  Stream<List<BlockedUser>> blockedList(String uid) {
    return _db
        .collection('blocks')
        .doc(uid)
        .collection('blocked')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (q) =>
              q.docs.map((d) => BlockedUser.fromData(d.id, d.data())).toList(),
        );
  }
}
