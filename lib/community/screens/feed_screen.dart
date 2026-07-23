import 'package:flutter/material.dart';
import '../../models/shooting_mode.dart';
import '../../theme/app_colors.dart';
import '../post_repository.dart';
import '../user_repository.dart';
import '../auth_service.dart';
import '../moderation.dart';
import '../models/post.dart';
import '../theme/community_theme.dart';
import 'confirm_dialog.dart';
import 'like_button.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'report_sheet.dart';
import 'account_screen.dart';

/// 촬영 팁 피드. 로그인 게이트 뒤에서 진입. 인기/최신 정렬 탭.
class FeedScreen extends StatefulWidget {
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
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _popular = true; // true=인기, false=최신
  ShootingMode? _filter; // null=전체

  List<Post> _sorted(List<Post> items) {
    // 모드 필터(선택 시 해당 모드만; 과거 mode 없는 글은 전체에서만 노출).
    final filtered = _filter == null
        ? items
        : items.where((p) => p.mode == _filter).toList();
    final list = [...filtered];
    if (_popular) {
      list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    } else {
      list.sort((a, b) {
        final ad = a.createdAt, bd = b.createdAt;
        if (ad == null || bd == null) return 0;
        return bd.compareTo(ad);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    final uid = widget.auth.currentUser?.uid ?? '';
    return Theme(
      data: CommunityTheme.themeOf(context),
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              const Text(
                '촬영 팁',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _Tab('인기', _popular, () => setState(() => _popular = true)),
              const SizedBox(width: 4),
              _Tab('최신', !_popular, () => setState(() => _popular = false)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: '내 계정',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AccountScreen(auth: widget.auth, users: widget.users),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  _FilterChip('전체', _filter == null, () {
                    setState(() => _filter = null);
                  }),
                  for (final m in ShootingMode.values)
                    _FilterChip(m.label, _filter == m, () {
                      setState(() => _filter = m);
                    }),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.accent,
          foregroundColor: p.surface,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CreatePostScreen(auth: widget.auth, posts: widget.posts),
            ),
          ),
          child: const Icon(Icons.add_a_photo),
        ),
        body: StreamBuilder<Set<String>>(
          stream: widget.users.blockedUids(uid),
          builder: (context, blockedSnap) {
            final blocked = blockedSnap.data ?? <String>{};
            return StreamBuilder<Set<String>>(
              stream: widget.posts.myReportedPostIds(uid),
              builder: (context, reportedSnap) {
                final reported = reportedSnap.data ?? <String>{};
                return StreamBuilder<List<Post>>(
                  stream: widget.posts.feed(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(child: Text('불러오지 못했어요'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = _sorted(
                      visibleItems(
                        snap.data!,
                        authorUidOf: (p) => p.authorUid,
                        idOf: (p) => p.id,
                        blockedAuthors: blocked,
                        reportedIds: reported,
                      ),
                    );
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('아직 게시물이 없어요. 첫 사진을 올려보세요!'),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _PostCard(
                        post: items[i],
                        posts: widget.posts,
                        users: widget.users,
                        uid: uid,
                        auth: widget.auth,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// 인기/최신 정렬 탭 pill.
class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? p.surface : p.textMuted,
          ),
        ),
      ),
    );
  }
}

/// 촬영모드 필터 칩(전체/인물/자연/사물).
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final p = CommunityTheme.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? AppColors.accent : const Color(0x33FFFFFF),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? p.surface : p.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// 게시물 촬영모드 태그(앰버 아웃라인 pill).
class _ModeTag extends StatelessWidget {
  final ShootingMode mode;
  const _ModeTag(this.mode);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.accent),
      ),
      child: Text(
        mode.label,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
    final ok = await showAppConfirm(
      context,
      icon: Icons.block,
      title: '${post.authorName} 님을 차단할까요?',
      body: '이 사용자의 게시물과 댓글이 보이지 않아요.',
      confirmLabel: '차단',
      destructive: true,
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
    final p = CommunityTheme.paletteOf(context);
    final initial = post.authorName.isNotEmpty
        ? post.authorName.characters.first
        : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: p.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post.authorName,
                    style: TextStyle(
                      color: p.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (post.mode != null) ...[
                  _ModeTag(post.mode!),
                  const SizedBox(width: 4),
                ],
                if (uid.isNotEmpty && uid != post.authorUid)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: p.textMuted),
                    color: p.surfaceCard,
                    onSelected: (v) {
                      if (v == 'report') _report(context);
                      if (v == 'block') _block(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: Text('신고하기')),
                      PopupMenuItem(
                        value: 'block',
                        child: Text(
                          '차단하기',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(post.imageUrl, fit: BoxFit.cover),
              ),
            ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                post.caption,
                style: const TextStyle(color: Color(0xE6F4F1EA), fontSize: 14),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                LikeButton(
                  posts: posts,
                  postId: post.id,
                  uid: uid,
                  likeCount: post.likeCount,
                  mutedColor: p.textMuted,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.mode_comment_outlined, color: p.textMuted),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(
                        post: post,
                        auth: auth,
                        posts: posts,
                      ),
                    ),
                  ),
                ),
                Text('${post.commentCount}', style: TextStyle(color: p.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
