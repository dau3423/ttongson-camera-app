# 똥손카메라 — 촬영 팁 공유 커뮤니티 기획서 (MVP)

- **작성일**: 2026-07-05
- **문서 유형**: 개발 기획서 (구현용)
- **상태**: 설계 확정, 구현 계획 수립 전
- **선행**: 온디바이스 가이드·클라우드 추천·촬영 모드·순차 단계형 가이드 완료.
  이 문서는 앱에 **소셜(커뮤니티) 계층**을 새로 추가한다.

---

## 1. 개요

### 1.1 한 줄 정의
사용자가 **사진 1장 + 한 줄 팁**을 올려 서로의 촬영을 배우는 피드형 커뮤니티.

### 1.2 문제/가치
"똥손"이 실제로 잘 찍힌 예시와 팁을 보며 배우고, 자기 사진을 공유해 **찍기→공유→영감→다시 찍기** 루프를 만든다.

### 1.3 핵심 결정 (확정)
- **콘텐츠**: 사진 1장 + 한 줄 자유 캡션(팁/질문). 사진은 갤러리에서 선택(image_picker).
- **상호작용**: 좋아요 + 댓글 + 신고.
- **로그인**: **Google · Apple · Kakao** 소셜 로그인. **커뮤니티 접근 자체가 회원 전용(피드 읽기 포함 로그인 필수)** + **✨구도 추천도 로그인 필수**. 로그인 없이 쓰는 건 **카메라 가이드뿐**.
- **개인정보 가림**: 업로드 전 **기기 내에서** 얼굴 자동 가림 + 수동 박스 가림(모자이크/스티커).
- **검열**: 신고 기반 + N회 신고 시 자동 숨김 + 사용자 차단. 관리자 검토는 Firestore 콘솔 수동.
- **피드 정렬**: 최신순 무한 스크롤.

### 1.4 기존 규정에 대한 영향
- `advise`(구도 추천) 클라우드 함수가 **Firebase Auth 로그인 토큰을 검증**하도록 바뀐다(현재 deviceId + App Check만). 미로그인 호출은 거부.
- 온디바이스 카메라 가이드는 **로그인과 무관하게** 계속 동작(변경 없음).
- **커뮤니티는 진입점부터 로그인 게이트로 감싼다** — 피드조차 로그인 후에만 보인다. 미로그인 사용자가 커뮤니티 버튼을 누르면 곧바로 Google 로그인 화면.

---

## 2. 백엔드 (Firebase 네이티브)

이미 Firebase(cloud_functions, app_check)를 쓰므로 **Auth + Firestore + Storage + Functions**로 확장한다.

### 2.1 신규 패키지
- 앱: `firebase_auth`, `google_sign_in`, `sign_in_with_apple`, `kakao_flutter_sdk_user`, `cloud_firestore`, `firebase_storage`, `image_picker`.
- (이미 있음: `firebase_core`, `firebase_app_check`, `cloud_functions`, `image`.)

### 2.1.1 소셜 로그인 제공자
셋 다 최종적으로 **Firebase Auth 사용자(uid)** 로 수렴한다 → Firestore/Storage 규칙은 uid만 보므로 이후 시스템은 동일.
- **Google**: `google_sign_in` → Firebase `GoogleAuthProvider` credential.
- **Apple**: `sign_in_with_apple` → Firebase `AppleAuthProvider`/OAuth credential. (iOS는 App Store 정책상 타 소셜 로그인 제공 시 Apple 로그인 필수. Apple Developer 설정·엔타이틀먼트 필요.)
- **Kakao**: `kakao_flutter_sdk_user`로 카카오 로그인 → 액세스 토큰을 **`kakaoCustomToken` 클라우드 함수**로 보내 검증(카카오 API) 후 **Firebase 커스텀 토큰** 발급 → 앱이 `signInWithCustomToken`. 네이티브 키(Android 키해시/네이티브 앱키, iOS URL 스킴) 설정 필요.

### 2.2 데이터 모델 (Firestore)
```
users/{uid}
  displayName: string          # Google 이름
  photoUrl: string|null
  createdAt: timestamp
  blocked: bool                # 운영자 차단(계정 정지)

posts/{postId}
  authorUid: string
  authorName: string           # 비정규화(피드 조회 편의)
  imageUrl: string             # Storage 다운로드 URL(가려진 이미지)
  caption: string              # 한 줄 팁 (<=140자)
  createdAt: timestamp
  likeCount: int               # 함수/트랜잭션으로 관리
  commentCount: int
  reportCount: int
  hidden: bool                 # 자동 숨김(함수 전용 쓰기)

posts/{postId}/likes/{uid}     # 문서 존재 = 좋아요
  createdAt: timestamp

posts/{postId}/comments/{commentId}
  authorUid, authorName, text (<=280자), createdAt, reportCount, hidden

reports/{reportId}
  targetType: 'post' | 'comment'
  targetPath: string           # 예: posts/abc 또는 posts/abc/comments/xyz
  reporterUid: string
  reason: string
  createdAt: timestamp

blocks/{uid}/blocked/{blockedUid}  # 문서 존재 = uid가 blockedUid를 차단
```

### 2.3 Storage
```
post_images/{uid}/{postId}.jpg   # 가림 처리된 최종 이미지만 저장
```
- 업로드 규칙: 본인 경로만, `image/jpeg`, 최대 크기 제한(예: 5MB).

### 2.4 Cloud Functions
- `onReportCreate`(reports/{id} onCreate): 대상 `reportCount++`, 임계(기본 5) 도달 시 `hidden=true`.
- `onLikeWrite`(posts/{id}/likes/{uid} onCreate·onDelete): `likeCount` 증감.
- `onCommentWrite`(comments onCreate·onDelete): `commentCount` 증감.
- `kakaoCustomToken`(호출형): 카카오 액세스 토큰을 받아 카카오 API로 검증 → 대응하는 Firebase 사용자 생성/조회 → **커스텀 토큰** 반환.
- `advise`(기존): **auth 컨텍스트 검증 추가** — `context.auth` 없으면 `unauthenticated` 반환.
- 임계값·집계는 **함수 전용 권한**으로만 필드를 수정(클라이언트는 `hidden`/`*Count` 직접 못 씀).

### 2.5 보안 규칙 (요지)
- **읽기**: 로그인 사용자, `hidden==false` 문서만.
- **쓰기(post/comment)**: 로그인 필수 + `authorUid == request.auth.uid`. `hidden`/`*Count`/`reportCount`는 클라이언트 쓰기 금지(함수만).
- **likes**: 본인 uid 문서만 생성/삭제.
- **reports**: 로그인 사용자 생성만(수정/삭제 불가).
- **blocks**: 본인 것만.
- **Storage**: 본인 경로 업로드만, 타입/용량 제한.

---

## 3. 개인정보 가림 (업로드 전, 기기 내)

### 3.1 원칙
가림은 **전부 기기에서** 수행하고, **가려진 이미지만** 업로드한다. 원본은 서버로 나가지 않는다.

### 3.2 흐름
```
갤러리 선택 → [가림 편집 화면] → 캡션 입력 → 업로드
```

### 3.3 기능
- **자동 얼굴 가림**: 앱의 ML Kit 얼굴 감지(재사용)로 얼굴 박스를 찾아 한 번에 가림.
- **수동 박스 가림**: 사용자가 드래그로 사각형 영역을 지정(번호판·문패 등). 자동 감지가 어려운 대상 담당.
- **가림 방식**: 각 영역마다 **모자이크(픽셀화)** 또는 **스티커(이모지/불투명 도형)** 선택.
- **되돌리기**: 추가한 가림 영역 개별 삭제.

### 3.4 처리(순수 로직 + 이미지 합성)
- 가림 영역 목록(정규화 사각형 + 방식)은 **순수 데이터**로 관리 → 좌표 변환·모자이크 블록 계산은 순수 함수로 TDD.
- 실제 픽셀 처리는 `image` 패키지로: 모자이크=영역 다운스케일→업스케일, 스티커=영역에 도형/이모지 합성. 결과를 JPEG 재인코딩.
- 얼굴 감지 좌표는 기존 `box_normalize`(회전 보정)와 동일 규약으로 이미지 픽셀 좌표에 매핑.

### 3.5 안전장치
- 얼굴이 감지되면 편집 화면 진입 시 **기본으로 얼굴 가림을 켜 둔다**(사용자가 해제 가능) — 실수로 얼굴 노출 방지.

---

## 4. 앱 구조 (신규)

계산(순수) ↔ 렌더/네트워크 분리 원칙 유지.

```
lib/community/
  auth_service.dart              # Google/Apple/Kakao 로그인·로그아웃·현재 사용자 (모두 Firebase Auth uid로 수렴)
  community_repository.dart      # Firestore/Storage 접근(게시·피드·좋아요·댓글·신고·차단)
  models/
    post.dart comment.dart mask_region.dart   # 값 객체(순수)
  moderation.dart                # 순수: 신고 임계 판정, 차단 필터 등
  masking.dart                   # 순수: 가림 영역 좌표/모자이크 블록 계산
  screens/
    sign_in_gate.dart            # 미로그인 시 로그인 유도 래퍼
    feed_screen.dart             # 최신순 무한 스크롤 피드
    post_detail_screen.dart      # 사진·캡션·좋아요·댓글·신고/차단
    create_post_screen.dart      # 사진 선택→가림→캡션→업로드 조립
    mask_editor_screen.dart      # 가림 편집(자동 얼굴+수동 박스, 모자이크/스티커)
```
- 카메라 화면에 **커뮤니티 진입 버튼** 추가.
- 순수 로직(`moderation.dart`, `masking.dart`, 모델)은 TDD. 화면/네트워크는 구현+수동 검증.

---

## 5. 단계 나누기 (스펙 1개 + 계획 여러 개)

규모가 커서 **하나의 계획으로 만들지 않는다.** 각 단계는 독립적으로 동작·테스트 가능한 산출물이다.

- **계획 A — 인증 + 추천 게이팅**
  `firebase_auth`, Google(`google_sign_in`)·Apple(`sign_in_with_apple`)·Kakao(`kakao_flutter_sdk_user` + `kakaoCustomToken` 함수) 로그인, `AuthService`, 로그인 게이트, `advise` 함수 auth 검증, 미로그인 시 ✨추천 차단.
  (규모가 크면 A1: 인증 기반+Google, A2: Apple, A3: Kakao 커스텀 토큰으로 세분 가능.)
- **계획 B — 게시·피드·좋아요**
  Firestore/Storage 세팅, 보안 규칙, `Post` 모델·리포지토리, 피드/상세/작성 화면, 좋아요, 집계 함수.
- **계획 C — 개인정보 가림**
  `masking.dart`(TDD) + `MaskEditorScreen`(자동 얼굴+수동 박스, 모자이크/스티커), 작성 흐름에 편집 단계 삽입.
- **계획 D — 댓글 + 신고/자동숨김/차단**
  댓글 CRUD, 신고 생성, `onReportCreate` 자동 숨김, 사용자 차단·피드 필터.

각 계획은 개별적으로 `tool/verify.sh`(및 functions 테스트) 통과를 완료 게이트로 한다.

---

## 6. 범위 밖 (YAGNI)
- 인기순 정렬·해시태그·검색·팔로우·DM·푸시 알림.
- 업로드 시 자동 이미지 안전성 검열(NSFW 자동 필터) — 후속.
- 번호판 자동 감지(수동 박스로 대체).
- 프로필 편집(닉네임은 Google 이름 사용).
- 이메일/전화 등 그 외 로그인 수단(소셜 3종 외).

---

## 7. 완료 정의 (MVP 전체)
- 커뮤니티는 **로그인해야 진입**하며, Google 로그인 후 피드를 보고 사진(개인정보 가림 처리)을 올려 좋아요·댓글을 주고받는다.
- 신고가 임계에 도달하면 게시물/댓글이 자동으로 숨겨지고, 사용자를 차단하면 그 사람 글이 피드에서 사라진다.
- ✨구도 추천은 로그인 사용자만 사용 가능하다.
- 순수 로직(masking·moderation·모델)은 TDD로 커버되고, 전체 게이트를 통과한다.
