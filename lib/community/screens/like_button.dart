import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../post_repository.dart';
import '../theme/community_theme.dart';

/// 좋아요 아이콘 + 카운트. 탭 즉시 낙관적으로 반영하고,
/// 서버 카운트(함수 관리)가 따라오면 자연스럽게 정합을 맞춘다.
class LikeButton extends StatefulWidget {
  final PostRepository posts;
  final String postId;
  final String uid;
  final int likeCount;
  final Color? mutedColor;
  const LikeButton({
    super.key,
    required this.posts,
    required this.postId,
    required this.uid,
    required this.likeCount,
    this.mutedColor,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  /// 탭 직후의 낙관적 liked 값. 서버 카운트가 갱신되면 해제.
  bool? _optimistic;

  @override
  void didUpdateWidget(LikeButton old) {
    super.didUpdateWidget(old);
    // 서버 likeCount가 바뀌면(함수 반영 완료) 낙관적 상태를 해제해 정합.
    if (_optimistic != null && widget.likeCount != old.likeCount) {
      _optimistic = null;
    }
  }

  void _toggle(bool currentlyLiked) {
    setState(() => _optimistic = !currentlyLiked);
    widget.posts.toggleLike(
      postId: widget.postId,
      uid: widget.uid,
      liked: currentlyLiked,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    return StreamBuilder<bool>(
      stream: widget.posts.likedByMe(postId: widget.postId, uid: widget.uid),
      builder: (_, snap) {
        final streamLiked = snap.data ?? false;
        final liked = _optimistic ?? streamLiked;
        // 낙관적 대기 중에는 서버 카운트(토글 전 값)에 ±1을 얹어 보여준다.
        final count = _optimistic == null
            ? widget.likeCount
            : widget.likeCount + (_optimistic! ? 1 : -1);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                color: liked
                    ? AppColors.danger
                    : (widget.mutedColor ?? p.textMuted),
              ),
              onPressed: widget.uid.isEmpty ? null : () => _toggle(liked),
            ),
            Text('$count'),
          ],
        );
      },
    );
  }
}
