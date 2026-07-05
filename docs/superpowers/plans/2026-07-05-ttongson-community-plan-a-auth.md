# 커뮤니티 계획 A1 — 인증 기반 + Google 로그인 + ✨추천 게이팅 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Firebase Auth 기반을 세우고 Google 로그인을 붙인 뒤, ✨구도 추천을 로그인 사용자만 쓰도록 게이팅한다.

**Architecture:** `AuthService`가 Firebase Auth를 감싸 로그인 상태/로그인/로그아웃을 제공한다. `advise` 클라우드 함수는 `request.auth`를 검증해 미로그인 호출을 거부한다. 카메라 화면의 ✨추천 진입점은 미로그인 시 로그인 화면으로 유도한다. 온디바이스 카메라 가이드는 로그인과 무관하게 동작(변경 없음).

**Tech Stack:** Flutter(Dart), `firebase_auth`, `google_sign_in`(v6 classic API), 기존 `firebase_core`/`cloud_functions`; 백엔드는 Firebase Functions v2 onCall(TypeScript, vitest).

**범위:** 이 계획은 커뮤니티 스펙의 **계획 A 중 A1**이다. Apple(A2)·Kakao(A3)·게시/피드(B)·가림(C)·댓글·신고(D)는 각자 별도 계획이다. A1 완료 시 "Google 로그인 → ✨추천 사용 가능, 미로그인 시 차단"이 동작한다.

## Global Constraints

- 로그인 없이 쓰는 건 카메라 가이드뿐. **✨구도 추천은 로그인 필수**(A1 범위). 커뮤니티 전체 회원 전용은 계획 B 이후.
- 소셜 로그인은 최종적으로 **Firebase Auth 사용자(uid)** 로 수렴한다.
- 정적 분석은 `dart analyze lib test`를 쓴다(한글 디렉토리명 때문에 `flutter analyze` 크래시). Flutter SDK: `/Users/soonbok/flutter/bin`.
- 순수 로직은 TDD. 플러그인/네이티브/UI는 구현 + 기기 수동 검증.
- 함수 변경은 `functions`에서 `npx vitest run` 통과가 게이트.
- 앱 완료 게이트: `tool/verify.sh` 통과.
- 커밋 메시지: Conventional Commits. 커밋 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 0: 사람이 먼저 해야 하는 콘솔 설정 (선행, 코드 아님)

이 태스크는 코드가 아니라 **사람(프로젝트 소유자)** 이 Firebase/Google 콘솔에서 하는 선행 작업이다. 이게 안 되면 이후 로그인 태스크의 기기 검증이 실패한다.

- [ ] **Step 1: Firebase 콘솔에서 Google 로그인 제공자 사용 설정**

Firebase Console → Authentication → Sign-in method → **Google 사용 설정**.

- [ ] **Step 2: Android SHA-1/SHA-256 지문 등록**

`cd android && ./gradlew signingReport` 로 debug SHA-1·SHA-256을 확인해 Firebase 프로젝트 설정 → 내 앱(Android)에 등록한 뒤, **google-services.json 재다운로드**하여 `android/app/google-services.json` 교체.

- [ ] **Step 3: 확인**

`android/app/google-services.json`에 `oauth_client` 항목(client_type 3, web client id 포함)이 있는지 확인. 없으면 Google 로그인이 토큰을 못 받는다.

> 이 태스크의 산출물은 코드 diff가 아니라 "콘솔 설정 완료 + 갱신된 google-services.json"이다. 리뷰는 google-services.json에 oauth_client가 존재하는지로 확인한다.

---

### Task 1: 의존성 추가

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `package:firebase_auth`, `package:google_sign_in`(v6) 사용 가능.

- [ ] **Step 1: 패키지 추가**

`pubspec.yaml`의 `dependencies:`에 아래를 추가(기존 firebase_core/cloud_functions 아래):
```yaml
  firebase_auth: ^5.3.1
  google_sign_in: ^6.2.1
```

- [ ] **Step 2: 설치**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter pub get`
Expected: `Got dependencies!` (버전 충돌 시 `flutter pub get` 출력의 제안대로 상한을 조정하되 google_sign_in은 6.x 유지).

- [ ] **Step 3: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add pubspec.yaml pubspec.lock
git commit -m "chore: firebase_auth·google_sign_in 의존성 추가"
```

---

### Task 2: `advise` 함수 로그인 검증

미로그인 호출을 거부한다. onCall v2는 인증된 클라이언트면 `request.auth`가 채워진다.

**Files:**
- Modify: `functions/src/advise.ts`
- Test: `functions/test/advise.test.ts`

**Interfaces:**
- Consumes: firebase-functions v2 `onCall`의 `request.auth`.
- Produces: 미인증 시 `HttpsError("unauthenticated", ...)`.

- [ ] **Step 1: 실패 테스트 추가**

먼저 현재 테스트 구조를 확인한다: `cat functions/test/advise.test.ts` 로 `advise` 핸들러를 어떻게 호출/모킹하는지 본다. 핸들러를 직접 호출하는 테스트가 있으면 그 패턴을 따르고, 없으면 아래 순수-경계 방식으로 검증한다.

`functions/src/advise.ts`에서 인증 검증을 **작은 순수 함수로 분리**해 테스트한다. `functions/src/auth_guard.ts` 생성 대상 함수의 계약:
```ts
// 인증 컨텍스트(있으면 uid 보유)를 받아, 없으면 예외.
export function requireAuthUid(auth: { uid?: string } | undefined): string
```

`functions/test/auth_guard.test.ts` 생성:
```ts
import { describe, it, expect } from "vitest";
import { requireAuthUid } from "../src/auth_guard.js";

describe("requireAuthUid", () => {
  it("uid가 있으면 그대로 반환", () => {
    expect(requireAuthUid({ uid: "abc" })).toBe("abc");
  });
  it("auth가 없으면 예외", () => {
    expect(() => requireAuthUid(undefined)).toThrow();
  });
  it("uid가 빈 값이면 예외", () => {
    expect(() => requireAuthUid({ uid: "" })).toThrow();
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run auth_guard`
Expected: FAIL — `auth_guard.js` 없음.

- [ ] **Step 3: 구현**

`functions/src/auth_guard.ts` 생성:
```ts
import { HttpsError } from "firebase-functions/v2/https";

/** 인증 컨텍스트에서 uid를 꺼낸다. 없으면 unauthenticated 예외. */
export function requireAuthUid(auth: { uid?: string } | undefined): string {
  const uid = auth?.uid;
  if (typeof uid !== "string" || uid.length === 0) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다");
  }
  return uid;
}
```

- [ ] **Step 4: advise 핸들러에 적용**

`functions/src/advise.ts`에서 import 추가하고 핸들러 본문 맨 앞(데이터 검증 전)에 인증 검증을 넣는다.

import 추가(상단 import들 옆):
```ts
import { requireAuthUid } from "./auth_guard.js";
```
핸들러 시작 부분, `const data = request.data ...` 바로 위에 추가:
```ts
    requireAuthUid(request.auth);
```

- [ ] **Step 5: 통과 확인 + 빌드**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run && npm run build`
Expected: 모든 테스트 PASS, tsc 빌드 성공.

- [ ] **Step 6: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add functions/src/auth_guard.ts functions/src/advise.ts functions/test/auth_guard.test.ts functions/lib
git commit -m "feat(functions): advise 로그인 검증(requireAuthUid)"
```

> 배포는 별도(사람): `firebase deploy --only functions:advise`. 배포 전까지 라이브 함수는 미인증도 통과한다.

---

### Task 3: `AuthService` (Google 로그인)

Firebase Auth를 감싸 로그인 상태·Google 로그인·로그아웃을 제공한다. 플러그인 의존이라 단위 테스트 대신 기기 수동 검증.

**Files:**
- Create: `lib/community/auth_service.dart`

**Interfaces:**
- Produces:
  - `class AuthService`
  - `Stream<User?> authState()`
  - `User? get currentUser`
  - `bool get isSignedIn`
  - `Future<User?> signInWithGoogle()` — 취소 시 null
  - `Future<void> signOut()`

- [ ] **Step 1: 구현**

`lib/community/auth_service.dart` 생성:
```dart
// lib/community/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Auth 래퍼. 소셜 로그인은 모두 Firebase 사용자(uid)로 수렴한다.
/// (A1: Google. Apple/Kakao는 후속 계획에서 메서드 추가.)
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  AuthService({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn();

  Stream<User?> authState() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Google 로그인. 사용자가 취소하면 null.
  Future<User?> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return null; // 취소
    final gAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
```

- [ ] **Step 2: 정적 분석**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/auth_service.dart`
Expected: No issues found!

- [ ] **Step 3: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/auth_service.dart
git commit -m "feat: AuthService — Google 로그인 래퍼"
```

---

### Task 4: 로그인 화면 + ✨추천 로그인 게이팅

미로그인 상태로 ✨추천을 누르면 로그인 화면(sign-in sheet)을 띄우고, 로그인 성공 시에만 추천을 진행한다.

**Files:**
- Create: `lib/community/screens/sign_in_sheet.dart`
- Modify: `lib/screens/camera_screen.dart` (`_requestAdvice` 진입부)

**Interfaces:**
- Consumes: `AuthService`(Task 3).
- Produces: `Future<bool> showSignInSheet(BuildContext, AuthService)` — 로그인 성공 시 true.

- [ ] **Step 1: 로그인 시트 구현**

`lib/community/screens/sign_in_sheet.dart` 생성:
```dart
import 'package:flutter/material.dart';
import '../auth_service.dart';

/// 로그인 유도 바텀시트. 로그인 성공 시 true 반환.
Future<bool> showSignInSheet(BuildContext context, AuthService auth) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '로그인이 필요해요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('구도 추천과 커뮤니티는 로그인 후 이용할 수 있어요.'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Google로 계속하기'),
              onPressed: () async {
                final user = await auth.signInWithGoogle();
                if (ctx.mounted) Navigator.pop(ctx, user != null);
              },
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
```

- [ ] **Step 2: 카메라 화면에 AuthService 필드 추가**

`lib/screens/camera_screen.dart` import에 추가:
```dart
import '../community/auth_service.dart';
import '../community/screens/sign_in_sheet.dart';
```
`_CameraScreenState` 필드부(예: `final CloudAdvisor _advisor = CloudAdvisor();` 근처)에 추가:
```dart
  final AuthService _auth = AuthService();
```

- [ ] **Step 3: `_requestAdvice` 진입부에 게이팅**

`_requestAdvice()` 본문 맨 앞(`if (_adviceLoading) return;` 다음)에 추가:
```dart
    if (!_auth.isSignedIn) {
      final signedIn = await showSignInSheet(context, _auth);
      if (!signedIn) return;
    }
```

- [ ] **Step 4: 정적 분석**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test`
Expected: No issues found!

- [ ] **Step 5: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/screens/sign_in_sheet.dart lib/screens/camera_screen.dart
git commit -m "feat: ✨추천 로그인 게이팅 + Google 로그인 시트"
```

---

### Task 5: 최종 검증

- [ ] **Step 1: 앱 게이트**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh`
Expected: `✅ verify 통과`.

- [ ] **Step 2: 함수 게이트**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run`
Expected: 전부 PASS.

- [ ] **Step 3: 기기 수동 검증 체크리스트 (사람)**

Task 0 콘솔 설정 완료 + `firebase deploy --only functions:advise` 후 `flutter run`:
- 미로그인 상태로 ✨추천 → 로그인 시트가 뜬다.
- Google 로그인 성공 → 추천이 진행된다(카드 표시).
- 앱 재실행 시 로그인 유지(추천 바로 가능).
- 미로그인으로 배포된 함수 직접 호출 시 `unauthenticated` 거부(로그인 후 정상).

---

## Self-Review (작성자 확인)

- **스펙 커버리지(계획 A1 부분):** 로그인 필수(✨추천)=Task 4, advise auth 검증=Task 2, AuthService(Google)=Task 3, 의존성=Task 1, 콘솔 선행=Task 0. Apple/Kakao/커뮤니티 전체 게이팅은 A2/A3/B로 명시적 분리(범위 밖).
- **플레이스홀더:** 코드 스텝에 실제 코드 포함. Task 2 Step 1은 기존 테스트 구조 확인을 지시하되 검증은 분리한 순수 함수(`requireAuthUid`)로 구체화.
- **타입 일관성:** `AuthService.{authState,currentUser,isSignedIn,signInWithGoogle,signOut}`, `showSignInSheet(BuildContext, AuthService)->Future<bool>`, `requireAuthUid(auth)->string` — 태스크 간 일치.
- **주의:** google_sign_in 6.x 클래식 API 기준 코드. `flutter pub get`이 7.x를 끌어오면(제약에 따라) `signIn()`/`authentication` API가 달라지니 6.x로 고정할 것.
