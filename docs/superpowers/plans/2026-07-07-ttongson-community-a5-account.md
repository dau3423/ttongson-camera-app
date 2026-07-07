# 커뮤니티 계획 A5 — 계정 관리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 사용자가 닉네임·프로필 사진을 편집하고, 소프트 회원 탈퇴(deleteDate)와 재가입을 할 수 있는 계정 화면을 추가한다.

**Architecture:** 순수 `UserProfile`(deleteDate·isWithdrawn)·`isValidNickname`은 TDD. `UserRepository`에 프로필 업데이트·사진 업로드(Storage)·탈퇴/재가입·watchProfile 추가. `AuthService` 헬퍼 + `sign_in_sheet` 재가입 흐름. `AccountScreen`이 편집·로그아웃·탈퇴 UI, 피드 AppBar에서 진입.

**Tech Stack:** Flutter(Dart), `cloud_firestore`, `firebase_auth`, `firebase_storage`, `image_picker`. 커뮤니티 A~D 완료·병합. 신규 의존성 없음. **탈퇴는 클라이언트 소프트 삭제(함수 없음)**.

## Global Constraints

- 회원 탈퇴 = 소프트 삭제: `/users/{uid}.deleteDate = serverTimestamp`. 데이터·정보 유지. 즉시 로그아웃.
- 탈퇴 계정 재로그인: 프로필 `isWithdrawn`이면 재가입 다이얼로그 — 재가입=deleteDate 삭제, 취소=로그아웃.
- 프로필 편집: 닉네임(트림 후 **1~20자**) + 프로필 사진.
- 프로필 사진: `profile_images/{uid}/photo.jpg`. 업로드 전 `mask_processor.applyMasks(file, const [])`로 축소(최장변 1600)·EXIF 제거.
- `UserProfile`·`isValidNickname`은 **순수 Dart**(Flutter/plugin import 금지). `toCreateMap`엔 deleteDate 미포함.
- `/users/{uid}` update는 기존 본인전용 규칙으로 충분(닉네임·photoUrl·deleteDate 갱신). `storage.rules`에 profile_images 규칙만 추가.
- async-gap: await 뒤 context 사용 전 mounted/context.mounted 가드 + messenger 선캡처.
- 순수 로직 TDD. 저장소/화면/인증은 구현 + 기기 검증. 게이트: `tool/verify.sh`, `dart analyze lib test`(**`flutter analyze` 금지**). Flutter SDK `/Users/soonbok/flutter/bin`.
- 커밋: Conventional Commits + `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

```
lib/community/
  models/user_profile.dart          # (수정) deleteDate·isWithdrawn·isValidNickname
  user_repository.dart              # (수정) watchProfile·updateProfile·uploadProfilePhoto·withdraw·rejoin + Storage
  auth_service.dart                 # (수정) myProfile·withdraw·rejoin 헬퍼
  screens/sign_in_sheet.dart        # (수정) 재가입 흐름
  screens/account_screen.dart       # (신규) 계정 화면
  screens/feed_screen.dart          # (수정) AppBar 계정 진입
storage.rules                       # (수정) profile_images 규칙
test/community/user_profile_test.dart  # (수정) deleteDate·isValidNickname 테스트
```

---

### Task 1: `UserProfile` deleteDate + `isValidNickname` (TDD)

**Files:**
- Modify: `lib/community/models/user_profile.dart`
- Modify: `test/community/user_profile_test.dart`

**Interfaces:** `UserProfile` gains `DateTime? deleteDate` + `bool get isWithdrawn`; top-level `bool isValidNickname(String)`.

- [ ] **Step 1: 실패 테스트** — `test/community/user_profile_test.dart`의 `main()` 끝(마지막 `}` 앞)에 추가:

```dart
  test('fromData: deleteDate 복원 + isWithdrawn', () {
    final active = UserProfile.fromData('u', {'nickname': 'n'});
    expect(active.deleteDate, isNull);
    expect(active.isWithdrawn, isFalse);

    final now = DateTime(2026, 7, 7);
    final gone = UserProfile.fromData('u', {'nickname': 'n', 'deleteDate': now});
    expect(gone.deleteDate, now);
    expect(gone.isWithdrawn, isTrue);
  });

  test('isValidNickname: 트림 후 1~20자', () {
    expect(isValidNickname(''), isFalse);
    expect(isValidNickname('   '), isFalse);
    expect(isValidNickname('a'), isTrue);
    expect(isValidNickname('  가  '), isTrue);
    expect(isValidNickname('a' * 20), isTrue);
    expect(isValidNickname('a' * 21), isFalse);
  });
```

- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/community/user_profile_test.dart` → FAIL (deleteDate/isWithdrawn/isValidNickname 없음).
- [ ] **Step 3: 구현** — `lib/community/models/user_profile.dart` 전체를 아래로 교체:

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

/// 닉네임 유효성: 트림 후 1~20자.
bool isValidNickname(String nickname) {
  final n = nickname.trim().length;
  return n >= 1 && n <= 20;
}

/// 커뮤니티 사용자 프로필(/users/{uid}).
class UserProfile {
  final String uid;
  final String? userId; // 이메일(없을 수 있음)
  final String nickname;
  final LoginType loginType;
  final DateTime? createdAt;
  final String? photoUrl;
  final DateTime? deleteDate; // 설정되면 탈퇴(소프트) 상태
  const UserProfile({
    required this.uid,
    required this.nickname,
    required this.loginType,
    this.userId,
    this.createdAt,
    this.photoUrl,
    this.deleteDate,
  });

  bool get isWithdrawn => deleteDate != null;

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  /// deleteDate는 탈퇴 시에만 설정하므로 생성 맵에 미포함.
  Map<String, dynamic> toCreateMap() => {
    'uid': uid,
    'userId': userId,
    'nickname': nickname,
    'loginType': loginType.name,
    'photoUrl': photoUrl,
  };

  /// Firestore 데이터(createdAt·deleteDate는 이미 DateTime으로 변환된 상태)에서 복원.
  factory UserProfile.fromData(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      userId: data['userId'] as String?,
      nickname: (data['nickname'] as String?) ?? '',
      loginType: parseLoginType(data['loginType'] as String?),
      createdAt: data['createdAt'] as DateTime?,
      photoUrl: data['photoUrl'] as String?,
      deleteDate: data['deleteDate'] as DateTime?,
    );
  }
}
```

- [ ] **Step 4:** `flutter test test/community/user_profile_test.dart` → PASS.
- [ ] **Step 5: 커밋**

```bash
git add lib/community/models/user_profile.dart test/community/user_profile_test.dart
git commit -m "feat: UserProfile deleteDate·isWithdrawn + isValidNickname"
```

---

### Task 2: `UserRepository` 편집·업로드·탈퇴 + Storage 규칙

**Files:**
- Modify: `lib/community/user_repository.dart` (전체 교체)
- Modify: `storage.rules`

**Interfaces:**
- Consumes: `applyMasks`(mask_processor, 기존), `UserProfile`(T1).
- Produces: `watchProfile(uid)`, `updateProfile({uid, nickname?, photoUrl?})`, `uploadProfilePhoto({uid, image})`, `withdraw(uid)`, `rejoin(uid)`. (`ensureProfile`·`getProfile` 유지, deleteDate 변환 보완.)

- [ ] **Step 1: 파일 전체 교체** — `lib/community/user_repository.dart`를 아래로 교체:

```dart
// lib/community/user_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'models/user_profile.dart';
import 'nickname_generator.dart';
import 'mask_processor.dart';

/// Firestore /users + 프로필 사진 Storage 접근. 판단 로직 없음.
class UserRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  UserRepository({FirebaseFirestore? db, FirebaseStorage? storage})
    : _db = db ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  /// Firestore 원시 데이터의 Timestamp 필드(createdAt·deleteDate)를 DateTime으로.
  Map<String, dynamic> _toModelData(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    for (final key in const ['createdAt', 'deleteDate']) {
      final ts = data[key];
      if (ts is Timestamp) data[key] = ts.toDate();
    }
    return data;
  }

  /// /users/{uid}가 없으면 랜덤 닉네임으로 생성, 있으면 기존 프로필을 반환한다.
  Future<UserProfile> ensureProfile({
    required User user,
    required LoginType loginType,
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    return _db.runTransaction<UserProfile>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        return UserProfile.fromData(user.uid, _toModelData(snap.data()!));
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

  /// /users/{uid} 프로필을 조회한다. 없으면 null.
  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromData(uid, _toModelData(snap.data()!));
  }

  /// /users/{uid} 프로필 스트림(편집 즉시 반영).
  Stream<UserProfile?> watchProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromData(uid, _toModelData(snap.data()!));
    });
  }

  /// 전달된 필드만 부분 업데이트.
  Future<void> updateProfile({
    required String uid,
    String? nickname,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (data.isEmpty) return;
    await _db.collection('users').doc(uid).update(data);
  }

  /// 프로필 사진을 축소·EXIF 제거 후 업로드하고 다운로드 URL을 반환한다.
  Future<String> uploadProfilePhoto({
    required String uid,
    required File image,
  }) async {
    final processed = await applyMasks(image, const []);
    final ref = _storage.ref('profile_images/$uid/photo.jpg');
    await ref.putFile(processed, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// 소프트 탈퇴: deleteDate 설정.
  Future<void> withdraw(String uid) async {
    await _db.collection('users').doc(uid).update({
      'deleteDate': FieldValue.serverTimestamp(),
    });
  }

  /// 재가입: deleteDate 제거.
  Future<void> rejoin(String uid) async {
    await _db.collection('users').doc(uid).update({
      'deleteDate': FieldValue.delete(),
    });
  }
}
```

- [ ] **Step 2: Storage 규칙** — `storage.rules`의 `match /post_images/{uid}/{file} { ... }` 블록 **다음에**(catch-all `match /{allPaths=**}` 위에) 추가:

```
    match /profile_images/{uid}/{file} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == uid
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
```

- [ ] **Step 3:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/user_repository.dart` → No issues found! (Storage 규칙 중괄호 균형: `python3 -c "s=open('storage.rules').read(); print(s.count('{')==s.count('}'))"` → True)
- [ ] **Step 4: 커밋**

```bash
git add lib/community/user_repository.dart storage.rules
git commit -m "feat: UserRepository 프로필 편집·사진 업로드·탈퇴/재가입 + profile_images 규칙"
```

> Storage 규칙 배포는 사람: `firebase deploy --only storage`.

---

### Task 3: `AuthService` 헬퍼 + 재가입 흐름

**Files:**
- Modify: `lib/community/auth_service.dart`
- Modify: `lib/community/screens/sign_in_sheet.dart`

**Interfaces:**
- Produces(AuthService): `Future<UserProfile?> myProfile()`, `Future<void> withdraw()`, `Future<void> rejoin()`.
- Consumes: `UserRepository.{getProfile,withdraw,rejoin}`(T2), `UserProfile.isWithdrawn`(T1).

- [ ] **Step 1: AuthService 헬퍼 추가** — `lib/community/auth_service.dart`의 `signOut()` 메서드 **위에**(클래스 안) 추가:

```dart
  /// 현재 로그인 사용자의 프로필(없으면 null).
  Future<UserProfile?> myProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Future.value(null);
    return _users.getProfile(uid);
  }

  /// 소프트 탈퇴(현재 사용자).
  Future<void> withdraw() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _users.withdraw(uid);
  }

  /// 재가입(현재 사용자, deleteDate 제거).
  Future<void> rejoin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _users.rejoin(uid);
  }
```

> `models/user_profile.dart`는 이미 import되어 있으므로 추가 import 불필요.

- [ ] **Step 2: 재가입 흐름** — `lib/community/screens/sign_in_sheet.dart`의 `_run(...)` 메서드 전체를 아래로 교체:

```dart
  Future<void> _run(Future<Object?> Function() signIn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final user = await signIn();
      if (user == null) {
        if (mounted) Navigator.pop(context, false);
        return;
      }
      final profile = await widget.auth.myProfile();
      if (!mounted) return;
      if (profile?.isWithdrawn ?? false) {
        final rejoin = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('탈퇴한 계정이에요'),
            content: const Text('이 계정은 탈퇴 처리됐어요. 다시 가입할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('재가입'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (rejoin == true) {
          await widget.auth.rejoin();
          if (mounted) Navigator.pop(context, true);
        } else {
          await widget.auth.signOut();
          if (mounted) Navigator.pop(context, false);
        }
        return;
      }
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }
```

- [ ] **Step 3:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib/community/auth_service.dart lib/community/screens/sign_in_sheet.dart` → No issues found!
- [ ] **Step 4: 커밋**

```bash
git add lib/community/auth_service.dart lib/community/screens/sign_in_sheet.dart
git commit -m "feat: AuthService myProfile·withdraw·rejoin + 탈퇴 계정 재가입 흐름"
```

---

### Task 4: 계정 화면 + 피드 진입

**Files:**
- Create: `lib/community/screens/account_screen.dart`
- Modify: `lib/community/screens/feed_screen.dart`

**Interfaces:**
- Consumes: `AuthService.{currentUser,signOut,withdraw}`(T3+기존), `UserRepository.{watchProfile,updateProfile,uploadProfilePhoto}`(T2), `UserProfile`·`isValidNickname`(T1).
- Produces: `class AccountScreen extends StatefulWidget { AccountScreen({required AuthService auth, UserRepository? users}) }`.

- [ ] **Step 1: 구현** — `lib/community/screens/account_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth_service.dart';
import '../user_repository.dart';
import '../models/user_profile.dart';

/// 내 계정 — 프로필 편집(닉네임·사진), 로그아웃, 회원 탈퇴.
class AccountScreen extends StatefulWidget {
  final AuthService auth;
  final UserRepository users;
  AccountScreen({super.key, required this.auth, UserRepository? users})
    : users = users ?? UserRepository();

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;
  String get _uid => widget.auth.currentUser?.uid ?? '';

  Future<void> _changePhoto() async {
    if (_busy) return;
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await widget.users.uploadProfilePhoto(
        uid: _uid,
        image: File(x.path),
      );
      await widget.users.updateProfile(uid: _uid, photoUrl: url);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('사진 변경에 실패했어요')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNickname(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('닉네임 편집'),
        content: TextField(
          controller: controller,
          maxLength: 20,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    final trimmed = result.trim();
    if (!isValidNickname(trimmed)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임은 1~20자로 입력해 주세요')));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.users.updateProfile(uid: _uid, nickname: trimmed);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('닉네임 변경에 실패했어요')));
    }
  }

  Future<void> _logout() async {
    await widget.auth.signOut();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('정말 탈퇴하시겠어요? 다시 로그인하면 재가입할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.auth.withdraw();
      await widget.auth.signOut();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('탈퇴에 실패했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 계정')),
      body: StreamBuilder<UserProfile?>(
        stream: widget.users.watchProfile(_uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('불러오지 못했어요'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) {
            return const Center(child: Text('프로필이 없어요'));
          }
          final hasPhoto = p.photoUrl != null && p.photoUrl!.isNotEmpty;
          return ListView(
            children: [
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : _changePhoto,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: hasPhoto
                        ? NetworkImage(p.photoUrl!)
                        : null,
                    child: hasPhoto
                        ? null
                        : const Icon(Icons.person, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _changePhoto,
                  child: const Text('사진 변경'),
                ),
              ),
              ListTile(
                title: const Text('닉네임'),
                subtitle: Text(p.nickname),
                trailing: const Icon(Icons.edit, size: 20),
                onTap: () => _editNickname(p.nickname),
              ),
              ListTile(title: const Text('로그인'), subtitle: Text(p.loginType.name)),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                onTap: _logout,
              ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text(
                  '회원 탈퇴',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _withdraw,
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: 피드 AppBar 진입** — `lib/community/screens/feed_screen.dart` import 블록에 추가:

```dart
import 'account_screen.dart';
```

그리고 `AppBar`의 `actions:` 리스트에서 기존 차단목록 `IconButton`(`Icons.block`) **앞에** 계정 아이콘 추가:

```dart
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: '내 계정',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountScreen(auth: auth, users: users),
              ),
            ),
          ),
```

- [ ] **Step 3:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && dart analyze lib test` → No issues found!
- [ ] **Step 4: 커밋**

```bash
git add lib/community/screens/account_screen.dart lib/community/screens/feed_screen.dart
git commit -m "feat: 계정 화면(프로필 편집·로그아웃·탈퇴) + 피드 진입"
```

---

### Task 5: 최종 검증

- [ ] **Step 1:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh` → `✅ verify 통과`.
- [ ] **Step 2:** `cd functions && npx vitest run` → 전부 PASS(회귀 없음).
- [ ] **Step 3: 기기 수동 검증 (사람)** — storage 규칙 배포 후 `flutter run`:
  - 피드 AppBar 사람 아이콘 → 계정 화면. 닉네임 편집(1~20자 검증), 사진 변경(갤러리→반영).
  - 로그아웃 → 미로그인.
  - 회원 탈퇴 → 확인 → 로그아웃. 같은 계정으로 재로그인 → '탈퇴한 계정' 다이얼로그 → 재가입 시 기존 닉네임·게시물로 복귀, 취소 시 미로그인.

---

## Self-Review (작성자 확인)

- **스펙 커버리지(A5):** UserProfile deleteDate·isWithdrawn·isValidNickname=T1, 저장소 편집/업로드/탈퇴/재가입/watchProfile + Storage 규칙=T2, AuthService 헬퍼 + 재가입 흐름=T3, 계정 화면 + 진입=T4, 검증=T5.
- **플레이스홀더:** 없음 — 모든 코드·테스트 실제 내용 포함. T1·T2는 상호의존 편집이 많아 파일 전체 교체.
- **타입 일관성:** `UserProfile{deleteDate,isWithdrawn}`·`isValidNickname`, `UserRepository.{watchProfile,updateProfile,uploadProfilePhoto,withdraw,rejoin}`, `AuthService.{myProfile,withdraw,rejoin}`, `AccountScreen({auth,users})` — 태스크 간 일치. 기존 `ensureProfile`·`getProfile`는 `_toModelData`로 deleteDate 변환 보완(탈퇴 계정 재로그인 시 Timestamp 캐스트 오류 방지).
- **주의:** 프로필 사진 경로는 `profile_images/{uid}/photo.jpg`(폴더-per-uid, 규칙 {uid} 바인딩 정확). 사진 업로드는 가림 파이프라인(applyMasks 빈 리스트) 재사용으로 EXIF 제거. 탈퇴는 클라이언트 소프트 삭제(함수 없음), 규칙은 기존 users 본인전용 update로 충분. Storage 규칙 배포는 사람.
```
