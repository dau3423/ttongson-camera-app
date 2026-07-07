import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth_service.dart';
import '../user_repository.dart';
import '../models/user_profile.dart';

/// 내 계정 — 프로필 편집(닉네임·사진), 로그아웃, 회원 탈퇴.
class AccountScreen extends StatefulWidget {
  final AuthService auth;
  final UserRepository users;
  AccountScreen({super.key, required this.auth, UserRepository? users})
    : users = users ?? UserRepository();

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;
  String get _uid => widget.auth.currentUser?.uid ?? '';

  Future<void> _changePhoto() async {
    if (_busy) return;
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await widget.users.uploadProfilePhoto(
        uid: _uid,
        image: File(x.path),
      );
      await widget.users.updateProfile(uid: _uid, photoUrl: url);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('사진 변경에 실패했어요')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNickname(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('닉네임 편집'),
        content: TextField(
          controller: controller,
          maxLength: 20,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    final trimmed = result.trim();
    if (!isValidNickname(trimmed)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임은 1~20자로 입력해 주세요')));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.users.updateProfile(uid: _uid, nickname: trimmed);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('닉네임 변경에 실패했어요')));
    }
  }

  Future<void> _logout() async {
    await widget.auth.signOut();
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('정말 탈퇴하시겠어요? 다시 로그인하면 재가입할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.auth.withdraw();
      await widget.auth.signOut();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('탈퇴에 실패했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 계정')),
      body: StreamBuilder<UserProfile?>(
        stream: widget.users.watchProfile(_uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('불러오지 못했어요'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) {
            return const Center(child: Text('프로필이 없어요'));
          }
          final hasPhoto = p.photoUrl != null && p.photoUrl!.isNotEmpty;
          return ListView(
            children: [
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : _changePhoto,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: hasPhoto
                        ? NetworkImage(p.photoUrl!)
                        : null,
                    child: hasPhoto ? null : const Icon(Icons.person, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _changePhoto,
                  child: const Text('사진 변경'),
                ),
              ),
              ListTile(
                title: const Text('닉네임'),
                subtitle: Text(p.nickname),
                trailing: const Icon(Icons.edit, size: 20),
                onTap: () => _editNickname(p.nickname),
              ),
              ListTile(
                title: const Text('로그인'),
                subtitle: Text(p.loginType.name),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                onTap: _logout,
              ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text('회원 탈퇴', style: TextStyle(color: Colors.red)),
                onTap: _withdraw,
              ),
            ],
          );
        },
      ),
    );
  }
}
