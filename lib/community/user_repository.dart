// lib/community/user_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'models/user_profile.dart';
import 'nickname_generator.dart';
import 'mask_processor.dart';

/// Firestore /users + 프로필 사진 Storage 접근. 판단 로직 없음.
class UserRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  UserRepository({FirebaseFirestore? db, FirebaseStorage? storage})
    : _db = db ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  /// Firestore 원시 데이터의 Timestamp 필드(createdAt·deleteDate)를 DateTime으로.
  Map<String, dynamic> _toModelData(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    for (final key in const ['createdAt', 'deleteDate']) {
      final ts = data[key];
      if (ts is Timestamp) data[key] = ts.toDate();
    }
    return data;
  }

  /// /users/{uid}가 없으면 랜덤 닉네임으로 생성, 있으면 기존 프로필을 반환한다.
  Future<UserProfile> ensureProfile({
    required User user,
    required LoginType loginType,
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    return _db.runTransaction<UserProfile>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        return UserProfile.fromData(user.uid, _toModelData(snap.data()!));
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
    return UserProfile.fromData(uid, _toModelData(snap.data()!));
  }

  /// /users/{uid} 프로필 스트림(편집 즉시 반영).
  Stream<UserProfile?> watchProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromData(uid, _toModelData(snap.data()!));
    });
  }

  /// 전달된 필드만 부분 업데이트.
  Future<void> updateProfile({
    required String uid,
    String? nickname,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (data.isEmpty) return;
    await _db.collection('users').doc(uid).update(data);
  }

  /// 프로필 사진을 축소·EXIF 제거 후 업로드하고 다운로드 URL을 반환한다.
  Future<String> uploadProfilePhoto({
    required String uid,
    required File image,
  }) async {
    final processed = await applyMasks(image, const []);
    final ref = _storage.ref('profile_images/$uid/photo.jpg');
    await ref.putFile(processed, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// 소프트 탈퇴: deleteDate 설정.
  Future<void> withdraw(String uid) async {
    await _db.collection('users').doc(uid).update({
      'deleteDate': FieldValue.serverTimestamp(),
    });
  }

  /// 재가입: deleteDate 제거.
  Future<void> rejoin(String uid) async {
    await _db.collection('users').doc(uid).update({
      'deleteDate': FieldValue.delete(),
    });
  }
}
