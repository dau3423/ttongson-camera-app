import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/shooting_mode.dart';
import '../../theme/app_colors.dart';
import '../auth_service.dart';
import '../post_repository.dart';
import '../theme/community_theme.dart';
import 'mask_editor_screen.dart';

/// 사진 선택 → 가림 편집 → 캡션 → 업로드.
class CreatePostScreen extends StatefulWidget {
  final AuthService auth;
  final PostRepository posts;
  const CreatePostScreen({super.key, required this.auth, required this.posts});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  File? _image;
  ShootingMode _mode = ShootingMode.person;
  bool _uploading = false;

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    final masked = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => MaskEditorScreen(image: File(x.path))),
    );
    // 편집 취소(null) 시 이미지 미설정 유지.
    if (masked != null && mounted) setState(() => _image = masked);
  }

  Future<void> _submit() async {
    final image = _image;
    final uid = widget.auth.currentUser?.uid;
    if (image == null || uid == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final profile = await widget.auth.ensureMyProfile();
      await widget.posts.createPost(
        uid: uid,
        authorName: profile?.nickname ?? '익명',
        image: image,
        caption: _caption.text.trim(),
        mode: _mode,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('업로드에 실패했어요')));
      }
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    return Theme(
      data: CommunityTheme.themeOf(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('사진 올리기'),
          actions: [
            TextButton(
              onPressed: (_image != null && !_uploading) ? _submit : null,
              child: const Text('올리기'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _pick,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                    image: _image != null
                        ? DecorationImage(
                            image: FileImage(_image!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _image == null
                      ? const Center(
                          child: Icon(Icons.add_photo_alternate, size: 48),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('촬영 모드', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in ShootingMode.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _mode == m,
                    onSelected: (_) => setState(() => _mode = m),
                    selectedColor: AppColors.accent,
                    labelStyle: TextStyle(
                      color: _mode == m
                          ? AppColors.surfaceApp
                          : p.text.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _caption,
              maxLength: 140,
              decoration: const InputDecoration(
                hintText: '한 줄 팁을 남겨보세요',
                border: OutlineInputBorder(),
              ),
            ),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
