// lib/community/models/user_profile.dart
// 순수 Dart — Flutter/plugin import 금지.

enum LoginType { google, apple, kakao, email }

/// enum 이름이 곧 wire 문자열(google/apple/kakao/email).
LoginType parseLoginType(String? s) {
  switch (s) {
    case 'google':
      return LoginType.google;
    case 'apple':
      return LoginType.apple;
    case 'kakao':
      return LoginType.kakao;
    case 'email':
      return LoginType.email;
    default:
      return LoginType.google;
  }
}

/// 닉네임 유효성: 트림 후 1~20자.
bool isValidNickname(String nickname) {
  final n = nickname.trim().length;
  return n >= 1 && n <= 20;
}

/// 이메일 유효성: 공백 없는 `로컬@도메인.tld` 최소 형태.
bool isValidEmail(String email) {
  final e = email.trim();
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e);
}

/// 비밀번호 유효성: 8자 이상(Firebase 이메일 인증 최소치).
bool isValidPassword(String password) => password.length >= 8;

/// 커뮤니티 사용자 프로필(/users/{uid}).
class UserProfile {
  final String uid;
  final String? userId; // 이메일(없을 수 있음)
  final String nickname;
  final LoginType loginType;
  final DateTime? createdAt;
  final String? photoUrl;
  final DateTime? deleteDate; // 설정되면 탈퇴(소프트) 상태
  const UserProfile({
    required this.uid,
    required this.nickname,
    required this.loginType,
    this.userId,
    this.createdAt,
    this.photoUrl,
    this.deleteDate,
  });

  bool get isWithdrawn => deleteDate != null;

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  /// deleteDate는 탈퇴 시에만 설정하므로 생성 맵에 미포함.
  Map<String, dynamic> toCreateMap() => {
    'uid': uid,
    'userId': userId,
    'nickname': nickname,
    'loginType': loginType.name,
    'photoUrl': photoUrl,
  };

  /// Firestore 데이터(createdAt·deleteDate는 이미 DateTime으로 변환된 상태)에서 복원.
  factory UserProfile.fromData(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      userId: data['userId'] as String?,
      nickname: (data['nickname'] as String?) ?? '',
      loginType: parseLoginType(data['loginType'] as String?),
      createdAt: data['createdAt'] as DateTime?,
      photoUrl: data['photoUrl'] as String?,
      deleteDate: data['deleteDate'] as DateTime?,
    );
  }
}
