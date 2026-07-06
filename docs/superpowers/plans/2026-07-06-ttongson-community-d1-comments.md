# 커뮤니티 계획 D1 — 댓글 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 사용자가 게시물 상세 화면에서 댓글을 작성·조회하고 본인 댓글을 삭제한다. commentCount는 Cloud Function이 관리.

**Architecture:** 순수 `Comment` 모델과 순수 `commentDelta`는 TDD. `PostRepository`에 댓글 서브컬렉션 접근(추가·스트림·삭제)을 더한다. `onCommentWrite`(Firestore 트리거)가 부모 post `commentCount`를 증감. `PostDetailScreen`이 사진·캡션·좋아요·댓글을 조립, 피드 카드의 댓글 버튼으로 진입.

**Tech Stack:** Flutter(Dart), `cloud_firestore`, `firebase_auth`; Functions v2 Firestore 트리거(TS, vitest). 계획 B·C 완료·병합됨. 신규 의존성 없음.

## Global Constraints

- `posts/{postId}/comments/{commentId}`: authorUid, authorName(작성 시점 닉네임 비정규화), text(≤280자), createdAt(serverTimestamp), reportCount, hidden. `reportCount`/`hidden` 및 부모 `commentCount`는 **클라이언트 쓰기 금지**(함수 전용).
- 댓글 조회: `hidden==false`만, `createdAt` **오름차순**(대화 순).
- text 상한 280자: UI `maxLength` + Firestore 규칙 `text.size() <= 280` 서버 강제.
- 별도 CommentRepository 없이 **`PostRepository`에 댓글 메서드 추가**.
- 작성자명 = 작성 시점 닉네임(`UserRepository.getProfile`, 폴백 '익명').
- 순수 로직 TDD. Firestore/UI는 구현 + 기기 수동 검증.
- 앱 게이트 `tool/verify.sh`, 함수 게이트 `npx vitest run`. 정적분석 `dart analyze lib test`(**`flutter analyze` 금지**). Flutter SDK `/Users/soonbok/flutter/bin`.
- 커밋: Conventional Commits + `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

```
lib/community/
  models/comment.dart              # (신규) 순수 값 객체
  post_repository.dart             # (수정) addComment·comments·deleteComment 추가
  screens/post_detail_screen.dart  # (신규) 상세 + 댓글 UI
  screens/feed_screen.dart         # (수정) 카드에 댓글 버튼
functions/
  src/comments.ts                  # (신규) commentDelta + onCommentWrite
  src/index.ts                     # (수정) export 추가
  test/comments.test.ts            # (신규)
firestore.rules                    # (수정) comments match
firestore.indexes.json             # (수정) comments 복합 인덱스
test/community/comment_test.dart   # (신규)
```

---

### Task 1: `Comment` 모델

**Files:**
- Create: `lib/community/models/comment.dart`
- Test: `test/community/comment_test.dart`

**Interfaces:**
- Produces: `class Comment { String id, authorUid, authorName, text; DateTime? createdAt; Map<String,dynamic> toCreateMap(); factory Comment.fromData(String id, Map<String,dynamic> data) }` — 생성자 `Comment({required id, authorUid, authorName, text, createdAt})`.

- [ ] **Step 1: 실패 테스트** — `test/community/comment_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/comment.dart';

void main() {
  test('toCreateMap: reportCount 0, hidden false, createdAt 제외', () {
    const c = Comment(
      id: '',
      authorUid: 'u1',
      authorName: '귀여운너구리1',
      text: '구도 좋네요',
    );
    final m = c.toCreateMap();
    expect(m['authorUid'], 'u1');
    expect(m['authorName'], '귀여운너구리1');
    expect(m['text'], '구도 좋네요');
    expect(m['reportCount'], 0);
    expect(m['hidden'], false);
    expect(m.containsKey('createdAt'), isFalse);
  });

  test('fromData: 복원(createdAt DateTime)', () {
    final now = DateTime(2026, 7, 6);
    final c = Comment.fromData('c9', {
      'authorUid': 'u2',
      'authorName': '느긋한수달2',
      'text': '역광이 멋져요',
      'createdAt': now,
    });
    expect(c.id, 'c9');
    expect(c.authorName, '느긋한수달2');
    expect(c.text, '역광이 멋져요');
    expect(c.createdAt, now);
  });

  test('fromData: 누락 필드는 안전한 기본값', () {
    final c = Comment.fromData('c', {});
    expect(c.authorUid, '');
    expect(c.text, '');
    expect(c.createdAt, isNull);
  });
}
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/community/comment_test.dart` → FAIL (파일 없음).
- [ ] **Step 3: 구현** — `lib/community/models/comment.dart`:

```dart
// lib/community/models/comment.dart
// 순수 Dart — Flutter/plugin import 금지.

class Comment {
  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime? createdAt;
  const Comment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    this.createdAt,
  });

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  /// reportCount/hidden은 함수 전용이지만 생성 기본값(0/false)은 규칙이 요구한다.
  Map<String, dynamic> toCreateMap() => {
    'authorUid': authorUid,
    'authorName': authorName,
    'text': text,
    'reportCount': 0,
    'hidden': false,
  };

  factory Comment.fromData(String id, Map<String, dynamic> data) => Comment(
    id: id,
    authorUid: (data['authorUid'] as String?) ?? '',
    authorName: (data['authorName'] as String?) ?? '',
    text: (data['text'] as String?) ?? '',
    createdAt: data['createdAt'] as DateTime?,
  );
}
```

- [ ] **Step 4:** `flutter test test/community/comment_test.dart` → PASS (3).
- [ ] **Step 5: 커밋**

```bash
git add lib/community/models/comment.dart test/community/comment_test.dart
git commit -m "feat: Comment 모델"
```

---

### Task 2: `onCommentWrite` 함수 + 규칙 + 인덱스

**Files:**
- Create: `functions/src/comments.ts`, `functions/test/comments.test.ts`
- Modify: `functions/src/index.ts`, `firestore.rules`, `firestore.indexes.json`

**Interfaces:** `commentDelta(before: boolean, after: boolean) -> number`, trigger `onCommentWrite`.

- [ ] **Step 1: 실패 테스트** — `functions/test/comments.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { commentDelta } from "../src/comments.js";

describe("commentDelta", () => {
  it("생성(+1)", () => expect(commentDelta(false, true)).toBe(1));
  it("삭제(-1)", () => expect(commentDelta(true, false)).toBe(-1));
  it("변화 없음(0)", () => {
    expect(commentDelta(true, true)).toBe(0);
    expect(commentDelta(false, false)).toBe(0);
  });
});
```

- [ ] **Step 2:** `cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run comments` → FAIL.
- [ ] **Step 3: 구현** — `functions/src/comments.ts`:

```ts
// functions/src/comments.ts
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

if (getApps().length === 0) initializeApp();

/** 댓글 문서 생성/삭제 delta: 생기면 +1, 사라지면 -1, 그 외 0. */
export function commentDelta(before: boolean, after: boolean): number {
  if (!before && after) return 1;
  if (before && !after) return -1;
  return 0;
}

export const onCommentWrite = onDocumentWritten(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    const delta = commentDelta(before, after);
    if (delta === 0) return;
    const postId = event.params.postId as string;
    await getFirestore()
      .collection("posts")
      .doc(postId)
      .update({ commentCount: FieldValue.increment(delta) });
  },
);
```

- [ ] **Step 4: export 추가** — `functions/src/index.ts`에 줄 추가(기존 export 아래):

```ts
export { onCommentWrite } from "./comments.js";
```

- [ ] **Step 5: Firestore 규칙** — `firestore.rules`의 `match /posts/{postId}` 블록 안, 기존 `match /likes/{uid} { ... }` 블록 **다음에** 추가:

```
      match /comments/{commentId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null
                      && request.resource.data.authorUid == request.auth.uid
                      && request.resource.data.reportCount == 0
                      && request.resource.data.hidden == false
                      && request.resource.data.text.size() <= 280;
        allow delete: if request.auth != null
                      && resource.data.authorUid == request.auth.uid;
        allow update: if false;
      }
```

- [ ] **Step 6: 복합 인덱스** — `firestore.indexes.json`의 `"indexes"` 배열에 항목 추가(기존 posts 인덱스 **뒤에**, 유효한 JSON 유지):

```json
    {
      "collectionGroup": "comments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "hidden", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    }
```

최종 `firestore.indexes.json`은 다음과 같아야 한다:

```json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "hidden", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "comments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "hidden", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

- [ ] **Step 7: 통과+빌드+커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run && npm run build && cd ..
git add functions/src/comments.ts functions/src/index.ts functions/test/comments.test.ts firestore.rules firestore.indexes.json
git commit -m "feat: 댓글 집계 함수 onCommentWrite + 규칙 + 인덱스"
```

> 배포는 사람: `firebase deploy --only functions,firestore:rules,firestore:indexes`.

---

### Task 3: `PostRepository` 댓글 메서드

**Files:**
- Modify: `lib/community/post_repository.dart`

**Interfaces:**
- Consumes: `Comment`(T1).
- Produces:
  - `Future<void> addComment({required String postId, required String uid, required String authorName, required String text})`
  - `Stream<List<Comment>> comments(String postId)`
  - `Future<void> deleteComment({required String postId, required String commentId})`

- [ ] **Step 1: import 추가** — `lib/community/post_repository.dart`의 `import 'models/post.dart';` 아래에 추가:

```dart
import 'models/comment.dart';
```

- [ ] **Step 2: 메서드 추가** — `likedByMe(...)` 메서드와 `_withDate(...)` 사이(클래스 안)에 아래 세 메서드를 그대로 추가:

```dart
  /// 게시물에 댓글을 추가한다. commentCount는 함수가 관리.
  Future<void> addComment({
    required String postId,
    required String uid,
    required String authorName,
    required String text,
  }) async {
    final comment = Comment(
      id: '',
      authorUid: uid,
      authorName: authorName,
      text: text,
    );
    await _db.collection('posts').doc(postId).collection('comments').add({
      ...comment.toCreateMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 댓글 목록(숨김 제외, 오래된 순).
  Stream<List<Comment>> comments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .where('hidden', isEqualTo: false)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (q) => q.docs
              .map((d) => Comment.fromData(d.id, _withDate(d.data())))
              .toList(),
        );
  }

  /// 댓글 삭제(본인 것만 — 규칙으로 강제).
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }
```

> `_withDate`(Timestamp→DateTime)는 이미 이 클래스에 있으니 재사용한다.

- [ ] **Step 3:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/post_repository.dart` → No issues found!
- [ ] **Step 4: 커밋**

```bash
git add lib/community/post_repository.dart
git commit -m "feat: PostRepository 댓글 추가·조회·삭제"
```

---

### Task 4: `PostDetailScreen`

**Files:**
- Create: `lib/community/screens/post_detail_screen.dart`

**Interfaces:**
- Consumes: `Post`(기존), `Comment`(T1), `PostRepository.{comments,addComment,deleteComment,likedByMe,toggleLike}`(T3+기존), `UserRepository.getProfile`(기존), `AuthService.currentUser`(기존).
- Produces: `class PostDetailScreen extends StatefulWidget { PostDetailScreen({required Post post, required AuthService auth, required PostRepository posts}) }`.

- [ ] **Step 1: 구현** — `lib/community/screens/post_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../post_repository.dart';
import '../user_repository.dart';
import '../models/post.dart';
import '../models/comment.dart';

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
      _input.clear();
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
    try {
      await widget.posts.deleteComment(
        postId: widget.post.id,
        commentId: c.id,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제에 실패했어요')));
      }
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
                StreamBuilder<List<Comment>>(
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
                    final items = snap.data!;
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
                                : null,
                          ),
                      ],
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

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/screens/post_detail_screen.dart` → No issues found!
- [ ] **Step 3: 커밋**

```bash
git add lib/community/screens/post_detail_screen.dart
git commit -m "feat: PostDetailScreen — 댓글 목록·작성·삭제"
```

---

### Task 5: 피드 카드에 댓글 버튼

**Files:**
- Modify: `lib/community/screens/feed_screen.dart`

**Interfaces:**
- Consumes: `PostDetailScreen`(T4).

- [ ] **Step 1: import 추가** — `feed_screen.dart` import 블록에 추가:

```dart
import 'post_detail_screen.dart';
```

- [ ] **Step 2: 카드에 auth 전달** — `ListView.builder`의 `itemBuilder`를 교체(현재 `_PostCard(post: items[i], posts: posts, uid: uid)`):

```dart
            itemBuilder: (_, i) => _PostCard(
              post: items[i],
              posts: posts,
              uid: uid,
              auth: auth,
            ),
```

- [ ] **Step 3: `_PostCard`에 auth 필드 추가** — 기존 필드·생성자를 교체:

```dart
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
```

- [ ] **Step 4: 좋아요 Row에 댓글 버튼 추가** — 기존 Row의 `Text('${post.likeCount}'), const SizedBox(width: 12),` 부분을 교체:

```dart
              Text('${post.likeCount}'),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
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
              Text('${post.commentCount}'),
```

- [ ] **Step 5:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test` → No issues found!
- [ ] **Step 6: 커밋**

```bash
git add lib/community/screens/feed_screen.dart
git commit -m "feat: 피드 카드에 댓글 버튼(상세 진입)"
```

---

### Task 6: 최종 검증

- [ ] **Step 1:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh` → `✅ verify 통과`.
- [ ] **Step 2:** `cd functions && npx vitest run` → 전부 PASS(commentDelta 포함).
- [ ] **Step 3: 기기 수동 검증 (사람)** — 함수/규칙/인덱스 배포 후 `flutter run`:
  - 피드 카드의 댓글 아이콘 → PostDetailScreen 진입, 사진·캡션·좋아요·"첫 댓글을 남겨보세요".
  - 댓글 입력 → 전송 → 목록에 즉시 표시, 피드의 `commentCount` 증가(함수 반영).
  - 본인 댓글 삭제 아이콘 → 확인 → 사라짐, 카운트 감소.
  - 타인 댓글엔 삭제 아이콘 없음.

---

## Self-Review (작성자 확인)

- **스펙 커버리지(D1):** Comment=T1, commentDelta/onCommentWrite/규칙/인덱스=T2, 저장소 메서드=T3, 상세·댓글 UI=T4, 진입 버튼=T5, 검증=T6. 편집 없음(스펙 범위).
- **플레이스홀더:** 없음 — 모든 코드·테스트 실제 내용 포함. (T3의 "placeholder to avoid unused import" 블록은 **쓰지 말라고 명시**하고 바로 실제 구현을 제공.)
- **타입 일관성:** `Comment{id,authorUid,authorName,text,createdAt,toCreateMap,fromData}`, `PostRepository.{addComment,comments,deleteComment}`, `PostDetailScreen({post,auth,posts})`, `commentDelta` — 태스크 간 일치. `_withDate`·`likedByMe`·`toggleLike`·`getProfile`·`UserProfile.nickname`은 기존과 동일.
- **주의:** commentCount/reportCount/hidden 클라이언트 쓰기 금지(규칙+함수). 인덱스는 comments 쿼리(hidden+createdAt asc)용. 배포는 사람.
```
