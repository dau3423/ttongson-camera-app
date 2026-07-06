import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../user_repository.dart';
import '../models/blocked_user.dart';

/// 내가 차단한 사용자 목록 + 해제.
class BlockedUsersScreen extends StatelessWidget {
  final AuthService auth;
  final UserRepository users;
  BlockedUsersScreen({super.key, required this.auth, UserRepository? users})
    : users = users ?? UserRepository();

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('차단한 사용자')),
      body: StreamBuilder<List<BlockedUser>>(
        stream: users.blockedList(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('불러오지 못했어요'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('차단한 사용자가 없어요'));
          }
          return ListView(
            children: [
              for (final b in items)
                ListTile(
                  title: Text(b.name),
                  trailing: TextButton(
                    onPressed: () =>
                        users.unblockUser(uid: uid, blockedUid: b.uid),
                    child: const Text('차단 해제'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
