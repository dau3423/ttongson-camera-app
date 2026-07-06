import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth_service.dart';
import '../post_repository.dart';
import '../user_repository.dart';

/// 사진 선택 → 캡션 → 업로드. (가림 편집 단계는 계획 C에서 삽입)
class CreatePostScreen extends StatefulWidget {
  final AuthService auth;
  final PostRepository posts;
  const CreatePostScreen({super.key, required this.auth, required this.posts});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final _users = UserRepository();
  File? _image;
  bool _uploading = false;

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null && mounted) setState(() => _image = File(x.path));
  }

  Future<void> _submit() async {
    final image = _image;
    final uid = widget.auth.currentUser?.uid;
    if (image == null || uid == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final profile = await _users.getProfile(uid);
      await widget.posts.createPost(
        uid: uid,
        authorName: profile?.nickname ?? '익명',
        image: image,
        caption: _caption.text.trim(),
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
    return Scaffold(
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
    );
  }
}
