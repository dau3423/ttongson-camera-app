import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../auth_service.dart';
import '../post_repository.dart';
import '../user_repository.dart';
import '../moderation.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../theme/community_theme.dart';
import 'confirm_dialog.dart';
import 'like_button.dart';
import 'report_sheet.dart';
import 'post_image_carousel.dart';

/// 게시물 상세 — 사진·캡션·좋아요 + 댓글 목록·입력. 피드 카드에서 진입.
class PostDetailScreen extends StatefulWidget {
  final Post post;
  final AuthService auth;
  final PostRepository posts;
  const PostDetailScreen({
    super.key,
    required this.post,
    required this.auth,
    required this.posts,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _input = TextEditingController();
  final _users = UserRepository();
  bool _sending = false;
  bool _deleting = false;

  String get _uid => widget.auth.currentUser?.uid ?? '';

  /// 작성자 본인이면 삭제할 수 있다.
  bool get _isMine => _uid.isNotEmpty && widget.post.authorUid == _uid;

  Future<void> _delete() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showAppConfirm(
      context,
      icon: Icons.delete_outline,
      title: l.postDeleteTitle,
      body: l.postDeleteBody,
      confirmLabel: l.postDeleteTooltip,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.posts.deletePost(widget.post);
      messenger.showSnackBar(SnackBar(content: Text(l.postDeleteSuccess)));
      navigator.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        messenger.showSnackBar(SnackBar(content: Text(l.postDeleteFailed)));
      }
    }
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context)!;
    final text = _input.text.trim();
    if (text.isEmpty || _uid.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      // 프로필이 없으면 생성해서 닉네임·사진을 확보(익명 방지).
      final profile = await widget.auth.ensureMyProfile();
      await widget.posts.addComment(
        postId: widget.post.id,
        uid: _uid,
        authorName: profile?.nickname ?? l.postAnonymous,
        authorPhotoUrl: profile?.photoUrl,
        text: text,
      );
      if (mounted) _input.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.postCommentSendFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(Comment c) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showAppConfirm(
      context,
      icon: Icons.delete_outline,
      title: l.postCommentDeleteTitle,
      body: l.postCommentDeleteBody,
      confirmLabel: l.postDeleteTooltip,
      destructive: true,
    );
    if (ok != true) return;
    if (!mounted) return;
    try {
      await widget.posts.deleteComment(postId: widget.post.id, commentId: c.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.postDeleteFailed)));
      }
    }
  }

  Future<void> _reportComment(Comment c) async {
    final l = AppLocalizations.of(context)!;
    final reason = await showReportSheet(context);
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.posts.reportComment(
        postId: widget.post.id,
        commentId: c.id,
        uid: _uid,
        reason: reason,
      );
      messenger.showSnackBar(SnackBar(content: Text(l.postReportSuccess)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.postReportFailed)));
    }
  }

  Future<void> _blockAuthor(Comment c) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showAppConfirm(
      context,
      icon: Icons.block,
      title: l.postBlockTitle(c.authorName),
      body: l.postBlockBody,
      confirmLabel: l.feedBlockConfirm,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _users.blockUser(
        uid: _uid,
        blockedUid: c.authorUid,
        blockedName: c.authorName,
      );
      messenger.showSnackBar(SnackBar(content: Text(l.postBlockSuccess)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.postBlockFailed)));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final post = widget.post;
    return Theme(
      data: CommunityTheme.themeOf(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(post.authorName),
          actions: [
            if (_isMine)
              IconButton(
                tooltip: l.postDeleteTooltip,
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleting ? null : _delete,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  PostImageCarousel(imageUrls: post.imageUrls),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(post.caption),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      LikeButton(
                        posts: widget.posts,
                        postId: post.id,
                        uid: _uid,
                        likeCount: post.likeCount,
                      ),
                    ],
                  ),
                  const Divider(),
                  StreamBuilder<Set<String>>(
                    stream: _users.blockedUids(_uid),
                    builder: (context, blockedSnap) {
                      final blocked = blockedSnap.data ?? <String>{};
                      return StreamBuilder<Set<String>>(
                        stream: widget.posts.myReportedCommentIds(_uid),
                        builder: (context, reportedSnap) {
                          final reported = reportedSnap.data ?? <String>{};
                          return StreamBuilder<List<Comment>>(
                            stream: widget.posts.comments(post.id),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(l.postCommentLoadFailed),
                                  ),
                                );
                              }
                              if (!snap.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final items = visibleItems(
                                snap.data!,
                                authorUidOf: (c) => c.authorUid,
                                idOf: (c) => c.id,
                                blockedAuthors: blocked,
                                reportedIds: reported,
                              );
                              if (items.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(l.postCommentEmpty),
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  for (final c in items)
                                    ListTile(
                                      leading: _CommentAvatar(
                                        name: c.authorName,
                                        photoUrl: c.authorPhotoUrl,
                                      ),
                                      title: Text(
                                        c.authorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(c.text),
                                      trailing: c.authorUid == _uid
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  _confirmDelete(c),
                                            )
                                          : PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.more_vert,
                                                size: 20,
                                              ),
                                              onSelected: (v) {
                                                if (v == 'report') {
                                                  _reportComment(c);
                                                }
                                                if (v == 'block') {
                                                  _blockAuthor(c);
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                PopupMenuItem(
                                                  value: 'report',
                                                  child: Text(l.postMenuReport),
                                                ),
                                                PopupMenuItem(
                                                  value: 'block',
                                                  child: Text(l.postMenuBlock),
                                                ),
                                              ],
                                            ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 280,
                        minLines: 1,
                        maxLines: 4,
                        enabled: _uid.isNotEmpty,
                        decoration: InputDecoration(
                          hintText: l.postCommentHint,
                          border: const OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: (_uid.isEmpty || _sending) ? null : _send,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 댓글 작성자 아바타. 사진이 있으면 사진, 없으면 닉네임 이니셜.
class _CommentAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _CommentAvatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
    );
  }
}
