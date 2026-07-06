// lib/community/models/blocked_user.dart
// 순수 Dart — Flutter/plugin import 금지.

class BlockedUser {
  final String uid;
  final String name;
  const BlockedUser({required this.uid, required this.name});

  factory BlockedUser.fromData(String uid, Map<String, dynamic> data) =>
      BlockedUser(uid: uid, name: (data['blockedName'] as String?) ?? '');
}
