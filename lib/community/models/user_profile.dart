// lib/community/models/user_profile.dart
// 순수 Dart — Flutter/plugin import 금지.

enum LoginType { google, apple, kakao }

/// enum 이름이 곧 wire 문자열(google/apple/kakao).
LoginType parseLoginType(String? s) {
  switch (s) {
    case 'google':
      return LoginType.google;
    case 'apple':
      return LoginType.apple;
    case 'kakao':
      return LoginType.kakao;
    default:
      return LoginType.google;
  }
}

/// 커뮤니티 사용자 프로필(/users/{uid}).
class UserProfile {
  final String uid;
  final String? userId; // 이메일(없을 수 있음)
  final String nickname;
  final LoginType loginType;
  final DateTime? createdAt;
  final String? photoUrl;
  const UserProfile({
    required this.uid,
    required this.nickname,
    required this.loginType,
    this.userId,
    this.createdAt,
    this.photoUrl,
  });

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  Map<String, dynamic> toCreateMap() => {
    'uid': uid,
    'userId': userId,
    'nickname': nickname,
    'loginType': loginType.name,
    'photoUrl': photoUrl,
  };

  /// Firestore 데이터(createdAt은 이미 DateTime으로 변환된 상태)에서 복원.
  factory UserProfile.fromData(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      userId: data['userId'] as String?,
      nickname: (data['nickname'] as String?) ?? '',
      loginType: parseLoginType(data['loginType'] as String?),
      createdAt: data['createdAt'] as DateTime?,
      photoUrl: data['photoUrl'] as String?,
    );
  }
}
