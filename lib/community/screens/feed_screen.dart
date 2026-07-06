import 'package:flutter/material.dart';
import '../post_repository.dart';
import '../auth_service.dart';
import '../models/post.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

/// 최신순 게시물 피드. 로그인 게이트 뒤에서 진입.
class FeedScreen extends StatelessWidget {
  final AuthService auth;
  final PostRepository posts;
  FeedScreen({super.key, required this.auth, PostRepository? posts})
    : posts = posts ?? PostRepository();

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('커뮤니티')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatePostScreen(auth: auth, posts: posts),
          ),
        ),
        child: const Icon(Icons.add_a_photo),
      ),
      body: StreamBuilder<List<Post>>(
        stream: posts.feed(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('불러오지 못했어요'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('아직 게시물이 없어요. 첫 사진을 올려보세요!'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _PostCard(post: items[i], posts: posts, uid: uid, auth: auth),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final PostRepository posts;
  final String uid;
  final AuthService auth;
  const _PostCard({
    required this.post,
    required this.posts,
    required this.uid,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              post.authorName,
              style: const TextStyle(fontWeight: FontWeight.bold),
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
