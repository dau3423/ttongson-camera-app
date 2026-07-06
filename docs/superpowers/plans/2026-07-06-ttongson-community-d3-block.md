# 커뮤니티 계획 D3 — 차단 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 사용자가 다른 사용자를 차단하면 그 사용자의 게시물·댓글이 내 화면에서 사라지고, 차단 목록 화면에서 해제할 수 있다.

**Architecture:** 순수 `BlockedUser` 모델과 순수 `moderation.visibleItems`(차단+신고 통합 필터)는 TDD. `UserRepository`에 blocks 서브컬렉션 접근(차단·해제·조회) 추가. `BlockedUsersScreen`으로 해제. 피드·상세 빌더가 `blockedUids`·`myReported*` 스트림을 구독해 `visibleItems`로 필터.

**Tech Stack:** Flutter(Dart), `cloud_firestore`, `firebase_auth`. B·C·D1·D2 완료·병합. 신규 의존성 없음. **함수 없음**(차단은 클라이언트 전용).

## Global Constraints

- 차단 문서: `blocks/{uid}/blocked/{blockedUid}` = `{blockedName, createdAt}`. 문서 존재 = uid가 blockedUid를 차단. 본인(request.auth.uid == uid)만 read/write.
- 차단은 **나에게만** 적용(상대 무영향). 함수·카운터 없음.
- 차단 범위: 차단 작성자의 **게시물 + 댓글** 모두 내 화면에서 제외.
- 필터는 순수 `moderation.visibleItems`로 **차단 작성자 + 내가 신고한 항목**을 함께 제외(D2 인라인 신고 필터를 대체·통합).
- 차단 실행은 **확인 다이얼로그** 후. **본인 콘텐츠엔 차단 옵션 미노출**(UI).
- 순수 로직 TDD. Firestore/UI는 구현 + 기기 검증.
- 앱 게이트 `tool/verify.sh`. 정적분석 `dart analyze lib test`(**`flutter analyze` 금지**). Flutter SDK `/Users/soonbok/flutter/bin`.
- 커밋: Conventional Commits + `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

```
lib/community/
  models/blocked_user.dart          # (신규) 순수 값 객체
  moderation.dart                   # (신규) 순수 visibleItems 필터
  user_repository.dart              # (수정) blockUser·unblockUser·blockedUids·blockedList
  screens/blocked_users_screen.dart # (신규) 차단 목록·해제
  screens/feed_screen.dart          # (수정) ⋮ 차단 + 필터 통합 + AppBar 진입
  screens/post_detail_screen.dart   # (수정) 댓글 ⋮(신고+차단) + 필터 통합
firestore.rules                     # (수정) blocks 규칙
test/community/
  blocked_user_test.dart            # (신규)
  moderation_test.dart              # (신규)
```

---

### Task 1: `BlockedUser` 모델

**Files:**
- Create: `lib/community/models/blocked_user.dart`
- Test: `test/community/blocked_user_test.dart`

**Interfaces:** `class BlockedUser { String uid, name; factory BlockedUser.fromData(String uid, Map<String,dynamic> data) }` — `name` = `data['blockedName']`.

- [ ] **Step 1: 실패 테스트** — `test/community/blocked_user_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/blocked_user.dart';

void main() {
  test('fromData: blockedName을 name으로', () {
    final b = BlockedUser.fromData('u1', {'blockedName': '귀여운너구리1'});
    expect(b.uid, 'u1');
    expect(b.name, '귀여운너구리1');
  });

  test('fromData: 이름 누락 시 빈 문자열', () {
    final b = BlockedUser.fromData('u2', {});
    expect(b.uid, 'u2');
    expect(b.name, '');
  });
}
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/community/blocked_user_test.dart` → FAIL.
- [ ] **Step 3: 구현** — `lib/community/models/blocked_user.dart`:

```dart
// lib/community/models/blocked_user.dart
// 순수 Dart — Flutter/plugin import 금지.

class BlockedUser {
  final String uid;
  final String name;
  const BlockedUser({required this.uid, required this.name});

  factory BlockedUser.fromData(String uid, Map<String, dynamic> data) =>
      BlockedUser(uid: uid, name: (data['blockedName'] as String?) ?? '');
}
```

- [ ] **Step 4:** `flutter test test/community/blocked_user_test.dart` → PASS (2).
- [ ] **Step 5: 커밋**

```bash
git add lib/community/models/blocked_user.dart test/community/blocked_user_test.dart
git commit -m "feat: BlockedUser 모델"
```

---

### Task 2: `moderation.visibleItems` 순수 필터

**Files:**
- Create: `lib/community/moderation.dart`
- Test: `test/community/moderation_test.dart`

**Interfaces:** `List<T> visibleItems<T>(List<T> items, {required String Function(T) authorUidOf, required String Function(T) idOf, required Set<String> blockedAuthors, required Set<String> reportedIds})`.

- [ ] **Step 1: 실패 테스트** — `test/community/moderation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/moderation.dart';

class _Item {
  final String id;
  final String author;
  const _Item(this.id, this.author);
}

void main() {
  const items = [_Item('p1', 'a'), _Item('p2', 'b'), _Item('p3', 'c')];

  List<_Item> run(Set<String> blocked, Set<String> reported) => visibleItems(
    items,
    authorUidOf: (i) => i.author,
    idOf: (i) => i.id,
    blockedAuthors: blocked,
    reportedIds: reported,
  );

  test('빈 집합이면 전부 표시', () {
    expect(run({}, {}).length, 3);
  });

  test('차단한 작성자 제외', () {
    expect(run({'b'}, {}).map((i) => i.id).toList(), ['p1', 'p3']);
  });

  test('내가 신고한 id 제외', () {
    expect(run({}, {'p1'}).map((i) => i.id).toList(), ['p2', 'p3']);
  });

  test('차단+신고 둘 다 제외', () {
    expect(run({'c'}, {'p1'}).map((i) => i.id).toList(), ['p2']);
  });
}
```

- [ ] **Step 2:** `flutter test test/community/moderation_test.dart` → FAIL.
- [ ] **Step 3: 구현** — `lib/community/moderation.dart`:

```dart
// lib/community/moderation.dart
// 순수 Dart — Flutter/plugin import 금지.

/// 차단한 작성자 또는 내가 신고한 항목을 제외한 리스트를 반환한다.
/// 피드(Post)·댓글(Comment) 공용.
List<T> visibleItems<T>(
  List<T> items, {
  required String Function(T) authorUidOf,
  required String Function(T) idOf,
  required Set<String> blockedAuthors,
  required Set<String> reportedIds,
}) {
  return items
      .where(
        (it) =>
            !blockedAuthors.contains(authorUidOf(it)) &&
            !reportedIds.contains(idOf(it)),
      )
      .toList();
}
```

- [ ] **Step 4:** `flutter test test/community/moderation_test.dart` → PASS (4).
- [ ] **Step 5: 커밋**

```bash
git add lib/community/moderation.dart test/community/moderation_test.dart
git commit -m "feat: moderation.visibleItems 차단·신고 순수 필터"
```

---

### Task 3: `UserRepository` 차단 메서드 + 규칙

**Files:**
- Modify: `lib/community/user_repository.dart`, `firestore.rules`

**Interfaces:**
- Consumes: `BlockedUser`(T1).
- Produces:
  - `Future<void> blockUser({required String uid, required String blockedUid, required String blockedName})`
  - `Future<void> unblockUser({required String uid, required String blockedUid})`
  - `Stream<Set<String>> blockedUids(String uid)`
  - `Stream<List<BlockedUser>> blockedList(String uid)`

- [ ] **Step 1: import 추가** — `lib/community/user_repository.dart`의 `import 'models/user_profile.dart';` 아래에 추가:

```dart
import 'models/blocked_user.dart';
```

- [ ] **Step 2: 메서드 추가** — `getProfile(...)` 메서드 아래(클래스 안, 닫는 `}` 앞)에 추가:

```dart
  /// 사용자 차단(내 blocks/{uid}/blocked/{blockedUid} 문서 생성).
  Future<void> blockUser({
    required String uid,
    required String blockedUid,
    required String blockedName,
  }) async {
    await _db
        .collection('blocks')
        .doc(uid)
        .collection('blocked')
        .doc(blockedUid)
        .set({
          'blockedName': blockedName,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// 차단 해제(문서 삭제).
  Future<void> unblockUser({
    required String uid,
    required String blockedUid,
  }) async {
    await _db
        .collection('blocks')
        .doc(uid)
        .collection('blocked')
        .doc(blockedUid)
        .delete();
  }

  /// 내가 차단한 uid 집합(필터용).
  Stream<Set<String>> blockedUids(String uid) {
    return _db
        .collection('blocks')
        .doc(uid)
        .collection('blocked')
        .snapshots()
        .map((q) => q.docs.map((d) => d.id).toSet());
  }

  /// 내가 차단한 사용자 목록(목록 화면용, 최신순).
  Stream<List<BlockedUser>> blockedList(String uid) {
    return _db
        .collection('blocks')
        .doc(uid)
        .collection('blocked')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (q) =>
              q.docs.map((d) => BlockedUser.fromData(d.id, d.data())).toList(),
        );
  }
```

- [ ] **Step 3: Firestore 규칙** — `firestore.rules`의 `match /posts/{postId} { ... }` 블록 전체가 끝난 **다음**, 최상위 catch-all `match /{document=**}` **위에** 추가:

```
    // 차단: 본인 것만 읽기/쓰기.
    match /blocks/{uid}/blocked/{blockedUid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
```

- [ ] **Step 4:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/user_repository.dart` → No issues found! (규칙 중괄호 균형도 확인: `python3 -c "s=open('firestore.rules').read(); print(s.count('{')==s.count('}'))"` → True)
- [ ] **Step 5: 커밋**

```bash
git add lib/community/user_repository.dart firestore.rules
git commit -m "feat: UserRepository 차단·해제·조회 + blocks 규칙"
```

> 규칙 배포는 사람: `firebase deploy --only firestore:rules`.

---

### Task 4: 차단 목록 화면

**Files:**
- Create: `lib/community/screens/blocked_users_screen.dart`

**Interfaces:**
- Consumes: `AuthService.currentUser`(기존), `UserRepository.{blockedList,unblockUser}`(T3), `BlockedUser`(T1).
- Produces: `class BlockedUsersScreen extends StatelessWidget { BlockedUsersScreen({required AuthService auth, UserRepository? users}) }`.

- [ ] **Step 1: 구현** — `lib/community/screens/blocked_users_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../user_repository.dart';
import '../models/blocked_user.dart';

/// 내가 차단한 사용자 목록 + 해제.
class BlockedUsersScreen extends StatelessWidget {
  final AuthService auth;
  final UserRepository users;
  BlockedUsersScreen({super.key, required this.auth, UserRepository? users})
    : users = users ?? UserRepository();

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('차단한 사용자')),
      body: StreamBuilder<List<BlockedUser>>(
        stream: users.blockedList(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('불러오지 못했어요'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('차단한 사용자가 없어요'));
          }
          return ListView(
            children: [
              for (final b in items)
                ListTile(
                  title: Text(b.name),
                  trailing: TextButton(
                    onPressed: () =>
                        users.unblockUser(uid: uid, blockedUid: b.uid),
                    child: const Text('차단 해제'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/screens/blocked_users_screen.dart` → No issues found!
- [ ] **Step 3: 커밋**

```bash
git add lib/community/screens/blocked_users_screen.dart
git commit -m "feat: 차단 목록 화면(해제)"
```

---

### Task 5: 피드 카드 차단 + 필터 통합 + AppBar 진입

**Files:**
- Modify: `lib/community/screens/feed_screen.dart` (전체 교체)

**Interfaces:**
- Consumes: `UserRepository.{blockedUids,blockUser}`(T3), `visibleItems`(T2), `BlockedUsersScreen`(T4), `showReportSheet`(기존).

- [ ] **Step 1: 파일 전체 교체** — `lib/community/screens/feed_screen.dart`를 아래로 교체:

```dart
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
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test` → No issues found!
- [ ] **Step 3: 커밋**

```bash
git add lib/community/screens/feed_screen.dart
git commit -m "feat: 피드 카드 차단 + 필터 통합(차단·신고) + 차단 목록 진입"
```

---

### Task 6: 댓글 차단 + 필터 통합

**Files:**
- Modify: `lib/community/screens/post_detail_screen.dart` (전체 교체)

**Interfaces:**
- Consumes: `UserRepository.{blockedUids,blockUser}`(T3, `_users` 필드 재사용), `visibleItems`(T2), `showReportSheet`(기존).

- [ ] **Step 1: 파일 전체 교체** — `lib/community/screens/post_detail_screen.dart`를 아래로 교체:

```dart
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
                                child: Center(child: CircularProgressIndicator()),
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
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test` → No issues found!
- [ ] **Step 3: 커밋**

```bash
git add lib/community/screens/post_detail_screen.dart
git commit -m "feat: 댓글 차단 + 필터 통합(차단·신고)"
```

---

### Task 7: 최종 검증

- [ ] **Step 1:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh` → `✅ verify 통과`.
- [ ] **Step 2:** `cd functions && npx vitest run` → 전부 PASS(회귀 없음).
- [ ] **Step 3: 기기 수동 검증 (사람)** — 규칙 배포 후 `flutter run`:
  - 타인 게시물 ⋮ → '차단하기' → 확인 → 그 사람 게시물이 피드에서 사라짐.
  - 타인 댓글 ⋮ → '차단하기' → 그 사람 게시물·댓글이 사라짐.
  - AppBar 차단 아이콘 → 차단 목록 → '차단 해제' → 다시 보임.
  - 본인 글/댓글엔 차단 옵션 없음(본인 댓글은 삭제만).
  - 신고 기능(D2) 회귀 없음(⋮에 신고하기 유지).

---

## Self-Review (작성자 확인)

- **스펙 커버리지(D3):** BlockedUser=T1, moderation.visibleItems=T2, UserRepository 차단·해제·조회+규칙=T3, 목록 화면=T4, 피드 차단+필터+진입=T5, 댓글 차단+필터=T6, 검증=T7.
- **플레이스홀더:** 없음 — 모든 코드·테스트 실제 내용 포함. T5·T6은 상호 의존 편집이 많아 파일 전체 교체(완전한 코드 제공).
- **타입 일관성:** `BlockedUser{uid,name,fromData}`, `visibleItems<T>(...authorUidOf,idOf,blockedAuthors,reportedIds)`, `UserRepository.{blockUser,unblockUser,blockedUids,blockedList}`, `BlockedUsersScreen({auth,users})`, `FeedScreen({auth,posts,users})` — 태스크 간 일치. 기존 `myReportedPostIds`·`myReportedCommentIds`·`reportPost`·`reportComment`·`showReportSheet`·`_confirmDelete` 재사용. D2의 인라인 신고 `.where` 필터는 `visibleItems`로 통합(동작 동일).
- **주의:** blocks 규칙은 본인 전용. 함수 없음. 차단은 나에게만 적용. 본인 콘텐츠 차단은 UI 미노출(규칙 강제 아님, 무해). 규칙 배포는 사람.
```
