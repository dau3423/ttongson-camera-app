# 똥손카메라 — 커뮤니티 계획 D2: 신고 / 자동숨김 설계

> 상위 스펙 `2026-07-05-ttongson-community-design.md` §2.4·§5(신고/자동숨김) 구현 결정을 확정하는 서브 스펙.
> 계획 D를 D1(댓글, 완료·병합) → **D2(신고/자동숨김)** → D3(차단)으로 분할한 둘째 조각. B·C·D1 완료.

## 1. 목표 / 범위

- 로그인 사용자가 **게시물과 댓글을 신고**한다. 대상별 신고 수가 임계에 도달하면 **자동으로 숨김**(전역).
- **내가 신고한 항목은 전역 임계와 무관하게 나에게는 즉시 숨김**(클라이언트 필터).
- 신고 사유는 **사전 정의 목록**에서 선택.
- **범위 밖(D2):** 차단(D3), 관리자 UI(콘솔 수동), 신고 취소.

## 2. 핵심 결정 (확정)

- **신고 대상:** 게시물 + 댓글 둘 다.
- **중복 방지:** 신고 문서 id = reporterUid → 대상별 한 사용자 1건(좋아요 패턴).
- **임계:** 기본 **5**. 도달 시 `hidden=true`. **latch**(신고가 줄어도 자동 해제 안 함 — 해제는 관리자 콘솔).
- **본인 콘텐츠 신고 불가**(UI에서 신고 옵션 숨김).
- **재신고:** 규칙상 update 금지 → 실패 → UI 토스트('이미 신고했을 수 있어요').
- **내가 신고 → 나에게 숨김:** collectionGroup 쿼리로 내 신고 대상을 조회해 피드·댓글에서 클라이언트 필터.
- **신고 사유:** `['스팸/광고', '욕설·혐오 발언', '부적절한 사진', '개인정보 노출', '기타']`.
- **D2에 새 순수 Dart 로직 없음** — `moderation.dart`(차단 필터)는 D3. D2의 순수 로직은 함수 측(TS) `reportDelta`·`shouldHide`.

## 3. 데이터 모델 (Firestore)

```
posts/{postId}/reports/{reporterUid}
  reporterUid: string        # = 문서 id (collectionGroup 조회용 필드)
  reason: string             # 사전 정의 사유
  createdAt: timestamp

posts/{postId}/comments/{commentId}/reports/{reporterUid}
  reporterUid, reason, createdAt   # 동일 형태
```

- 대상(post·comment)의 `reportCount`/`hidden`은 **함수 전용 쓰기**(기존 규칙에서 클라이언트 update 금지 — Admin SDK 우회).

## 4. Cloud Function + 보안 규칙

`functions/src/reports.ts`:
- 순수 `reportDelta(before: boolean, after: boolean): number` — 생성 +1, 삭제 -1, 그 외 0. **vitest TDD.**
- 순수 `shouldHide(count: number, threshold = 5): boolean` — `count >= threshold`. **vitest TDD.**
- 공유 헬퍼 `applyReport(targetRef, delta)`: **트랜잭션** — 대상 문서를 읽어 `next = (reportCount ?? 0) + delta`, `hidden = (hidden ?? false) || shouldHide(next)`, `{ reportCount: next, hidden }` 갱신.
- 트리거 둘(각 경로 전용):
  - `onPostReportWrite`(`posts/{postId}/reports/{uid}` onDocumentWritten) → 대상 `posts/{postId}`.
  - `onCommentReportWrite`(`posts/{postId}/comments/{commentId}/reports/{uid}` onDocumentWritten) → 대상 `posts/{postId}/comments/{commentId}`.
  - 각각 `reportDelta`로 delta 계산, 0이면 skip, 아니면 `applyReport`.
- `functions/src/index.ts`에서 export.

`firestore.rules` — post reports와 comment reports 각각(대상 블록 내부):
- `read`: `request.auth != null && resource.data.reporterUid == request.auth.uid` (본인 신고만 — collectionGroup 쿼리 허용).
- `create`: `request.auth != null && request.resource.data.reporterUid == request.auth.uid && request.resource.data.reason is string`.
- `update, delete`: 금지.

> 인덱스: `reporterUid` 단일 필드 equality(collectionGroup)는 Firestore 자동 단일필드 인덱스로 커버 → **복합 인덱스 불필요**. 배포는 사람: `firebase deploy --only functions,firestore:rules`.

## 5. 저장소 (`PostRepository`에 추가)

- `Future<void> reportPost({required String postId, required String uid, required String reason})` → `posts/{postId}/reports/{uid}` set `{reporterUid: uid, reason, createdAt: serverTimestamp}`.
- `Future<void> reportComment({required String postId, required String commentId, required String uid, required String reason})` → 해당 경로 동일.
- `Stream<Set<String>> myReportedPostIds(String uid)` — `collectionGroup('reports').where('reporterUid', isEqualTo: uid)`, 각 문서의 상위 경로가 `posts/{postId}/reports/{uid}`인 것(게시물 직속)의 postId 집합.
- `Stream<Set<String>> myReportedCommentIds(String uid)` — 같은 쿼리에서 상위 경로가 `.../comments/{commentId}/reports/{uid}`인 것의 commentId 집합.
  - 게시물/댓글 신고 구분: 문서 참조의 `parent.parent.parent.id`가 `'posts'`면 게시물 신고(postId=`parent.parent.id`), `'comments'`면 댓글 신고(commentId=`parent.parent.id`).

## 6. 신고 사유 시트 (`lib/community/screens/report_sheet.dart`, 신규)

- `Future<String?> showReportSheet(BuildContext context)` — 사전 정의 사유를 나열하는 모달 바텀시트(`showModalBottomSheet`). 사유 탭 시 해당 문자열로 pop, 취소 시 null. 게시물·댓글 신고가 공유.
- 사유 목록은 이 파일의 `const reportReasons` 상수.

## 7. UI 연결

- `feed_screen.dart` `_PostCard`: **본인 글이 아니면** ⋮(`PopupMenuButton`)에 '신고하기' → `showReportSheet` → 사유 있으면 `reportPost` → 성공('신고되었습니다')/실패 토스트.
- **피드 필터**: `FeedScreen`에서 `myReportedPostIds(uid)`를 구독해, `feed()` 결과에서 내가 신고한 postId를 제외하고 렌더(중첩 StreamBuilder).
- `post_detail_screen.dart` 댓글: **타인 댓글**엔 신고 액션(아이콘/메뉴) → `showReportSheet` → `reportComment`. **본인 댓글**엔 기존 삭제(D1).
- **댓글 필터**: `comments()` 결과에서 `myReportedCommentIds(uid)`를 구독해 내가 신고한 commentId 제외.

## 8. 자동숨김 효과

- 전역: `hidden=true`가 되면 기존 `feed()`(hidden==false)·`comments()`(hidden==false) 쿼리가 자동 제외 → **클라이언트 추가 변경 없음**.
- 개인: §5·§7의 collectionGroup 필터로 내 신고 항목을 내 화면에서 제외.

## 9. 에러 처리

- 신고 실패(재신고 포함) → 토스트. 성공 → '신고되었습니다'.
- `myReported*` 스트림 에러 시 필터 대상 없음으로 간주(피드/댓글은 계속 표시) — 신고 숨김은 best-effort, 원본 조회를 막지 않는다.
- 본인 콘텐츠엔 신고 옵션을 노출하지 않는다.

## 10. 테스트

- **순수 TDD(TS)**: `functions/test/reports.test.ts` — `reportDelta`(생성/삭제/무변화), `shouldHide`(임계 미만/도달/초과, 커스텀 임계).
- **저장소/UI/함수 트리거**: 구현 + 기기 수동 검증(플러그인·트랜잭션·UI).
- 게이트: 앱 `tool/verify.sh`, 함수 `npx vitest run`, 정적분석 `dart analyze lib test`(`flutter analyze` 금지).

## 11. 완료 정의 (D2)

로그인 사용자가 게시물/댓글의 신고 메뉴로 사유를 선택해 신고하면, 그 항목이 **내 화면에서 즉시 사라진다**. 서로 다른 사용자 5명이 같은 대상을 신고하면 함수가 `hidden=true`로 만들어 **모두의 피드에서 사라진다**. 본인 콘텐츠엔 신고 옵션이 없다. `tool/verify.sh`·`vitest` 통과.
