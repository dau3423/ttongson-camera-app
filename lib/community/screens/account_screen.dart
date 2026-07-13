import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../auth_service.dart';
import '../user_repository.dart';
import '../models/user_profile.dart';
import 'confirm_dialog.dart';

const _text = Color(0xFFF4F1EA);
const _muted = Color(0x80F4F1EA);

/// 내 프로필 — 프로필 편집(닉네임·사진), 로그아웃, 회원 탈퇴.
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
          autofocus: true,
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
    final ok = await showAppConfirm(
      context,
      icon: Icons.waving_hand,
      title: '로그아웃 할까요?',
      body: '다시 로그인하면 이어서 사용할 수 있어요.',
      confirmLabel: '로그아웃',
      destructive: true,
    );
    if (ok != true) return;
    await widget.auth.signOut();
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _withdraw() async {
    final ok = await showAppConfirm(
      context,
      icon: Icons.person_remove,
      title: '정말 탈퇴하시겠어요?',
      body: '다시 로그인하면 재가입할 수 있어요.',
      confirmLabel: '탈퇴',
      destructive: true,
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
      appBar: AppBar(title: const Text('내 프로필')),
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
          final initial = p.nickname.isNotEmpty
              ? p.nickname.characters.first
              : '?';
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // 앰버 커버 + 겹치는 원형 아바타
              SizedBox(
                height: 150,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 104,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFC107), Color(0xFFFFA000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _busy ? null : _changePhoto,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surfaceApp,
                              width: 4,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.surfaceCard,
                            backgroundImage: hasPhoto
                                ? NetworkImage(p.photoUrl!)
                                : null,
                            child: hasPhoto
                                ? null
                                : Text(
                                    initial,
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nickname,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.userId ?? '${p.loginType.name} 로그인',
                      style: const TextStyle(
                        fontFamily: AppFonts.mono,
                        color: _muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _tile(
                icon: Icons.edit_outlined,
                label: '닉네임 편집',
                onTap: () => _editNickname(p.nickname),
              ),
              _tile(
                icon: Icons.image_outlined,
                label: '프로필 사진 변경',
                onTap: _busy ? null : _changePhoto,
              ),
              _tile(
                icon: Icons.badge_outlined,
                label: '로그인 방식',
                trailing: Text(
                  p.loginType.name,
                  style: const TextStyle(color: _muted),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(0),
                  ),
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _withdraw,
                  child: const Text(
                    '회원 탈퇴',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: _muted),
      title: Text(label, style: const TextStyle(color: _text)),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : const Icon(Icons.chevron_right, color: _muted)),
      onTap: onTap,
    );
  }
}
