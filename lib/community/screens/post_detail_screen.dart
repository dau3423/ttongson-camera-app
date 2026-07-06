import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../post_repository.dart';
import '../user_repository.dart';
import '../moderation.dart';
import '../models/post.dart';
import '../models/comment.dart';
import 'report_sheet.dart';

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

  String get _uid => widget.auth.currentUser?.uid ?? '';

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _uid.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final profile = await _users.getProfile(_uid);
      await widget.posts.addComment(
        postId: widget.post.id,
        uid: _uid,
        authorName: profile?.nickname ?? '익명',
        text: text,
      );
      if (mounted) _input.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글 전송에 실패했어요')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('이 댓글을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    try {
      await widget.posts.deleteComment(postId: widget.post.id, commentId: c.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제에 실패했어요')));
      }
    }
  }

  Future<void> _reportComment(Comment c) async {
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
      messenger.showSnackBar(const SnackBar(content: Text('신고되었습니다')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('신고에 실패했어요 (이미 신고했을 수 있어요)')),
      );
    }
  }

  Future<void> _blockAuthor(Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text('${c.authorName} 님을 차단할까요? 이 사용자의 게시물과 댓글이 보이지 않아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('차단'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _users.blockUser(
        uid: _uid,
        blockedUid: c.authorUid,
        blockedName: c.authorName,
      );
      messenger.showSnackBar(const SnackBar(content: Text('차단했어요')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('차단에 실패했어요')));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Scaffold(
      appBar: AppBar(title: Text(post.authorName)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(post.imageUrl, fit: BoxFit.cover),
                ),
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
                    StreamBuilder<bool>(
                      stream: widget.posts.likedByMe(
                        postId: post.id,
                        uid: _uid,
                      ),
                      builder: (_, s) {
                        final liked = s.data ?? false;
                        return IconButton(
                          icon: Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            color: liked ? Colors.red : null,
                          ),
                          onPressed: _uid.isEmpty
                              ? null
                              : () => widget.posts.toggleLike(
                                  postId: post.id,
                                  uid: _uid,
                                ),
                        );
                      },
                    ),
                    Text('${post.likeCount}'),
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
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('댓글을 불러오지 못했어요')),
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
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('첫 댓글을 남겨보세요')),
                              );
                            }
                            return Column(
                              children: [
                                for (final c in items)
                                  ListTile(
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
                                            onPressed: () => _confirmDelete(c),
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
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'report',
                                                child: Text('신고하기'),
                                              ),
                                              PopupMenuItem(
                                                value: 'block',
                                                child: Text('차단하기'),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 280,
                      minLines: 1,
                      maxLines: 4,
                      enabled: _uid.isNotEmpty,
                      decoration: const InputDecoration(
                        hintText: '댓글을 남겨보세요',
                        border: OutlineInputBorder(),
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
    );
  }
}
