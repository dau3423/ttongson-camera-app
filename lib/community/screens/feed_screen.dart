import 'package:flutter/material.dart';
import '../post_repository.dart';
import '../user_repository.dart';
import '../auth_service.dart';
import '../moderation.dart';
import '../models/post.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'report_sheet.dart';
import 'blocked_users_screen.dart';

/// 최신순 게시물 피드. 로그인 게이트 뒤에서 진입.
class FeedScreen extends StatelessWidget {
  final AuthService auth;
  final PostRepository posts;
  final UserRepository users;
  FeedScreen({
    super.key,
    required this.auth,
    PostRepository? posts,
    UserRepository? users,
  }) : posts = posts ?? PostRepository(),
       users = users ?? UserRepository();

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티'),
        actions: [
          IconButton(
            icon: const Icon(Icons.block),
            tooltip: '차단 목록',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlockedUsersScreen(auth: auth, users: users),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatePostScreen(auth: auth, posts: posts),
          ),
        ),
        child: const Icon(Icons.add_a_photo),
      ),
      body: StreamBuilder<Set<String>>(
        stream: users.blockedUids(uid),
        builder: (context, blockedSnap) {
          final blocked = blockedSnap.data ?? <String>{};
          return StreamBuilder<Set<String>>(
            stream: posts.myReportedPostIds(uid),
            builder: (context, reportedSnap) {
              final reported = reportedSnap.data ?? <String>{};
              return StreamBuilder<List<Post>>(
                stream: posts.feed(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(child: Text('불러오지 못했어요'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = visibleItems(
                    snap.data!,
                    authorUidOf: (p) => p.authorUid,
                    idOf: (p) => p.id,
                    blockedAuthors: blocked,
                    reportedIds: reported,
                  );
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('아직 게시물이 없어요. 첫 사진을 올려보세요!'),
                    );
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => _PostCard(
                      post: items[i],
                      posts: posts,
                      users: users,
                      uid: uid,
                      auth: auth,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final PostRepository posts;
  final UserRepository users;
  final String uid;
  final AuthService auth;
  const _PostCard({
    required this.post,
    required this.posts,
    required this.users,
    required this.uid,
    required this.auth,
  });

  Future<void> _report(BuildContext context) async {
    final reason = await showReportSheet(context);
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await posts.reportPost(postId: post.id, uid: uid, reason: reason);
      messenger.showSnackBar(const SnackBar(content: Text('신고되었습니다')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('신고에 실패했어요 (이미 신고했을 수 있어요)')),
      );
    }
  }

  Future<void> _block(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text('${post.authorName} 님을 차단할까요? 이 사용자의 게시물과 댓글이 보이지 않아요.'),
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
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await users.blockUser(
        uid: uid,
        blockedUid: post.authorUid,
        blockedName: post.authorName,
      );
      messenger.showSnackBar(const SnackBar(content: Text('차단했어요')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('차단에 실패했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    post.authorName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (uid.isNotEmpty && uid != post.authorUid)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'report') _report(context);
                      if (v == 'block') _block(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: Text('신고하기')),
                      PopupMenuItem(value: 'block', child: Text('차단하기')),
                    ],
                  ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: Image.network(post.imageUrl, fit: BoxFit.cover),
          ),
          Padding(padding: const EdgeInsets.all(12), child: Text(post.caption)),
          Row(
            children: [
              StreamBuilder<bool>(
                stream: posts.likedByMe(postId: post.id, uid: uid),
                builder: (_, s) {
                  final liked = s.data ?? false;
                  return IconButton(
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.red : null,
                    ),
                    onPressed: uid.isEmpty
                        ? null
                        : () => posts.toggleLike(postId: post.id, uid: uid),
                  );
                },
              ),
              Text('${post.likeCount}'),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PostDetailScreen(post: post, auth: auth, posts: posts),
                  ),
                ),
              ),
              Text('${post.commentCount}'),
            ],
          ),
        ],
      ),
    );
  }
}
