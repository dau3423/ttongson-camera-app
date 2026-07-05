# 똥손카메라 — 최초 로그인 사용자 프로필 자동 생성 기획서 (커뮤니티 A4)

- **작성일**: 2026-07-05
- **문서 유형**: 개발 기획서 (구현용)
- **상태**: 설계 확정, 구현 계획 수립 전
- **선행**: 커뮤니티 A1(Google)·A2(Apple) 로그인 병합됨. 이 문서는 로그인 성공 시 Firestore 사용자 프로필을 자동 생성한다.
- **관계**: 커뮤니티 기획서(`2026-07-05-ttongson-community-design.md`)의 `users/{uid}` 필드를 **이 문서가 확정**한다(닉네임·loginType·userId=이메일 추가). Firestore 도입도 여기서 시작하며 계획 B와 공유한다.

---

## 1. 개요

### 1.1 한 줄 정의
✨추천·커뮤니티를 위해 로그인하면, **가입 안 된 사용자는 랜덤 닉네임으로 프로필이 자동 생성**되어 Firestore `/users`에 저장된다.

### 1.2 동작
- 로그인(Google/Apple/Kakao) **성공 직후**, 앱이 `/users/{uid}` 존재를 확인한다.
- 없으면 트랜잭션으로 **생성**(랜덤 닉네임 + 필드). 있으면 그대로 둔다(닉네임·가입일 보존).
- ✨추천이든 커뮤니티든 로그인 경로면 항상 실행된다.

### 1.3 확정 결정
- 프로필 생성 위치: **앱(클라이언트)**. 서버 Auth 트리거 미사용.
- 닉네임: **한국어 형용사 + 동물 + 숫자**(예: `귀여운너구리4821`).
- 로그인 UI: 기존 **바텀시트 유지**(전용 전체화면 아님).

---

## 2. 데이터 모델

### 2.1 `/users/{uid}` (문서 ID = Firebase uid)
| 필드 | 타입 | 설명 |
|---|---|---|
| `uid` | string | Firebase Auth uid (문서 ID와 동일) |
| `userId` | string \| null | 가입 이메일. **없을 수 있음** — Apple 가림 이메일/미제공, Kakao 이메일 미동의 시 null |
| `nickname` | string | 랜덤(형용사+동물+숫자) |
| `loginType` | string | `'google'` \| `'apple'` \| `'kakao'` |
| `createdAt` | timestamp | 서버 타임스탬프(가입일). 생성 시 1회 고정 |
| `photoUrl` | string \| null | 제공자 프로필 사진(있으면) |

### 2.2 보안 규칙 (Firestore)
- `/users/{uid}` **읽기**: 로그인 사용자(`request.auth != null`).
- **생성/수정**: 본인만(`request.auth.uid == uid`).
- `uid`는 문서 ID와 일치해야 하고, `createdAt`은 생성 시 서버 타임스탬프로만.

---

## 3. 구조 (신규/수정)

계산(순수) ↔ 네트워크/플러그인 분리 유지.

```
lib/community/
  models/user_profile.dart      # 순수 값 객체 (uid, userId?, nickname, loginType, createdAt?, photoUrl?)
  nickname_generator.dart       # 순수: 형용사+동물+숫자. 주입형 Random으로 결정적 테스트(TDD)
  user_repository.dart          # Firestore /users 접근: ensureProfile(user, loginType) -> UserProfile
  auth_service.dart (수정)       # 각 signIn 성공 후 ensureProfile 호출(loginType 전달)
```

### 3.1 인터페이스
- `enum LoginType { google, apple, kakao }` (문자열 wire: 그대로 소문자).
- `String generateNickname({Random? random})` — 형용사+동물+숫자(예: 0~9999). 목록은 상수.
- `UserRepository.ensureProfile({required User user, required LoginType loginType}) -> Future<UserProfile>`
  - 트랜잭션: `get /users/{uid}` → 없으면 create(uid, userId=user.email, nickname=generateNickname(), loginType, createdAt=serverTimestamp, photoUrl=user.photoURL) → 반환. 있으면 기존값 반환.
- `AuthService`는 생성 시 `UserRepository`를 주입받아, `signInWithGoogle/Apple`(및 향후 Kakao) 성공 후 해당 `LoginType`으로 `ensureProfile`을 호출한다.

### 3.2 테스트 대상
- `nickname_generator.dart`: 형식(형용사+동물+숫자), 목록 범위, Random 주입 시 결정성 — **TDD**.
- `user_profile.dart`: 직렬화(toMap/fromMap), null 허용 필드 — **TDD**.
- `user_repository.dart`·`auth_service.dart`: Firestore/플러그인 의존 → 기기 수동 검증(억지 단위테스트 금지).

---

## 4. 의존성
- 신규: `cloud_firestore`. (이미 있음: firebase_core, firebase_auth, cloud_functions 등.)

---

## 5. 범위 밖 (YAGNI)
- 닉네임 전역 유니크 보장(숫자 접미사로 충돌 확률 낮음, 허용).
- 프로필 편집·닉네임 변경·사진 변경(계획 B 이후).
- 서버측 Auth onCreate 트리거.
- 로그인 전용 전체화면(바텀시트 유지).

---

## 6. 완료 정의
- 처음 로그인한 사용자는 `/users/{uid}`에 랜덤 닉네임·loginType·(가능하면)이메일·가입일로 문서가 생성된다.
- 재로그인 시 기존 프로필이 보존된다(중복 생성·닉네임 변경 없음).
- 이메일이 없는 로그인(Apple 가림/Kakao 미동의)에서도 `userId=null`로 정상 생성된다.
- 닉네임 생성기·프로필 모델은 TDD로 커버되고, `tool/verify.sh` 통과.
