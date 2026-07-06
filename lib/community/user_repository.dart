// lib/community/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user_profile.dart';
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
}
