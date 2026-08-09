import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import 'package:ttongson_camera/l10n/app_localizations.dart';
import '../auth_service.dart';
import '../user_repository.dart';
import '../models/user_profile.dart';
import '../theme/community_theme.dart';
import '../theme/community_theme_controller.dart';
import 'blocked_users_screen.dart';
import 'confirm_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    // 로그인했는데 프로필 문서가 없으면(로그인 시 생성 누락) 진입 시 생성.
    // watchProfile 스트림이 생성 즉시 반영한다. 실패는 조용히 무시(화면은 계속 동작).
    widget.auth.ensureMyProfile().catchError((_) => null);
  }

  Future<void> _changePhoto() async {
    if (_busy) return;
    final l = AppLocalizations.of(context)!;
    // 픽업 단계에서 축소·JPEG 근접 형식으로 받아 디코딩 실패(HEIC 등) 여지를 줄인다.
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (x == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await widget.users.uploadProfilePhoto(
        uid: _uid,
        image: File(x.path),
      );
      await widget.users.updateProfile(uid: _uid, photoUrl: url);
    } catch (e, st) {
      // 원인(권한/디코딩 등)을 파악할 수 있게 실제 에러를 노출한다.
      debugPrint('프로필 사진 변경 실패: $e\n$st');
      messenger.showSnackBar(
        SnackBar(content: Text(l.accountPhotoChangeFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNickname(String current) async {
    final l = AppLocalizations.of(context)!;
    // 컨트롤러는 다이얼로그가 자기 State.dispose에서 정리한다(닫힘 애니메이션 중
    // dispose로 인한 'used after disposed' 방지).
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameEditDialog(initial: current),
    );
    if (result == null || !mounted) return;
    final trimmed = result.trim();
    if (!isValidNickname(trimmed)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.accountNicknameInvalid)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.users.updateProfile(uid: _uid, nickname: trimmed);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.accountNicknameChangeFailed)),
      );
    }
  }

  Future<void> _logout() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showAppConfirm(
      context,
      icon: Icons.waving_hand,
      title: l.accountLogoutTitle,
      body: l.accountLogoutBody,
      confirmLabel: l.accountLogoutConfirm,
      destructive: true,
    );
    if (ok != true) return;
    await widget.auth.signOut();
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _withdraw() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showAppConfirm(
      context,
      icon: Icons.person_remove,
      title: l.accountWithdrawTitle,
      body: l.accountWithdrawBody,
      confirmLabel: l.accountWithdrawConfirm,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.auth.withdraw();
      await widget.auth.signOut();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.accountWithdrawFailed)));
    }
  }

  static String _themeModeLabel(CommunityThemeMode m, AppLocalizations l) {
    switch (m) {
      case CommunityThemeMode.system:
        return l.accountThemeSystem;
      case CommunityThemeMode.light:
        return l.accountThemeLight;
      case CommunityThemeMode.dark:
        return l.accountThemeDark;
    }
  }

  Future<void> _pickThemeMode() async {
    final l = AppLocalizations.of(context)!;
    final controller = CommunityTheme.controllerOf(context);
    final selected = await showModalBottomSheet<CommunityThemeMode>(
      context: context,
      builder: (sheetContext) {
        final current = controller.mode;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.accountThemePickerTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              RadioGroup<CommunityThemeMode>(
                groupValue: current,
                onChanged: (v) => Navigator.pop(sheetContext, v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in CommunityThemeMode.values)
                      RadioListTile<CommunityThemeMode>(
                        value: m,
                        title: Text(_themeModeLabel(m, l)),
                        activeColor: AppColors.accent,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null) await controller.setMode(selected);
  }

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    final l = AppLocalizations.of(context)!;
    return Theme(
      data: CommunityTheme.themeOf(context),
      child: Scaffold(
        appBar: AppBar(title: Text(l.accountTitle)),
        body: StreamBuilder<UserProfile?>(
          stream: widget.users.watchProfile(_uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text(l.accountLoadFailed));
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = snap.data;
            if (profile == null) {
              return Center(child: Text(l.accountNoProfile));
            }
            final hasPhoto =
                profile.photoUrl != null && profile.photoUrl!.isNotEmpty;
            final initial = profile.nickname.isNotEmpty
                ? profile.nickname.characters.first
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
                              border: Border.all(color: p.surface, width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: p.surfaceCard,
                              backgroundImage: hasPhoto
                                  ? NetworkImage(profile.photoUrl!)
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
                        profile.nickname,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.userId ??
                            '${profile.loginType.name}${l.accountLoginTypeSuffix}',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          color: p.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _tile(
                  icon: Icons.edit_outlined,
                  label: l.accountEditNickname,
                  onTap: () => _editNickname(profile.nickname),
                ),
                _tile(
                  icon: Icons.image_outlined,
                  label: l.accountChangePhoto,
                  onTap: _busy ? null : _changePhoto,
                ),
                _tile(
                  icon: Icons.badge_outlined,
                  label: l.accountLoginMethod,
                  trailing: Text(
                    profile.loginType.name,
                    style: TextStyle(color: p.textMuted),
                  ),
                ),
                _tile(
                  icon: Icons.block,
                  label: l.accountBlockedUsers,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlockedUsersScreen(
                        auth: widget.auth,
                        users: widget.users,
                      ),
                    ),
                  ),
                ),
                _tile(
                  icon: Icons.brightness_6_outlined,
                  label: l.accountTheme,
                  trailing: Text(
                    _themeModeLabel(
                      CommunityTheme.controllerOf(context).mode,
                      l,
                    ),
                    style: TextStyle(color: p.textMuted),
                  ),
                  onTap: _pickThemeMode,
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
                    child: Text(
                      l.accountLogout,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _withdraw,
                    child: Text(
                      l.accountWithdraw,
                      style: TextStyle(color: p.textMuted, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final p = CommunityTheme.paletteOf(context);
    return ListTile(
      leading: Icon(icon, color: p.textMuted),
      title: Text(label, style: TextStyle(color: p.text)),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(Icons.chevron_right, color: p.textMuted)),
      onTap: onTap,
    );
  }
}

/// 닉네임 편집 다이얼로그. 컨트롤러를 자기 생명주기에서 정리해
/// 닫힘 애니메이션 도중 dispose 경합을 피한다. 저장 시 입력 텍스트를 pop.
class _NicknameEditDialog extends StatefulWidget {
  final String initial;
  const _NicknameEditDialog({required this.initial});

  @override
  State<_NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<_NicknameEditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.accountEditNicknameTitle),
      content: TextField(
        controller: _controller,
        maxLength: 20,
        autofocus: true,
        decoration: const InputDecoration(counterText: ''),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l.accountSave),
        ),
      ],
    );
  }
}
