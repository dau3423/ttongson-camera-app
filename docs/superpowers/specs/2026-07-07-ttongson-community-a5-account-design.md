# 똥손카메라 — 커뮤니티 계획 A5: 계정 관리 설계

> 상위 스펙 `2026-07-05-ttongson-community-design.md`(인증)·`2026-07-05-ttongson-user-profile-design.md`(프로필)의 후속.
> 로그인/로그아웃/회원가입(소셜)·프로필 자동 생성은 A1~A4에서 완료. A5는 **프로필 편집·회원 탈퇴(소프트)·계정 화면**을 추가한다. 커뮤니티 A·B·C·D 완료 상태.

## 1. 목표 / 범위

- 로그인 사용자가 **닉네임과 프로필 사진을 편집**한다.
- **회원 탈퇴**를 **소프트 삭제**로 처리한다(`/users/{uid}.deleteDate` 설정, 데이터·정보 유지).
- 탈퇴 계정으로 재로그인하면 **차단·안내**하되, **재가입**을 선택하면 복귀시킨다.
- 로그인/로그아웃/회원가입은 기존 동작 유지(A5는 그 위에 화면·편집·탈퇴만 추가).
- **범위 밖:** 하드 삭제(콘텐츠 캐스케이드 삭제), 이메일/비밀번호 가입, 피드·댓글 아바타 표시(추후).

## 2. 핵심 결정 (확정)

- **프로필 편집:** 닉네임 + 프로필 사진.
- **회원 탈퇴:** 소프트 삭제 — 클라이언트가 `/users/{uid}.deleteDate = serverTimestamp` 설정(함수 없음). 게시물·댓글 등 데이터 유지, 즉시 로그아웃.
- **탈퇴 계정 재로그인:** 로그인은 성공하지만(소셜 크리덴셜 유효), 프로필의 `deleteDate`가 있으면 **재가입 여부를 묻고** — 재가입=`deleteDate` 삭제 후 이용, 취소=로그아웃.
- **프로필 사진:** `profile_images/{uid}.jpg`. 업로드 전 **가림 파이프라인 재사용**(`mask_processor.applyMasks(file, [])`)으로 축소(최장변 1600)·EXIF 제거.
- **닉네임:** 트림 후 **1~20자**(UI 검증, 순수 함수). 유일성 강제 없음.

## 3. 데이터 모델 (Firestore)

```
users/{uid}
  uid, userId, nickname, loginType, createdAt, photoUrl   # 기존
  deleteDate: timestamp | (없음)   # 설정되면 탈퇴 상태(소프트)
```

- `UserProfile`(순수)에 `DateTime? deleteDate` 추가, `bool get isWithdrawn => deleteDate != null`.
- `fromData`가 `deleteDate` 복원. `toCreateMap`엔 미포함(생성 시 없음, 탈퇴 시에만 설정).
- 순수 함수 `bool isValidNickname(String)` — 트림 후 길이 1~20.

## 4. 저장소 (`UserRepository`)

기존 `ensureProfile`·`getProfile` 유지. 추가/보완:
- `getProfile` — `createdAt`뿐 아니라 `deleteDate`도 Timestamp→DateTime 변환.
- `Stream<UserProfile?> watchProfile(String uid)` — `/users/{uid}` 스냅샷 스트림(계정 화면이 편집 후 자동 반영되도록).
- `Future<void> updateProfile({required String uid, String? nickname, String? photoUrl})` — 전달된 필드만 `/users/{uid}` 업데이트.
- `Future<String> uploadProfilePhoto({required String uid, required File image})` — `mask_processor.applyMasks(image, const [])`로 처리 후 `profile_images/{uid}.jpg`에 업로드, 다운로드 URL 반환. (PostRepository처럼 `FirebaseStorage` 의존 추가.)
- `Future<void> withdraw(String uid)` — `deleteDate: serverTimestamp` 설정.
- `Future<void> rejoin(String uid)` — `deleteDate: FieldValue.delete()`.

## 5. 인증 흐름 (`AuthService` / `sign_in_sheet`)

- `AuthService` 헬퍼(내부 `_users` 위임): `Future<UserProfile?> myProfile()`(현재 uid 프로필), `Future<void> withdraw()`, `Future<void> rejoin()`.
- `sign_in_sheet._run`: 로그인 성공(user != null) 후 `myProfile()`의 `isWithdrawn`이면 **재가입 다이얼로그**:
  - **재가입** → `rejoin()` → 로그인 완료(pop true).
  - **취소** → `signOut()` → 미로그인(pop false).
  - `isWithdrawn`이 아니면 기존대로 pop true.

## 6. 보안 규칙

- `/users/{uid}` — 기존 `allow update: if request.auth != null && request.auth.uid == uid`가 닉네임·photoUrl·deleteDate 갱신을 이미 허용(변경 불필요).
- `storage.rules`에 프로필 사진 규칙 추가(기존 `post_images` 옆):
```
    match /profile_images/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == uid
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
```
> 규칙 배포는 사람: `firebase deploy --only storage`.

## 7. 계정 화면 (`lib/community/screens/account_screen.dart`, 신규)

- `AccountScreen({required AuthService auth, UserRepository? users})`.
- `watchProfile(uid)` 스트림으로 프로필을 구독(편집·사진 변경이 즉시 반영).
- 표시: 프로필 사진(`CircleAvatar`, photoUrl 없으면 기본 아이콘), 닉네임, 로그인 종류.
- **사진 변경**: 아바타 탭 → image_picker → `uploadProfilePhoto` → `updateProfile(photoUrl)` → 갱신.
- **닉네임 편집**: 탭 → TextField 다이얼로그(`isValidNickname` 검증) → `updateProfile(nickname)`.
- **로그아웃** 버튼 → `auth.signOut()` → 화면 pop.
- **회원 탈퇴** 버튼 → 확인 다이얼로그 → `auth.withdraw()` → `signOut()` → pop.
- 진입점: 피드 `AppBar`에 **계정 아이콘**(사람) → `AccountScreen`.

## 8. 에러 처리

- 업로드/업데이트/탈퇴/재가입 실패 → 토스트. 탈퇴·재가입은 확인 다이얼로그 후 실행.
- 미로그인 상태로 계정 화면 진입 방지(피드는 로그인 게이트 뒤).
- async-gap: await 뒤 context 사용 전 mounted/context.mounted 가드, messenger 선캡처.

## 9. 테스트

- **순수 TDD**: `user_profile_test`에 deleteDate 복원·isWithdrawn 케이스 추가, `isValidNickname` 테스트(경계 0/1/20/21자, 공백 트림).
- **저장소/화면/인증**: 구현 + 기기 수동 검증.
- 게이트: 앱 `tool/verify.sh`, 정적분석 `dart analyze lib test`(`flutter analyze` 금지).

## 10. 완료 정의 (A5)

로그인 사용자가 피드 AppBar의 계정 아이콘으로 계정 화면에 들어가 닉네임과 프로필 사진을 바꾸고, 로그아웃하거나 회원 탈퇴할 수 있다. 탈퇴하면 `deleteDate`가 설정되고 로그아웃되며, 그 계정으로 다시 로그인하면 재가입 여부를 물어 재가입 시 기존 데이터로 복귀한다. `tool/verify.sh` 통과.
