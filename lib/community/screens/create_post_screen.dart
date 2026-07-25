import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/shooting_mode.dart';
import '../../theme/app_colors.dart';
import '../auth_service.dart';
import '../mask_processor.dart';
import '../post_repository.dart';
import '../theme/community_theme.dart';
import 'mask_editor_screen.dart';

/// 작성 중 슬롯: 편집을 위해 원본을, 표시·업로드를 위해 마스킹본을 함께 보관.
class _PickedImage {
  final File original;
  File masked;
  _PickedImage({required this.original, required this.masked});
}

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
  final List<_PickedImage> _images = [];
  ShootingMode _mode = ShootingMode.person;
  bool _uploading = false;
  bool _masking = false;
  static const _maxImages = 10;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty || !mounted) return;
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      _snack('사진은 최대 10장까지 올릴 수 있어요');
      return;
    }
    var toAdd = picked;
    if (picked.length > remaining) {
      toAdd = picked.sublist(0, remaining);
      _snack('사진은 최대 10장까지 올릴 수 있어요');
    }
    setState(() => _masking = true);
    try {
      // 여러 장을 동시(최대 3개)에 자동 마스킹 — 순차보다 빠르고 순서는 보존된다.
      final originals = [for (final x in toAdd) File(x.path)];
      final masked = await autoMaskFacesAll(originals);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < originals.length; i++) {
          _images.add(_PickedImage(original: originals[i], masked: masked[i]));
        }
      });
    } finally {
      if (mounted) setState(() => _masking = false);
    }
  }

  Future<void> _editAt(int i) async {
    final masked = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => MaskEditorScreen(image: _images[i].original),
      ),
    );
    if (masked != null && mounted) {
      setState(() => _images[i].masked = masked);
    }
  }

  void _removeAt(int i) => setState(() => _images.removeAt(i));

  Future<void> _submit() async {
    final uid = widget.auth.currentUser?.uid;
    if (_images.isEmpty || uid == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final profile = await widget.auth.ensureMyProfile();
      await widget.posts.createPost(
        uid: uid,
        authorName: profile?.nickname ?? '익명',
        images: _images.map((e) => e.masked).toList(),
        caption: _caption.text.trim(),
        mode: _mode,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        _snack('업로드에 실패했어요');
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
              onPressed: (_images.isNotEmpty && !_uploading && !_masking)
                  ? _submit
                  : null,
              child: const Text('올리기'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 선택한 사진 그리드(마스킹본 표시). 탭=마스크 재편집, ×=삭제, +=추가.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _editAt(i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _images[i].masked,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removeAt(i),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_images.length < _maxImages)
                  GestureDetector(
                    onTap: _masking ? null : _pick,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _masking
                          ? const Center(child: CircularProgressIndicator())
                          : const Center(
                              child: Icon(Icons.add_photo_alternate, size: 32),
                            ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_images.length}/$_maxImages · 얼굴은 자동으로 가려집니다. 사진을 탭해 수정할 수 있어요.',
              style: TextStyle(
                fontSize: 12,
                color: p.text.withValues(alpha: 0.6),
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
