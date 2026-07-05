# 커뮤니티 계획 A2 — Apple 로그인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 `AuthService`에 Apple 로그인을 추가하고, 로그인 시트에 "Apple로 계속하기" 버튼을 붙인다.

**Architecture:** `sign_in_with_apple`로 Apple ID 자격을 받아 Firebase `OAuthProvider('apple.com')` 자격으로 변환해 `signInWithCredential`으로 로그인한다. Google과 동일하게 최종적으로 Firebase Auth 사용자(uid)로 수렴한다. 나머지 시스템(추천 게이팅·규칙)은 이미 uid 기반이라 변경 없음.

**Tech Stack:** Flutter(Dart), `firebase_auth`(6.x), `sign_in_with_apple`.

**범위:** 커뮤니티 스펙 계획 A 중 **A2**. A1(Google)은 이미 병합됨. Kakao(A3)·게시(B)·가림(C)·댓글/신고(D)는 별도 계획.

## Global Constraints

- 소셜 로그인은 최종적으로 **Firebase Auth 사용자(uid)** 로 수렴한다.
- 정적 분석은 `dart analyze lib test`(한글 디렉토리명 때문에 `flutter analyze` 크래시). Flutter SDK: `/Users/soonbok/flutter/bin`.
- 플러그인/네이티브/UI는 구현 + 기기 수동 검증(단위 테스트 무의미).
- 앱 완료 게이트: `tool/verify.sh` 통과.
- 커밋: Conventional Commits. 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- 로그인 시트 문구·버튼 스타일은 기존 Google 버튼과 동일 패턴을 따른다.

---

### Task 0: 사람이 먼저 해야 하는 네이티브/콘솔 설정 (선행, 코드 아님)

Apple 로그인은 네이티브 설정 없이는 기기 검증이 실패한다. **사람(프로젝트 소유자)** 이 수행한다.

- [ ] **Step 1: Apple Developer — App ID에 "Sign In with Apple" 사용 설정**

Apple Developer → Certificates, IDs & Profiles → Identifiers → 앱의 App ID → **Sign In with Apple** 체크 후 저장.

- [ ] **Step 2: Xcode — Runner에 Capability 추가**

`ios/Runner.xcworkspace`를 Xcode로 열고 Runner 타깃 → Signing & Capabilities → **+ Capability → Sign in with Apple** 추가.

- [ ] **Step 3: Firebase Console — Apple 제공자 사용 설정**

Firebase Console → Authentication → Sign-in method → **Apple 사용 설정**. (iOS 네이티브는 사용 설정만으로 충분. **Android/웹에서 Apple 로그인**을 지원하려면 Services ID + 리턴 URL 구성이 추가로 필요 — 이건 이 계획 범위 밖, 필요 시 후속.)

> 산출물은 코드 diff가 아니라 "Apple Developer/Xcode/Firebase 설정 완료". A2 코드 태스크는 이 설정과 독립적으로 작성 가능하며, 실제 로그인 검증만 설정 완료 후 가능하다.
> **주의:** 현재 테스트 기기가 Android면 Apple 로그인은 Services ID 웹 플로우 구성 전까지 동작하지 않는다(iOS에서 우선 검증).

---

### Task 1: 의존성 추가

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `package:sign_in_with_apple` 사용 가능.

- [ ] **Step 1: 패키지 추가**

`pubspec.yaml`의 `dependencies:`에서 `google_sign_in` 줄 아래에 추가:
```yaml
  sign_in_with_apple: ^6.1.0
```

- [ ] **Step 2: 설치**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter pub get`
Expected: `Got dependencies!` (충돌 시 solver 제안대로 상한 조정하되 6.x 유지).

- [ ] **Step 3: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add pubspec.yaml pubspec.lock
git commit -m "chore: sign_in_with_apple 의존성 추가"
```

---

### Task 2: `AuthService.signInWithApple()`

**Files:**
- Modify: `lib/community/auth_service.dart`

**Interfaces:**
- Consumes: 기존 `AuthService`의 `_auth`(FirebaseAuth).
- Produces: `Future<User?> signInWithApple()` — 사용자가 취소하면 null, 성공 시 `User`.

- [ ] **Step 1: import 추가**

`lib/community/auth_service.dart` 상단 import에 추가(기존 import들 아래):
```dart
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
```

- [ ] **Step 2: 메서드 추가**

`signInWithGoogle()` 메서드 바로 아래에 추가:
```dart
  /// Apple 로그인. 사용자가 취소하면 null.
  Future<User?> signInWithApple() async {
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauth = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      final result = await _auth.signInWithCredential(oauth);
      return result.user;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null; // 취소
      rethrow;
    }
  }
```

- [ ] **Step 3: 정적 분석**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/auth_service.dart`
Expected: No issues found!
(만약 `OAuthProvider`/`AppleIDAuthorizationScopes`/`AuthorizationErrorCode` 식별자가 설치된 버전과 다르면, 같은 동작을 유지하도록 설치된 API에 맞춰 최소 수정하고 보고서에 기록.)

- [ ] **Step 4: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/auth_service.dart
git commit -m "feat: AuthService에 Apple 로그인 추가"
```

---

### Task 3: 로그인 시트에 Apple 버튼

**Files:**
- Modify: `lib/community/screens/sign_in_sheet.dart`

**Interfaces:**
- Consumes: `AuthService.signInWithApple()`(Task 2).

- [ ] **Step 1: Apple 버튼 추가**

`sign_in_sheet.dart`에서 Google 버튼(`ElevatedButton.icon(... 'Google로 계속하기' ...)`) **바로 아래**에 추가:
```dart
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.apple),
              label: const Text('Apple로 계속하기'),
              onPressed: () async {
                final user = await auth.signInWithApple();
                if (ctx.mounted) Navigator.pop(ctx, user != null);
              },
            ),
```

- [ ] **Step 2: 정적 분석**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test`
Expected: No issues found!

- [ ] **Step 3: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/screens/sign_in_sheet.dart
git commit -m "feat: 로그인 시트에 Apple 버튼"
```

---

### Task 4: 최종 검증

- [ ] **Step 1: 앱 게이트**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh`
Expected: `✅ verify 통과`.

- [ ] **Step 2: 기기 수동 검증 (사람, iOS)**

Task 0 완료 후 iOS 기기/시뮬레이터에서 `flutter run`:
- 미로그인 상태로 ✨추천 → 로그인 시트에 **Google/Apple 버튼 둘 다** 표시.
- "Apple로 계속하기" → Apple 로그인 시트 → 성공 시 추천 진행.
- 취소하면 아무 일도 일어나지 않음(추천 미진행).

---

## Self-Review (작성자 확인)

- **스펙 커버리지(A2):** Apple 로그인=Task 2, 로그인 시트 버튼=Task 3, 의존성=Task 1, 네이티브 선행=Task 0. Google(A1) 기병합, Kakao(A3)·게시(B) 등은 범위 밖으로 명시.
- **플레이스홀더:** 코드 스텝에 실제 코드 포함. Task 2 Step 3에 버전-API 불일치 시 최소 적응 지침(구체 대상 식별자 명시).
- **타입 일관성:** `AuthService.signInWithApple()->Future<User?>`가 Task 2에서 정의되고 Task 3에서 소비됨. 기존 `showSignInSheet(BuildContext, AuthService)` 계약 불변.
- **주의:** sign_in_with_apple 6.x 기준. `OAuthProvider`는 firebase_auth 제공. Android에서 Apple 로그인은 Services ID 웹 플로우 구성 전엔 미동작(iOS 우선).
