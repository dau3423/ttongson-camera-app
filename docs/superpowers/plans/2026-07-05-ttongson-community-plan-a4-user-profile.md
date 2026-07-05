# 커뮤니티 계획 A4 — 최초 로그인 사용자 프로필 자동 생성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 성공 시 `/users/{uid}`가 없으면 랜덤 닉네임으로 프로필을 자동 생성한다(있으면 보존).

**Architecture:** 순수 로직(닉네임 생성기·프로필 모델)은 TDD로 만들고, `UserRepository.ensureProfile`가 Firestore 트랜잭션으로 "없으면 생성"을 수행한다. `AuthService`는 각 소셜 로그인 성공 후 해당 `loginType`으로 `ensureProfile`을 호출한다. Firestore 보안 규칙으로 본인 문서만 쓰기 허용.

**Tech Stack:** Flutter(Dart), `cloud_firestore`, `firebase_auth`(6.x); Firestore 보안 규칙.

**범위:** 커뮤니티 A4. A1(Google)·A2(Apple) 로그인 병합됨. Kakao(A3)·게시(B) 등은 별도.

## Global Constraints

- `/users/{uid}` 필드: `uid`(=문서ID), `userId`=이메일(**null 허용**), `nickname`(형용사+동물+숫자 랜덤), `loginType`(`google`/`apple`/`kakao`), `createdAt`(서버 타임스탬프), `photoUrl`(null 허용).
- 프로필 생성은 **클라이언트 트랜잭션**. 없으면 생성, 있으면 보존(닉네임·가입일 불변).
- 순수 로직(`nickname_generator.dart`, `models/user_profile.dart`)은 **Flutter/plugin import 금지**, TDD.
- 정적 분석은 `dart analyze lib test`(한글 디렉토리명 때문에 `flutter analyze` 크래시). Flutter SDK: `/Users/soonbok/flutter/bin`.
- Firestore/플러그인 코드는 구현 + 기기 수동 검증.
- 앱 완료 게이트: `tool/verify.sh` 통과.
- 커밋: Conventional Commits. 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 0: 사람 선행 — Firestore 활성화 (코드 아님)

- [ ] **Step 1: Firebase 콘솔에서 Cloud Firestore 데이터베이스 생성**

Firebase Console → Firestore Database → **데이터베이스 만들기**(프로덕션 모드, 리전 선택). 이게 없으면 기기 검증 시 프로필 생성이 실패한다.

> 산출물은 코드가 아니라 "Firestore DB 생성됨". 보안 규칙 배포는 Task 5에서 파일을 만든 뒤 사람이 `firebase deploy --only firestore:rules`로 수행한다.

---

### Task 1: `cloud_firestore` 의존성

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 패키지 추가**

`pubspec.yaml`의 `dependencies:`에서 `firebase_auth` 줄 아래에 추가:
```yaml
  cloud_firestore: ^6.0.2
```

- [ ] **Step 2: 설치**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter pub get`
Expected: `Got dependencies!` (충돌 시 solver 제안대로 상한 조정하되 기존 firebase_core `^4.11.0`·cloud_functions는 건드리지 않는다).

- [ ] **Step 3: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add pubspec.yaml pubspec.lock
git commit -m "chore: cloud_firestore 의존성 추가"
```

---

### Task 2: `UserProfile` 모델 + `LoginType`

**Files:**
- Create: `lib/community/models/user_profile.dart`
- Test: `test/community/user_profile_test.dart`

**Interfaces:**
- Produces: `enum LoginType { google, apple, kakao }`, `LoginType parseLoginType(String?)`, `class UserProfile { uid, userId?, nickname, loginType, createdAt?, photoUrl?; Map toCreateMap(); UserProfile.fromData(String uid, Map data) }`.

- [ ] **Step 1: 실패 테스트 작성**

`test/community/user_profile_test.dart` 생성:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/user_profile.dart';

void main() {
  test('parseLoginType: 유효값 파싱, 이상/누락은 google 폴백', () {
    expect(parseLoginType('google'), LoginType.google);
    expect(parseLoginType('apple'), LoginType.apple);
    expect(parseLoginType('kakao'), LoginType.kakao);
    expect(parseLoginType(null), LoginType.google);
    expect(parseLoginType('xxx'), LoginType.google);
  });

  test('toCreateMap: 필드 매핑, loginType은 소문자 이름, createdAt 제외', () {
    const p = UserProfile(
      uid: 'u1',
      userId: 'a@b.com',
      nickname: '귀여운너구리1',
      loginType: LoginType.apple,
      photoUrl: 'http://x/y.png',
    );
    final m = p.toCreateMap();
    expect(m['uid'], 'u1');
    expect(m['userId'], 'a@b.com');
    expect(m['nickname'], '귀여운너구리1');
    expect(m['loginType'], 'apple');
    expect(m['photoUrl'], 'http://x/y.png');
    expect(m.containsKey('createdAt'), isFalse);
  });

  test('userId/photoUrl 은 null 허용', () {
    const p = UserProfile(
      uid: 'u1',
      nickname: '느긋한수달2',
      loginType: LoginType.kakao,
    );
    final m = p.toCreateMap();
    expect(m['userId'], isNull);
    expect(m['photoUrl'], isNull);
    expect(m['loginType'], 'kakao');
  });

  test('fromData: 복원(누락 필드는 안전한 기본값)', () {
    final now = DateTime(2026, 7, 5);
    final p = UserProfile.fromData('u9', {
      'userId': null,
      'nickname': '씩씩한판다7',
      'loginType': 'google',
      'createdAt': now,
      'photoUrl': null,
    });
    expect(p.uid, 'u9');
    expect(p.userId, isNull);
    expect(p.nickname, '씩씩한판다7');
    expect(p.loginType, LoginType.google);
    expect(p.createdAt, now);
    expect(p.photoUrl, isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/community/user_profile_test.dart`
Expected: FAIL — `user_profile.dart` 없음.

- [ ] **Step 3: 구현**

`lib/community/models/user_profile.dart` 생성:
```dart
// lib/community/models/user_profile.dart
// 순수 Dart — Flutter/plugin import 금지.

enum LoginType { google, apple, kakao }

/// enum 이름이 곧 wire 문자열(google/apple/kakao).
LoginType parseLoginType(String? s) {
  switch (s) {
    case 'google':
      return LoginType.google;
    case 'apple':
      return LoginType.apple;
    case 'kakao':
      return LoginType.kakao;
    default:
      return LoginType.google;
  }
}

/// 커뮤니티 사용자 프로필(/users/{uid}).
class UserProfile {
  final String uid;
  final String? userId; // 이메일(없을 수 있음)
  final String nickname;
  final LoginType loginType;
  final DateTime? createdAt;
  final String? photoUrl;
  const UserProfile({
    required this.uid,
    required this.nickname,
    required this.loginType,
    this.userId,
    this.createdAt,
    this.photoUrl,
  });

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  Map<String, dynamic> toCreateMap() => {
    'uid': uid,
    'userId': userId,
    'nickname': nickname,
    'loginType': loginType.name,
    'photoUrl': photoUrl,
  };

  /// Firestore 데이터(createdAt은 이미 DateTime으로 변환된 상태)에서 복원.
  factory UserProfile.fromData(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      userId: data['userId'] as String?,
      nickname: (data['nickname'] as String?) ?? '',
      loginType: parseLoginType(data['loginType'] as String?),
      createdAt: data['createdAt'] as DateTime?,
      photoUrl: data['photoUrl'] as String?,
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/community/user_profile_test.dart`
Expected: PASS (4개).

- [ ] **Step 5: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/models/user_profile.dart test/community/user_profile_test.dart
git commit -m "feat: UserProfile 모델 + LoginType"
```

---

### Task 3: 랜덤 닉네임 생성기

**Files:**
- Create: `lib/community/nickname_generator.dart`
- Test: `test/community/nickname_generator_test.dart`

**Interfaces:**
- Produces: `String generateNickname({Random? random})`, `const nicknameAdjectives`, `const nicknameAnimals`.

- [ ] **Step 1: 실패 테스트 작성**

`test/community/nickname_generator_test.dart` 생성:
```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/nickname_generator.dart';

void main() {
  test('형식: 형용사+동물+숫자(0~9999)', () {
    final n = generateNickname(random: Random(1));
    // 숫자로 끝난다
    expect(RegExp(r'\d+$').hasMatch(n), isTrue);
    // 목록의 형용사로 시작하고, 목록의 동물을 포함한다
    final adj = nicknameAdjectives.firstWhere((a) => n.startsWith(a));
    final rest = n.substring(adj.length);
    final animal = nicknameAnimals.firstWhere((a) => rest.startsWith(a));
    final digits = rest.substring(animal.length);
    expect(int.parse(digits), inInclusiveRange(0, 9999));
  });

  test('같은 시드면 결정적(동일 결과)', () {
    expect(generateNickname(random: Random(42)),
        generateNickname(random: Random(42)));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/community/nickname_generator_test.dart`
Expected: FAIL — `nickname_generator.dart` 없음.

- [ ] **Step 3: 구현**

`lib/community/nickname_generator.dart` 생성:
```dart
// lib/community/nickname_generator.dart
// 순수 Dart — Flutter/plugin import 금지.
import 'dart:math';

const nicknameAdjectives = [
  '귀여운', '용감한', '느긋한', '엉뚱한', '따뜻한', '수줍은', '씩씩한', '나른한',
];
const nicknameAnimals = [
  '너구리', '수달', '고양이', '판다', '여우', '펭귄', '고슴도치', '알파카',
];

/// 형용사+동물+숫자(0~9999) 랜덤 닉네임. [random] 주입 시 결정적(테스트용).
String generateNickname({Random? random}) {
  final r = random ?? Random();
  final adj = nicknameAdjectives[r.nextInt(nicknameAdjectives.length)];
  final animal = nicknameAnimals[r.nextInt(nicknameAnimals.length)];
  final number = r.nextInt(10000);
  return '$adj$animal$number';
}
```

- [ ] **Step 4: 통과 확인**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/community/nickname_generator_test.dart`
Expected: PASS (2개).

- [ ] **Step 5: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/nickname_generator.dart test/community/nickname_generator_test.dart
git commit -m "feat: 랜덤 닉네임 생성기(형용사+동물+숫자)"
```

---

### Task 4: `UserRepository.ensureProfile`

Firestore 트랜잭션으로 "없으면 생성". 플러그인 의존이라 단위 테스트 대신 기기 수동 검증.

**Files:**
- Create: `lib/community/user_repository.dart`

**Interfaces:**
- Consumes: `UserProfile`/`LoginType`(Task 2), `generateNickname`(Task 3), `cloud_firestore`, `firebase_auth`.
- Produces: `class UserRepository { UserRepository({FirebaseFirestore? db}); Future<UserProfile> ensureProfile({required User user, required LoginType loginType}) }`.

- [ ] **Step 1: 구현**

`lib/community/user_repository.dart` 생성:
```dart
// lib/community/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user_profile.dart';
import 'nickname_generator.dart';

/// Firestore /users 접근. 판단 로직 없음(생성/조회만).
class UserRepository {
  final FirebaseFirestore _db;
  UserRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// /users/{uid}가 없으면 랜덤 닉네임으로 생성, 있으면 기존 프로필을 반환한다.
  Future<UserProfile> ensureProfile({
    required User user,
    required LoginType loginType,
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    return _db.runTransaction<UserProfile>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.data()!);
        final ts = data['createdAt'];
        data['createdAt'] = ts is Timestamp ? ts.toDate() : null;
        return UserProfile.fromData(user.uid, data);
      }
      final profile = UserProfile(
        uid: user.uid,
        userId: user.email,
        nickname: generateNickname(),
        loginType: loginType,
        photoUrl: user.photoURL,
      );
      tx.set(ref, {
        ...profile.toCreateMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return profile;
    });
  }
}
```

- [ ] **Step 2: 정적 분석**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/user_repository.dart`
Expected: No issues found!

- [ ] **Step 3: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/user_repository.dart
git commit -m "feat: UserRepository.ensureProfile — /users 트랜잭션 생성/조회"
```

---

### Task 5: `AuthService`에 프로필 생성 연결 + 보안 규칙

**Files:**
- Modify: `lib/community/auth_service.dart`
- Modify: `firestore.rules`

**Interfaces:**
- Consumes: `UserRepository.ensureProfile`(Task 4), `LoginType`(Task 2).

- [ ] **Step 1: AuthService에 UserRepository 주입 + 호출**

`lib/community/auth_service.dart`를 수정한다.

import 추가(기존 import 아래):
```dart
import 'user_repository.dart';
import 'models/user_profile.dart';
```
필드·생성자 교체:
```dart
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  final UserRepository _users;
  AuthService({FirebaseAuth? auth, GoogleSignIn? google, UserRepository? users})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn(),
      _users = users ?? UserRepository();
```
`signInWithGoogle()`의 마지막 부분을 교체:
```dart
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) {
      await _users.ensureProfile(user: user, loginType: LoginType.google);
    }
    return user;
```
`signInWithApple()`의 `try` 블록 마지막 부분을 교체:
```dart
      final result = await _auth.signInWithCredential(oauth);
      final user = result.user;
      if (user != null) {
        await _users.ensureProfile(user: user, loginType: LoginType.apple);
      }
      return user;
```

- [ ] **Step 2: 보안 규칙 추가**

`firestore.rules`의 `match /databases/{database}/documents {` 안, 기존 `match /{document=**}` **위에** `/users` 규칙을 추가:
```
    // 사용자 프로필: 로그인 사용자는 읽기, 본인 문서만 생성/수정.
    match /users/{uid} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.auth.uid == uid
                    && request.resource.data.uid == uid;
      allow update: if request.auth != null && request.auth.uid == uid;
    }
```
(기존 catch-all `allow read, write: if false;`는 그대로 둔다 — Firestore는 매칭된 규칙 중 하나라도 allow면 허용하므로 /users만 열린다.)

- [ ] **Step 3: 정적 분석**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test`
Expected: No issues found!

- [ ] **Step 4: 커밋**

```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add lib/community/auth_service.dart firestore.rules
git commit -m "feat: 로그인 성공 시 프로필 자동 생성 + /users 보안 규칙"
```

> 규칙 배포는 사람: `firebase deploy --only firestore:rules`.

---

### Task 6: 최종 검증

- [ ] **Step 1: 앱 게이트**

Run: `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh`
Expected: `✅ verify 통과`.

- [ ] **Step 2: 기기 수동 검증 (사람)**

Task 0(Firestore 생성) + 규칙 배포 후 `flutter run`:
- 처음 로그인(Google/Apple) → Firestore 콘솔 `/users/{uid}`에 문서 생성됨: `nickname`(형용사+동물+숫자), `loginType`, `userId`(이메일 또는 null), `createdAt`, `uid`.
- 로그아웃 후 재로그인 → 문서가 **새로 안 생기고** 닉네임·가입일 유지.
- (Apple 가림 이메일/미제공 시 `userId`가 null이어도 정상 생성)

---

## Self-Review (작성자 확인)

- **스펙 커버리지:** 필드/모델=Task 2, 랜덤 닉네임=Task 3, 없으면 생성 트랜잭션=Task 4, 로그인 연결(loginType 전달)=Task 5, 보안 규칙=Task 5, 의존성=Task 1, Firestore 활성화=Task 0. null 이메일 허용=Task 2·4에서 처리.
- **플레이스홀더:** 코드·테스트 실제 내용 포함. Task 1/4에 버전·분석 확인 지시 구체화.
- **타입 일관성:** `UserProfile{uid,userId?,nickname,loginType,createdAt?,photoUrl?}`, `toCreateMap()`, `UserProfile.fromData(uid, data)`, `parseLoginType(String?)`, `generateNickname({Random?})`, `UserRepository.ensureProfile({user, loginType})`, `LoginType{google,apple,kakao}` — 태스크 간 일치.
- **주의:** `cloud_firestore ^6.0.2`가 기존 firebase_core `^4.11.0`과 충돌하면 solver 제안대로 조정(핵심은 6.x 계열 유지).
