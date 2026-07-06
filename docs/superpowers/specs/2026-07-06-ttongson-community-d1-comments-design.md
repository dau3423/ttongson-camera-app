# 똥손카메라 — 커뮤니티 계획 D1: 댓글 설계

> 상위 스펙 `2026-07-05-ttongson-community-design.md` §2.4·§5(댓글) 구현 결정을 확정하는 서브 스펙.
> 계획 D(댓글·신고·차단)를 **D1(댓글) → D2(신고/자동숨김) → D3(차단)** 로 분할한 첫 조각. B(게시·피드·좋아요)·C(가림)는 완료·병합됨.

## 1. 목표 / 범위

- 로그인 사용자가 게시물에 **댓글을 작성·조회하고 본인 댓글을 삭제**한다.
- 댓글 화면은 **PostDetailScreen**(사진+캡션+좋아요 + 댓글 목록 + 입력란). 피드 카드의 댓글 버튼으로 진입.
- **범위 밖(D1):** 댓글 수정(편집), 신고/자동숨김(D2), 차단(D3). D1은 `hidden` 필드·필터만 마련하고 숨김 트리거는 D2에서 붙인다.

## 2. 핵심 결정 (확정)

- **기능:** 작성 + 본인 삭제. 수정(편집) 없음(YAGNI).
- **화면:** `PostDetailScreen`. D2/D3의 신고·차단 액션이 얹힐 홈.
- **정렬:** 댓글은 `createdAt` **오름차순**(대화 순).
- **저장소:** 별도 CommentRepository를 만들지 않고 **`PostRepository`에 댓글 메서드 추가**(좋아요도 여기 있으므로 post 서브컬렉션 접근을 한곳에).
- **text 상한 280자**: UI `maxLength` + **Firestore 규칙 `text.size() <= 280`** 서버 강제.
- `reportCount`/`hidden`은 **클라이언트 쓰기 금지**(함수 전용). 생성 시 0/false 기본값만 허용.
- 작성자명은 작성 시점 닉네임 비정규화(`UserRepository.getProfile`, 폴백 '익명') — 게시물과 동일.

## 3. 데이터 모델 (Firestore)

```
posts/{postId}/comments/{commentId}
  authorUid: string
  authorName: string      # 비정규화(작성 시점 닉네임)
  text: string            # <=280자
  createdAt: timestamp    # serverTimestamp
  reportCount: int        # 함수 전용 쓰기(D2)
  hidden: bool            # 자동 숨김(함수 전용, D2)
```

`Comment` 값 객체(순수): `id, authorUid, authorName, text, createdAt?`. `reportCount`/`hidden`은 모델에 두지 않는다(표시에 불필요, 게시물 `Post`와 동일 패턴 — `toCreateMap`이 0/false로 기록, 조회는 `hidden==false` 필터).

- `Map toCreateMap()` → `{authorUid, authorName, text, reportCount:0, hidden:false}` (createdAt 제외).
- `Comment.fromData(String id, Map data)` → createdAt은 `DateTime?`.

## 4. Cloud Function + 보안 규칙

- `functions/src/comments.ts`:
  - 순수 `commentDelta(before: boolean, after: boolean): number` — 생성 +1, 삭제 -1, 그 외 0(`likeDelta`와 동형). **vitest TDD.**
  - `onCommentWrite`(`posts/{postId}/comments/{commentId}` onDocumentWritten): delta 계산 후 부모 post `commentCount`를 `FieldValue.increment(delta)`. delta 0이면 skip. `functions/src/index.ts`에서 export.
- `firestore.rules` — `posts/{postId}` 블록 안 `comments/{commentId}` match:
  - `read`: 로그인 사용자.
  - `create`: 로그인 + `authorUid == request.auth.uid` + `reportCount == 0` + `hidden == false` + `text.size() <= 280`.
  - `delete`: 로그인 + `resource.data.authorUid == request.auth.uid`.
  - `update`: 금지.
- **복합 인덱스**: `firestore.indexes.json`에 comments 쿼리용 인덱스 추가 — collectionGroup `comments`, queryScope COLLECTION, fields `hidden ASC` + `createdAt ASC`. (계획 B의 인덱스 누락 교훈 반영: 없으면 첫 조회 시 `hasError`.)

> 규칙·함수·인덱스 배포는 사람: `firebase deploy --only functions,firestore:rules,firestore:indexes`.

## 5. 저장소 (`PostRepository`에 추가)

- `Future<void> addComment({required String postId, required String uid, required String authorName, required String text})` — `posts/{postId}/comments`에 `toCreateMap` + `createdAt: serverTimestamp` 문서 생성.
- `Stream<List<Comment>> comments(String postId)` — `where('hidden', isEqualTo: false).orderBy('createdAt')`(오름차순), Timestamp→DateTime 변환.
- `Future<void> deleteComment({required String postId, required String commentId})` — 문서 삭제.

`likeCount`처럼 `commentCount`는 클라이언트가 직접 쓰지 않는다(함수 전용).

## 6. 화면

- `lib/community/screens/post_detail_screen.dart` (신규):
  - 상단: 사진(`Image.network`), 작성자명, 캡션, 좋아요(기존 `likedByMe`/`toggleLike` 재사용).
  - 중간: 댓글 목록(`comments(postId)` 스트림, 오름차순). 각 댓글에 작성자명·text·시간. **본인 댓글**엔 삭제(확인 다이얼로그 → `deleteComment`).
  - 하단: 입력란(`maxLength: 280`) + 전송 버튼 → `addComment`(닉네임은 `getProfile`).
  - 로딩/빈 목록/에러 상태 문구.
- `lib/community/screens/feed_screen.dart` `_PostCard` 수정: 좋아요 옆에 **댓글 아이콘 + `commentCount`** → 탭 시 `PostDetailScreen(post, auth, posts)` push.

## 7. 에러 처리

- 댓글 스트림 에러 → '댓글을 불러오지 못했어요'. 빈 목록 → '첫 댓글을 남겨보세요'.
- 전송 실패 → 토스트, 입력 유지. 삭제는 확인 다이얼로그 후 실행, 실패 시 토스트.
- 미로그인 상태로 PostDetail에 도달하지 않도록(피드는 로그인 게이트 뒤) — 입력란은 uid 없으면 비활성.

## 8. 테스트

- **순수 TDD**: `test/community/comment_test.dart`(toCreateMap 0/false·createdAt 제외, fromData 복원), `functions/test/comments.test.ts`(commentDelta 생성/삭제/무변화).
- **저장소/화면**: 구현 + 기기 수동 검증(플러그인·UI). 억지 단위테스트 금지.
- 게이트: 앱 `tool/verify.sh`, 함수 `npx vitest run`, 정적분석 `dart analyze lib test`(`flutter analyze` 금지).

## 9. 완료 정의 (D1)

로그인 사용자가 피드 카드의 댓글 버튼으로 PostDetailScreen에 들어가 댓글을 작성하면 목록에 즉시 보이고 `commentCount`가 함수로 증가한다. 본인 댓글을 삭제하면 목록에서 사라지고 카운트가 감소한다. `tool/verify.sh`·`vitest` 통과.
