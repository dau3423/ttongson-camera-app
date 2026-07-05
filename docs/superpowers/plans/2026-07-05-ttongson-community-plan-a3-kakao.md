# 커뮤니티 계획 A3 — Kakao 로그인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카카오 로그인을 붙인다. Firebase 기본 제공자가 아니므로 카카오 토큰을 검증해 Firebase 커스텀 토큰을 발급하는 클라우드 함수를 거쳐 Firebase Auth 사용자로 수렴시킨다.

**Architecture:** 앱에서 `kakao_flutter_sdk_user`로 로그인 → 액세스 토큰을 `kakaoCustomToken` 함수로 전송 → 함수가 카카오 API로 검증 후 Admin SDK로 **커스텀 토큰** 발급 → 앱이 `signInWithCustomToken` → 기존 `ensureProfile(loginType: kakao)`로 프로필 생성. Google(A1)·Apple(A2)와 동일하게 uid로 수렴.

**Tech Stack:** Flutter(Dart), `kakao_flutter_sdk_user`, `cloud_functions`, `firebase_auth`; Firebase Functions v2 onCall(TypeScript, vitest), firebase-admin.

**범위:** 커뮤니티 A3. A1(Google)·A2(Apple)·A4(프로필) 병합됨. 게시(B)·가림(C)·댓글(D)은 별도.

## Global Constraints

- 소셜 로그인은 최종적으로 **Firebase Auth 사용자(uid)** 로 수렴. 카카오 uid 규약: `kakao:{kakaoId}`.
- 로그인 성공 시 기존 `AuthService`/`UserRepository.ensureProfile`로 프로필 자동 생성(loginType=`kakao`).
- 앱 정적 분석 `dart analyze lib test`(한글 디렉토리명 때문에 `flutter analyze` 크래시). Flutter SDK: `/Users/soonbok/flutter/bin`.
- 함수 변경은 `functions`에서 `npx vitest run` 통과가 게이트. Node 22(global `fetch` 사용).
- 순수 로직 TDD, 플러그인/네이티브/UI는 구현 + 기기 수동 검증.
- 앱 완료 게이트: `tool/verify.sh` 통과.
- 커밋: Conventional Commits. 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 0: 사람 선행 — Kakao Developers/네이티브 설정 (코드 아님)

- [ ] **Step 1: Kakao Developers 앱 생성 + 카카오 로그인 활성화**

[Kakao Developers](https://developers.kakao.com) → 애플리케이션 추가 → **네이티브 앱 키** 확보. 제품 설정 → **카카오 로그인 활성화 ON**, 동의항목(닉네임 등) 설정.

- [ ] **Step 2: 플랫폼 등록(키 해시/번들)**

- Android: 패키지명 `com.junicode.ttongson_camera` + **키 해시** 등록. 디버그 키 해시:
  `keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64`
- iOS: 번들 ID 등록.

- [ ] **Step 3: 네이티브 앱 키를 `lib/community/kakao_config.dart`에 기입(Task 1에서 파일 생성)** + Android `AndroidManifest.xml`·iOS `Info.plist`에 카카오 로그인 리다이렉트(URL 스킴 `kakao{NATIVE_APP_KEY}`) 설정. (kakao_flutter_sdk 문서 기준.)

> 산출물은 코드가 아니라 "Kakao 콘솔·네이티브 설정 완료 + 네이티브 앱 키". 코드 태스크는 이 설정과 독립적으로 작성 가능하며, 실제 로그인 검증만 설정 완료 후 가능. `kakaoCustomToken` 함수 배포도 사람: `firebase deploy --only functions:kakaoCustomToken`.

---

### Task 1: 의존성 + Kakao SDK 초기화

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/community/kakao_config.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 패키지 추가**

`pubspec.yaml`의 `dependencies:`에서 `cloud_firestore` 줄 아래에 추가:
```yaml
  kakao_flutter_sdk_user: ^1.9.6
```
Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter pub get`
Expected: `Got dependencies!` (충돌 시 solver 제안대로 조정, 1.9.x 유지).

- [ ] **Step 2: 네이티브 앱 키 설정 파일 생성**

`lib/community/kakao_config.dart` 생성:
```dart
// lib/community/kakao_config.dart
// Kakao Developers의 네이티브 앱 키. Task 0에서 실제 값으로 교체한다.
const String kakaoNativeAppKey = 'YOUR_KAKAO_NATIVE_APP_KEY';
```

- [ ] **Step 3: main.dart에서 SDK 초기화**

`lib/main.dart` import에 추가:
```dart
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'community/kakao_config.dart';
```
`WidgetsFlutterBinding.ensureInitialized();` 바로 다음 줄에 추가:
```dart
  KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
```

- [ ] **Step 4: 분석 + 커밋**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test`
Expected: No issues found!
```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add pubspec.yaml pubspec.lock lib/community/kakao_config.dart lib/main.dart
git commit -m "chore: kakao_flutter_sdk_user 의존성 + KakaoSdk 초기화"
```

---

### Task 2: `kakaoCustomToken` 클라우드 함수

카카오 액세스 토큰을 검증하고 Firebase 커스텀 토큰을 발급한다.

**Files:**
- Create: `functions/src/kakao.ts`
- Modify: `functions/src/index.ts`
- Test: `functions/test/kakao.test.ts`

**Interfaces:**
- Produces: `kakaoUid(id: unknown) -> string` (순수), onCall `kakaoCustomToken`.

- [ ] **Step 1: 실패 테스트 작성**

`functions/test/kakao.test.ts` 생성:
```ts
import { describe, it, expect } from "vitest";
import { kakaoUid } from "../src/kakao.js";

describe("kakaoUid", () => {
  it("숫자 id를 kakao: 접두 uid로", () => {
    expect(kakaoUid(12345)).toBe("kakao:12345");
  });
  it("문자열 id도 허용", () => {
    expect(kakaoUid("abc")).toBe("kakao:abc");
  });
  it("id가 없거나 객체면 예외", () => {
    expect(() => kakaoUid(undefined)).toThrow();
    expect(() => kakaoUid({})).toThrow();
    expect(() => kakaoUid(null)).toThrow();
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run kakao`
Expected: FAIL — `kakao.js` 없음.

- [ ] **Step 3: 구현**

`functions/src/kakao.ts` 생성:
```ts
// functions/src/kakao.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

if (getApps().length === 0) initializeApp();

/** 카카오 사용자 id → Firebase uid. */
export function kakaoUid(id: unknown): string {
  if (typeof id !== "number" && typeof id !== "string") {
    throw new HttpsError("unauthenticated", "카카오 사용자 정보를 확인할 수 없습니다");
  }
  return `kakao:${id}`;
}

export const kakaoCustomToken = onCall({ enforceAppCheck: true }, async (request) => {
  const accessToken = (request.data as { accessToken?: string })?.accessToken;
  if (typeof accessToken !== "string" || accessToken.length === 0) {
    throw new HttpsError("invalid-argument", "accessToken이 필요합니다");
  }
  const res = await fetch("https://kapi.kakao.com/v2/user/me", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    throw new HttpsError("unauthenticated", "카카오 토큰 검증에 실패했습니다");
  }
  const data = (await res.json()) as { id?: number };
  const uid = kakaoUid(data.id);
  const token = await getAuth().createCustomToken(uid, { provider: "kakao" });
  return { token };
});
```

- [ ] **Step 4: index.ts에 export 추가**

`functions/src/index.ts`를 아래로 교체(또는 줄 추가):
```ts
export { advise } from "./advise.js";
export { kakaoCustomToken } from "./kakao.js";
```

- [ ] **Step 5: 통과 확인 + 빌드**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run && npm run build`
Expected: 모든 테스트 PASS, tsc 빌드 성공.

- [ ] **Step 6: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add functions/src/kakao.ts functions/src/index.ts functions/test/kakao.test.ts functions/lib
git commit -m "feat(functions): kakaoCustomToken — 카카오 토큰 검증 후 커스텀 토큰 발급"
```

> 배포는 사람: `firebase deploy --only functions:kakaoCustomToken`.

---

### Task 3: `AuthService.signInWithKakao()`

**Files:**
- Modify: `lib/community/auth_service.dart`

**Interfaces:**
- Consumes: `UserRepository.ensureProfile`, `LoginType.kakao`, `cloud_functions`, `kakao_flutter_sdk_user`.
- Produces: `Future<User?> signInWithKakao()` — 취소 시 null.

- [ ] **Step 1: import 추가**

`lib/community/auth_service.dart` 상단 import에 추가:
```dart
import 'package:flutter/services.dart' show PlatformException;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
```

- [ ] **Step 2: 메서드 추가**

`signInWithApple()` 아래에 추가:
```dart
  /// 카카오 로그인. 사용자가 취소하면 null.
  Future<User?> signInWithKakao() async {
    final OAuthToken kakaoToken;
    try {
      kakaoToken = await isKakaoTalkInstalled()
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return null; // 사용자 취소
      rethrow;
    }
    final callable = FirebaseFunctions.instance.httpsCallable('kakaoCustomToken');
    final result = await callable.call<Map<String, dynamic>>({
      'accessToken': kakaoToken.accessToken,
    });
    final customToken = result.data['token'] as String;
    final cred = await _auth.signInWithCustomToken(customToken);
    final user = cred.user;
    if (user != null) {
      await _users.ensureProfile(user: user, loginType: LoginType.kakao);
    }
    return user;
  }
```

- [ ] **Step 3: 정적 분석**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/auth_service.dart`
Expected: No issues found!
(설치된 `kakao_flutter_sdk_user` 1.9.x에서 `isKakaoTalkInstalled`/`UserApi`/`OAuthToken`/`loginWithKakaoTalk`/`loginWithKakaoAccount` 식별자가 다르면 같은 동작을 유지하도록 최소 수정하고 보고서에 기록.)

- [ ] **Step 4: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/auth_service.dart
git commit -m "feat: AuthService에 카카오 로그인(커스텀 토큰) 추가"
```

---

### Task 4: 로그인 시트에 카카오 버튼

**Files:**
- Modify: `lib/community/screens/sign_in_sheet.dart`

**Interfaces:**
- Consumes: `AuthService.signInWithKakao()`(Task 3), 기존 `_ProviderButton`(iconColor 지원).

- [ ] **Step 1: 카카오 버튼 추가**

`sign_in_sheet.dart`에서 Google `_ProviderButton` **바로 아래**(Apple `if (Platform.isIOS)` 블록 위)에 추가한다. 카카오는 iOS·Android 모두 지원하므로 항상 노출:
```dart
              const SizedBox(height: 12),
              _ProviderButton(
                label: '카카오로 계속하기',
                icon: Icons.chat_bubble,
                iconColor: const Color(0xFF3C1E1E),
                background: const Color(0xFFFEE500),
                foreground: const Color(0xFF3C1E1E),
                bordered: false,
                onTap: _busy ? null : () => _run(widget.auth.signInWithKakao),
              ),
```

- [ ] **Step 2: 정적 분석**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test`
Expected: No issues found!

- [ ] **Step 3: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/screens/sign_in_sheet.dart
git commit -m "feat: 로그인 시트에 카카오 버튼"
```

---

### Task 5: 최종 검증

- [ ] **Step 1: 앱 게이트**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh`
Expected: `✅ verify 통과`.

- [ ] **Step 2: 함수 게이트**

Run: `cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run`
Expected: 전부 PASS.

- [ ] **Step 3: 기기 수동 검증 (사람)**

Task 0(콘솔·네이티브·앱키) + `firebase deploy --only functions:kakaoCustomToken` 후 `flutter run`:
- 미로그인 상태로 ✨추천 → 로그인 시트에 **카카오(노란) 버튼** 표시.
- "카카오로 계속하기" → 카카오 로그인 → 성공 시 추천 진행 + `/users/{uid}`에 `loginType: 'kakao'`로 프로필 생성.
- 취소하면 아무 일도 일어나지 않음.

---

## Self-Review (작성자 확인)

- **스펙 커버리지(A3):** 카카오 로그인=Task 3, 커스텀 토큰 함수=Task 2, 버튼=Task 4, 의존성·초기화=Task 1, 네이티브 선행=Task 0. uid `kakao:{id}`·loginType kakao 반영. Google/Apple/프로필은 기병합.
- **플레이스홀더:** 코드·테스트 실제 내용 포함. `kakao_config.dart`의 앱 키는 사람이 채우는 설정 seam(구조상 유효 const)이며 Task 0에서 교체.
- **타입 일관성:** `signInWithKakao()->Future<User?>`(Task 3)가 Task 4에서 소비됨. `kakaoUid(unknown)->string`, `kakaoCustomToken` onCall. 기존 `_ProviderButton(iconColor)` 활용.
- **주의:** kakao_flutter_sdk_user 1.9.x API·네이티브 리다이렉트 설정 필요. Node 22 global fetch 사용. `enforceAppCheck: true`는 advise와 동일 정책.
