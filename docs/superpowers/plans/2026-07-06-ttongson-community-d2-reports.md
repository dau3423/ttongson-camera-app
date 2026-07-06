# 커뮤니티 계획 D2 — 신고 / 자동숨김 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 사용자가 게시물·댓글을 신고하면 내 화면에서 즉시 사라지고, 서로 다른 5명이 같은 대상을 신고하면 함수가 전역 숨김 처리한다.

**Architecture:** 대상별 `reports/{reporterUid}` 서브컬렉션(중복 방지, 좋아요 패턴). 순수 `reportDelta`·`shouldHide`(TS, vitest TDD)와 두 트랜잭션 트리거가 `reportCount`/`hidden`을 관리. `PostRepository`에 신고·내신고조회 메서드 추가. 내가 신고한 항목은 `collectionGroup('reports')` 쿼리로 클라이언트에서 피드·댓글에서 제외.

**Tech Stack:** Flutter(Dart), `cloud_firestore`, `firebase_auth`; Functions v2 Firestore 트리거(TS, vitest). B·C·D1 완료·병합. 신규 의존성 없음.

## Global Constraints

- 신고 문서: `posts/{postId}/reports/{reporterUid}` 및 `posts/{postId}/comments/{commentId}/reports/{reporterUid}` = `{reporterUid, reason, createdAt}`. 문서 id = reporterUid(대상별 1건, 중복 방지).
- `reportCount`/`hidden`(post·comment)은 **함수 전용 쓰기**(기존 규칙 update 금지, Admin SDK 우회). 임계 기본 **5**, 도달 시 `hidden=true` **latch**(자동 해제 없음).
- 신고 사유는 사전 정의: `['스팸/광고', '욕설·혐오 발언', '부적절한 사진', '개인정보 노출', '기타']`.
- **본인 콘텐츠 신고 옵션 미노출**(UI). **재신고**는 규칙 update 금지 → 실패 → 토스트.
- **내가 신고 → 나에게 숨김**: `collectionGroup('reports').where('reporterUid', ==, uid)`로 조회해 피드·댓글에서 제외.
- reports read 규칙은 **필드 기반**: `resource.data.reporterUid == request.auth.uid`(collectionGroup 허용). `reporterUid` 단일필드 인덱스는 자동 → 복합 인덱스 불필요.
- 순수 로직 TDD(TS). Firestore/UI/트리거는 구현 + 기기 검증.
- 앱 게이트 `tool/verify.sh`, 함수 게이트 `npx vitest run`. 정적분석 `dart analyze lib test`(**`flutter analyze` 금지**). Flutter SDK `/Users/soonbok/flutter/bin`.
- 커밋: Conventional Commits + `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

```
functions/
  src/reports.ts             # (신규) reportDelta·shouldHide·onPost/CommentReportWrite
  src/index.ts               # (수정) export 추가
  test/reports.test.ts       # (신규)
firestore.rules              # (수정) post/comment reports match
lib/community/
  post_repository.dart       # (수정) reportPost·reportComment·myReportedPostIds·myReportedCommentIds
  screens/report_sheet.dart  # (신규) showReportSheet + reportReasons
  screens/feed_screen.dart   # (수정) 카드 ⋮ 신고 + 내신고 게시물 제외
  screens/post_detail_screen.dart  # (수정) 댓글 신고 + 내신고 댓글 제외
```

---

### Task 1: `reports.ts` 함수 + 규칙

**Files:**
- Create: `functions/src/reports.ts`, `functions/test/reports.test.ts`
- Modify: `functions/src/index.ts`, `firestore.rules`

**Interfaces:** `reportDelta(before, after) -> number`, `shouldHide(count, threshold=5) -> boolean`, triggers `onPostReportWrite`·`onCommentReportWrite`.

- [ ] **Step 1: 실패 테스트** — `functions/test/reports.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { reportDelta, shouldHide } from "../src/reports.js";

describe("reportDelta", () => {
  it("생성(+1)", () => expect(reportDelta(false, true)).toBe(1));
  it("삭제(-1)", () => expect(reportDelta(true, false)).toBe(-1));
  it("변화 없음(0)", () => {
    expect(reportDelta(true, true)).toBe(0);
    expect(reportDelta(false, false)).toBe(0);
  });
});

describe("shouldHide", () => {
  it("임계 미만은 false", () => expect(shouldHide(4)).toBe(false));
  it("임계 도달은 true", () => expect(shouldHide(5)).toBe(true));
  it("임계 초과는 true", () => expect(shouldHide(6)).toBe(true));
  it("커스텀 임계", () => {
    expect(shouldHide(2, 3)).toBe(false);
    expect(shouldHide(3, 3)).toBe(true);
  });
});
```

- [ ] **Step 2:** `cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run reports` → FAIL.
- [ ] **Step 3: 구현** — `functions/src/reports.ts`:

```ts
// functions/src/reports.ts
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, DocumentReference } from "firebase-admin/firestore";

if (getApps().length === 0) initializeApp();

/** 신고 문서 생성/삭제 delta: 생기면 +1, 사라지면 -1, 그 외 0. */
export function reportDelta(before: boolean, after: boolean): number {
  if (!before && after) return 1;
  if (before && !after) return -1;
  return 0;
}

/** 신고 수가 임계에 도달하면 숨김. */
export function shouldHide(count: number, threshold = 5): boolean {
  return count >= threshold;
}

/** 대상의 reportCount를 delta만큼 조정하고, 임계 도달 시 hidden=true(latch). */
async function applyReport(
  target: DocumentReference,
  delta: number,
): Promise<void> {
  const db = getFirestore();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(target);
    if (!snap.exists) return;
    const cur = (snap.data()?.reportCount ?? 0) as number;
    const next = cur + delta;
    const wasHidden = (snap.data()?.hidden ?? false) as boolean;
    tx.update(target, { reportCount: next, hidden: wasHidden || shouldHide(next) });
  });
}

export const onPostReportWrite = onDocumentWritten(
  "posts/{postId}/reports/{uid}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    const delta = reportDelta(before, after);
    if (delta === 0) return;
    const postId = event.params.postId as string;
    await applyReport(getFirestore().collection("posts").doc(postId), delta);
  },
);

export const onCommentReportWrite = onDocumentWritten(
  "posts/{postId}/comments/{commentId}/reports/{uid}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    const delta = reportDelta(before, after);
    if (delta === 0) return;
    const postId = event.params.postId as string;
    const commentId = event.params.commentId as string;
    await applyReport(
      getFirestore()
        .collection("posts")
        .doc(postId)
        .collection("comments")
        .doc(commentId),
      delta,
    );
  },
);
```

- [ ] **Step 4: export 추가** — `functions/src/index.ts`에 줄 추가(기존 export 아래):

```ts
export { onPostReportWrite, onCommentReportWrite } from "./reports.js";
```

- [ ] **Step 5: Firestore 규칙** — `firestore.rules`:

(5a) `match /posts/{postId}` 블록 안, 기존 `match /comments/{commentId} { ... }` 블록 **다음에** 게시물 신고 블록 추가:

```
      match /reports/{uid} {
        allow read: if request.auth != null
                    && resource.data.reporterUid == request.auth.uid;
        allow create: if request.auth != null
                      && request.resource.data.reporterUid == request.auth.uid
                      && request.resource.data.reason is string;
        allow update, delete: if false;
      }
```

(5b) `match /comments/{commentId}` 블록 안(기존 create/delete/update 규칙 **다음, 닫는 `}` 앞**)에 댓글 신고 블록 추가:

```
        match /reports/{uid} {
          allow read: if request.auth != null
                      && resource.data.reporterUid == request.auth.uid;
          allow create: if request.auth != null
                        && request.resource.data.reporterUid == request.auth.uid
                        && request.resource.data.reason is string;
          allow update, delete: if false;
        }
```

- [ ] **Step 6: 통과+빌드+커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run && npm run build && cd ..
git add functions/src/reports.ts functions/src/index.ts functions/test/reports.test.ts firestore.rules
git commit -m "feat: 신고 집계 함수 onPost/CommentReportWrite + 규칙"
```

> 배포는 사람: `firebase deploy --only functions,firestore:rules`.

---

### Task 2: `PostRepository` 신고 메서드

**Files:**
- Modify: `lib/community/post_repository.dart`

**Interfaces:**
- Produces:
  - `Future<void> reportPost({required String postId, required String uid, required String reason})`
  - `Future<void> reportComment({required String postId, required String commentId, required String uid, required String reason})`
  - `Stream<Set<String>> myReportedPostIds(String uid)`
  - `Stream<Set<String>> myReportedCommentIds(String uid)`

- [ ] **Step 1: 메서드 추가** — `lib/community/post_repository.dart`의 `deleteComment(...)` 메서드와 `_withDate(...)` 사이(클래스 안)에 추가:

```dart
  /// 게시물 신고(대상별 1건, 문서 id=uid). reportCount/hidden은 함수가 관리.
  Future<void> reportPost({
    required String postId,
    required String uid,
    required String reason,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('reports')
        .doc(uid)
        .set({
          'reporterUid': uid,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// 댓글 신고(대상별 1건, 문서 id=uid).
  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String uid,
    required String reason,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('reports')
        .doc(uid)
        .set({
          'reporterUid': uid,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// 내가 신고한 게시물 id 집합(collectionGroup). 경로가 posts/{id}/reports/{uid}인 것.
  Stream<Set<String>> myReportedPostIds(String uid) {
    return _db
        .collectionGroup('reports')
        .where('reporterUid', isEqualTo: uid)
        .snapshots()
        .map((q) {
          final ids = <String>{};
          for (final d in q.docs) {
            final target = d.reference.parent.parent; // post 또는 comment 문서
            if (target != null && target.parent.id == 'posts') {
              ids.add(target.id);
            }
          }
          return ids;
        });
  }

  /// 내가 신고한 댓글 id 집합(collectionGroup). 경로가 .../comments/{id}/reports/{uid}인 것.
  Stream<Set<String>> myReportedCommentIds(String uid) {
    return _db
        .collectionGroup('reports')
        .where('reporterUid', isEqualTo: uid)
        .snapshots()
        .map((q) {
          final ids = <String>{};
          for (final d in q.docs) {
            final target = d.reference.parent.parent; // post 또는 comment 문서
            if (target != null && target.parent.id == 'comments') {
              ids.add(target.id);
            }
          }
          return ids;
        });
  }
```

> 경로 판별: 신고 문서 `d.reference`의 `parent`(reports 컬렉션)→`parent`(대상 문서)가 `target`. `target.parent.id`가 `'posts'`면 게시물 신고, `'comments'`면 댓글 신고.

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/post_repository.dart` → No issues found!
- [ ] **Step 3: 커밋**

```bash
git add lib/community/post_repository.dart
git commit -m "feat: PostRepository 신고·내신고 조회 메서드"
```

---

### Task 3: 신고 사유 시트

**Files:**
- Create: `lib/community/screens/report_sheet.dart`

**Interfaces:**
- Produces: `const List<String> reportReasons`, `Future<String?> showReportSheet(BuildContext context)`.

- [ ] **Step 1: 구현** — `lib/community/screens/report_sheet.dart`:

```dart
import 'package:flutter/material.dart';

/// 신고 사유(사전 정의).
const List<String> reportReasons = [
  '스팸/광고',
  '욕설·혐오 발언',
  '부적절한 사진',
  '개인정보 노출',
  '기타',
];

/// 신고 사유 선택 바텀시트. 선택 시 사유 문자열, 취소 시 null.
Future<String?> showReportSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '신고 사유를 선택하세요',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final reason in reportReasons)
            ListTile(
              title: Text(reason),
              onTap: () => Navigator.pop(ctx, reason),
            ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/screens/report_sheet.dart` → No issues found!
- [ ] **Step 3: 커밋**

```bash
git add lib/community/screens/report_sheet.dart
git commit -m "feat: 신고 사유 선택 바텀시트"
```

---

### Task 4: 피드 카드 신고 + 내신고 제외

**Files:**
- Modify: `lib/community/screens/feed_screen.dart`

**Interfaces:**
- Consumes: `PostRepository.{reportPost,myReportedPostIds}`(T2), `showReportSheet`(T3).

- [ ] **Step 1: import 추가** — `feed_screen.dart` import 블록에 추가:

```dart
import 'report_sheet.dart';
```

- [ ] **Step 2: body 교체(내신고 제외)** — `FeedScreen.build`의 `body: StreamBuilder<List<Post>>( ... )` 전체를 아래로 교체:

```dart
      body: StreamBuilder<Set<String>>(
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
              final items = snap.data!
                  .where((p) => !reported.contains(p.id))
                  .toList();
              if (items.isEmpty) {
                return const Center(child: Text('아직 게시물이 없어요. 첫 사진을 올려보세요!'));
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => _PostCard(
                  post: items[i],
                  posts: posts,
                  uid: uid,
                  auth: auth,
                ),
              );
            },
          );
        },
      ),
```

- [ ] **Step 3: 카드 헤더에 ⋮ 신고 메뉴** — `_PostCard.build`의 작성자명 Padding(현재 `Padding( ... child: Text(post.authorName, ...))`)을 아래로 교체:

```dart
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
                    onSelected: (_) => _report(context),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: Text('신고하기')),
                    ],
                  ),
              ],
            ),
          ),
```

- [ ] **Step 4: `_report` 메서드 추가** — `_PostCard` 클래스 안(`build` 위)에 추가:

```dart
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
```

- [ ] **Step 5:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test` → No issues found!
- [ ] **Step 6: 커밋**

```bash
git add lib/community/screens/feed_screen.dart
git commit -m "feat: 피드 카드 신고 메뉴 + 내가 신고한 게시물 제외"
```

---

### Task 5: 댓글 신고 + 내신고 제외

**Files:**
- Modify: `lib/community/screens/post_detail_screen.dart`

**Interfaces:**
- Consumes: `PostRepository.{reportComment,myReportedCommentIds}`(T2), `showReportSheet`(T3).

- [ ] **Step 1: import 추가** — `post_detail_screen.dart` import 블록에 추가:

```dart
import 'report_sheet.dart';
```

- [ ] **Step 2: `_reportComment` 메서드 추가** — `_confirmDelete(...)` 메서드 아래에 추가:

```dart
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
```

- [ ] **Step 3: 댓글 StreamBuilder 교체(내신고 제외 + 신고 액션)** — 기존 `StreamBuilder<List<Comment>>( ... )` 전체(Divider 다음의 그 블록)를 아래로 교체:

```dart
                StreamBuilder<Set<String>>(
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
                        final items = snap.data!
                            .where((c) => !reported.contains(c.id))
                            .toList();
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
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.flag_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => _reportComment(c),
                                      ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
```

- [ ] **Step 4:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test` → No issues found!
- [ ] **Step 5: 커밋**

```bash
git add lib/community/screens/post_detail_screen.dart
git commit -m "feat: 댓글 신고 + 내가 신고한 댓글 제외"
```

---

### Task 6: 최종 검증

- [ ] **Step 1:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh` → `✅ verify 통과`.
- [ ] **Step 2:** `cd functions && npx vitest run` → 전부 PASS(reportDelta·shouldHide 포함).
- [ ] **Step 3: 기기 수동 검증 (사람)** — 함수/규칙 배포 후 `flutter run`:
  - 타인 게시물 ⋮ → '신고하기' → 사유 선택 → '신고되었습니다', **그 글이 내 피드에서 사라짐**.
  - 타인 댓글 🚩 → 사유 → 신고 → **그 댓글이 내 목록에서 사라짐**.
  - 본인 글/댓글엔 신고 옵션 없음(본인 댓글은 삭제만).
  - 서로 다른 5개 계정으로 같은 글 신고 → `hidden=true` → 모두의 피드에서 사라짐(함수).
  - 재신고 시도 → 실패 토스트.

---

## Self-Review (작성자 확인)

- **스펙 커버리지(D2):** reports 함수(reportDelta·shouldHide·두 트리거·트랜잭션 latch)+규칙=T1, 저장소(reportPost·reportComment·myReported*)=T2, 사유 시트=T3, 게시물 신고+피드 필터=T4, 댓글 신고+댓글 필터=T5, 검증=T6. moderation.dart(차단 필터)는 D3.
- **플레이스홀더:** 없음 — 모든 코드·테스트 실제 내용 포함.
- **타입 일관성:** `reportDelta`·`shouldHide`(TS), `PostRepository.{reportPost,reportComment,myReportedPostIds,myReportedCommentIds}`, `showReportSheet`·`reportReasons`, `_report`/`_reportComment` — 태스크 간 일치. 기존 `feed()`·`comments()`·`_PostCard`·`_confirmDelete`는 그대로 재사용.
- **주의:** reports read는 필드 기반(collectionGroup 허용). reportCount/hidden은 함수 전용(기존 update 금지 규칙 유지). 본인 콘텐츠 신고는 UI 미노출(규칙 강제 아님, 무해). 배포는 사람.
```
