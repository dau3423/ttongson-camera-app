# 똥손카메라 — 커뮤니티 계획 D3: 차단 설계

> 상위 스펙 `2026-07-05-ttongson-community-design.md` §2.4·§5(차단) 구현 결정을 확정하는 서브 스펙.
> 계획 D를 D1(댓글)·D2(신고/자동숨김, 완료·병합) → **D3(차단)** 으로 분할한 마지막 조각. B·C·D1·D2 완료. 커뮤니티 MVP의 마지막 단계.

## 1. 목표 / 범위

- 로그인 사용자가 **다른 사용자를 차단**하면, 그 사용자의 **게시물과 댓글이 내 화면에서 사라진다**(클라이언트 필터).
- **차단 목록 화면**에서 차단을 **해제**할 수 있다.
- **범위 밖(D3):** 운영자 계정 정지(`users.blocked`), 차단 시 알림. 차단은 나에게만 적용(상대는 모름).

## 2. 핵심 결정 (확정)

- **차단 범위:** 게시물 + 댓글 둘 다(차단 작성자 콘텐츠 전부 숨김).
- **해제:** 차단 목록 화면에서 해제(피드 AppBar 사람 아이콘으로 진입).
- **차단 실행:** 확인 다이얼로그 후.
- **필터 통합:** `moderation.visibleItems`(순수)로 **차단 작성자 + 내가 신고한 항목**을 함께 제외. D2에서 인라인으로 하던 신고 필터를 이 함수로 통합.
- **차단 문서:** `blocks/{myUid}/blocked/{blockedUid}` = `{blockedName, createdAt}`(이름 비정규화 — 목록 화면용). 본인 것만 read/write.
- **적용 범위:** 나에게만(상대에겐 영향 없음). 함수·카운터 없음.

## 3. 데이터 모델 (Firestore)

```
blocks/{uid}/blocked/{blockedUid}
  blockedName: string      # 차단 시점 상대 닉네임(목록 표시용)
  createdAt: timestamp
```

- 문서 존재 = uid가 blockedUid를 차단.
- `BlockedUser` 값 객체(순수): `{uid, name}`, `BlockedUser.fromData(String uid, Map data)`(name = blockedName).

## 4. 순수 필터 — `lib/community/moderation.dart` (신규, TDD)

```
List<T> visibleItems<T>(
  List<T> items, {
  required String Function(T) authorUidOf,
  required String Function(T) idOf,
  required Set<String> blockedAuthors,
  required Set<String> reportedIds,
})
```

- `blockedAuthors`에 속한 작성자(authorUidOf) 또는 `reportedIds`에 속한 id(idOf)인 항목을 제외한 리스트 반환.
- 순수 Dart — Flutter/plugin import 금지. 피드(Post)·댓글(Comment) 공용. **TDD**(차단 제외·신고 제외·둘 다·빈 집합=전부 표시).

## 5. 저장소 (`UserRepository`에 추가) + 보안 규칙

- `Future<void> blockUser({required String uid, required String blockedUid, required String blockedName})` → `blocks/{uid}/blocked/{blockedUid}` set `{blockedName, createdAt: serverTimestamp}`.
- `Future<void> unblockUser({required String uid, required String blockedUid})` → 해당 문서 delete.
- `Stream<Set<String>> blockedUids(String uid)` — `blocks/{uid}/blocked` 스냅샷 → 차단 uid(문서 id) 집합(필터용).
- `Stream<List<BlockedUser>> blockedList(String uid)` — 같은 컬렉션 → `BlockedUser`(uid+name) 목록(목록 화면용, createdAt 내림차순).

`firestore.rules` — `blocks/{uid}/blocked/{blockedUid}`:
- `allow read, write: if request.auth != null && request.auth.uid == uid` (본인 것만).

> 함수 없음. 인덱스: `blocks/{uid}/blocked` 단순 컬렉션 조회(단일 createdAt orderBy는 자동 단일필드 인덱스) → 복합 인덱스 불필요. 규칙 배포는 사람.

## 6. 차단 목록 화면 (`lib/community/screens/blocked_users_screen.dart`, 신규)

- `BlockedUsersScreen({required AuthService auth, UserRepository? users})`.
- `blockedList(uid)` 스트림 → 차단한 사용자 목록(이름 + 해제 버튼). 각 해제 → `unblockUser`.
- 빈 목록: '차단한 사용자가 없어요'. 로딩/에러 상태.

## 7. UI 연결

- 피드 AppBar에 **차단 목록 진입 액션**(사람 아이콘) → `BlockedUsersScreen`.
- 피드 카드 ⋮ 메뉴(본인 글 아니면): 기존 '신고하기' + **'차단하기'** → 확인 다이얼로그 → `blockUser(blockedUid: post.authorUid, blockedName: post.authorName)`.
- 상세 댓글(타인): 기존 신고 아이콘을 **⋮ 메뉴(신고하기 + 차단하기)** 로 변경. 차단은 댓글 작성자(authorUid/authorName) 대상.
- **필터 통합**: 피드·댓글 빌더에서 `blockedUids(uid)` + 기존 `myReported*(uid)`를 구독하고 `moderation.visibleItems`로 함께 필터(중첩 StreamBuilder).

## 8. 에러 처리

- 차단/해제 실패 → 토스트. 차단은 확인 다이얼로그 후 실행.
- 필터 스트림(`blockedUids`·`myReported*`) 에러/미로딩 → 빈 집합으로 간주(콘텐츠 계속 표시, best-effort).
- 미로그인 상태로 진입하지 않도록(피드는 로그인 게이트 뒤). 본인 콘텐츠엔 차단 옵션 미노출.

## 9. 테스트

- **순수 TDD**: `test/community/blocked_user_test.dart`(fromData), `test/community/moderation_test.dart`(visibleItems — 차단·신고·복합·빈 집합).
- **저장소/화면**: 구현 + 기기 수동 검증(플러그인·UI).
- 게이트: 앱 `tool/verify.sh`, 정적분석 `dart analyze lib test`(`flutter analyze` 금지).

## 10. 완료 정의 (D3 / 커뮤니티 MVP)

로그인 사용자가 게시물/댓글의 ⋮ 메뉴에서 상대를 차단하면 그 사람의 게시물·댓글이 **내 피드·상세에서 즉시 사라진다**. 차단 목록 화면에서 해제하면 다시 보인다. 본인 콘텐츠엔 차단 옵션이 없다. `tool/verify.sh` 통과. → 커뮤니티 A·B·C·D 전체 완료.
