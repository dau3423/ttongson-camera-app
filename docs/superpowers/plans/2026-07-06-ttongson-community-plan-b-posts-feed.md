# 커뮤니티 계획 B — 게시·피드·좋아요 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 사용자가 사진+한 줄 팁을 올리고, 최신순 피드에서 보고, 좋아요를 누른다.

**Architecture:** 순수 모델(Post)은 TDD. `PostRepository`가 Storage 업로드 + Firestore 문서 생성/조회/좋아요를 담당. 좋아요 수는 Cloud Function(Firestore 트리거)이 관리(클라이언트는 likeCount 직접 못 씀). 화면: 피드·작성. 커뮤니티 진입은 로그인 게이트 뒤.

**Tech Stack:** Flutter(Dart), `cloud_firestore`, `firebase_storage`, `image_picker`, `firebase_auth`; Functions v2 Firestore 트리거(TS, vitest).

**범위:** 커뮤니티 B. A1~A4 병합됨. 가림(C)·댓글/신고(D)는 별도. **B의 작성 흐름은 가림 없이 사진→캡션→업로드**이며, 가림 편집 단계는 C에서 삽입한다.

## Global Constraints

- `posts/{postId}`: authorUid, authorName(닉네임 비정규화), imageUrl, caption(<=140자), createdAt(서버 타임스탬프), likeCount, commentCount, reportCount, hidden. `likeCount`/`commentCount`/`reportCount`/`hidden`은 **클라이언트 쓰기 금지**(함수만).
- `posts/{id}/likes/{uid}`: 문서 존재 = 좋아요.
- Storage: `post_images/{uid}/{postId}.jpg` — 본인 경로만 업로드.
- 피드: 최신순(createdAt desc), `hidden==false`만.
- 순수 로직 TDD. Firestore/Storage/UI/플러그인은 구현 + 기기 수동 검증.
- 앱 게이트 `tool/verify.sh`, 함수 게이트 `npx vitest run`. 정적분석 `dart analyze lib test`. Flutter SDK `/Users/soonbok/flutter/bin`.
- 커밋: Conventional Commits + `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 0: 사람 선행 — Cloud Storage 활성화 (코드 아님)

- [ ] **Step 1:** Firebase 콘솔 → Storage → 시작하기(기본 버킷 생성). Firestore는 A4에서 이미 생성.
> 규칙·함수 배포는 각 태스크 후 사람이 수행: `firebase deploy --only functions,firestore:rules,storage`.

---

### Task 1: 의존성 추가

**Files:** Modify `pubspec.yaml`

- [ ] **Step 1:** `dependencies:`의 `cloud_firestore` 아래에 추가:
```yaml
  firebase_storage: ^13.0.4
  image_picker: ^1.1.2
```
- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter pub get` → `Got dependencies!`(충돌 시 solver 제안대로 조정, firebase_core 불변).
- [ ] **Step 3:**
```bash
cd /Users/soonbok/Projects/junicode/똥손카메라
git add pubspec.yaml pubspec.lock
git commit -m "chore: firebase_storage·image_picker 의존성 추가"
```

---

### Task 2: `Post` 모델

**Files:** Create `lib/community/models/post.dart`, Test `test/community/post_test.dart`

**Interfaces:** `class Post { id, authorUid, authorName, imageUrl, caption, createdAt?, likeCount, commentCount }`, `Map toCreateMap({required String imageUrl})`, `Post.fromData(String id, Map data)`.

- [ ] **Step 1: 실패 테스트** — `test/community/post_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/post.dart';

void main() {
  test('toCreateMap: 카운터는 0, hidden false, createdAt 제외', () {
    const p = Post(
      id: '',
      authorUid: 'u1',
      authorName: '귀여운너구리1',
      imageUrl: 'https://x/y.jpg',
      caption: '역광에서 살짝 밑에서',
    );
    final m = p.toCreateMap(imageUrl: 'https://x/y.jpg');
    expect(m['authorUid'], 'u1');
    expect(m['authorName'], '귀여운너구리1');
    expect(m['imageUrl'], 'https://x/y.jpg');
    expect(m['caption'], '역광에서 살짝 밑에서');
    expect(m['likeCount'], 0);
    expect(m['commentCount'], 0);
    expect(m['reportCount'], 0);
    expect(m['hidden'], false);
    expect(m.containsKey('createdAt'), isFalse);
  });

  test('fromData: 복원(createdAt DateTime, 카운터 유지)', () {
    final now = DateTime(2026, 7, 6);
    final p = Post.fromData('post9', {
      'authorUid': 'u2',
      'authorName': '느긋한수달2',
      'imageUrl': 'https://a/b.jpg',
      'caption': '가운데 정렬',
      'createdAt': now,
      'likeCount': 5,
      'commentCount': 2,
    });
    expect(p.id, 'post9');
    expect(p.authorName, '느긋한수달2');
    expect(p.caption, '가운데 정렬');
    expect(p.createdAt, now);
    expect(p.likeCount, 5);
    expect(p.commentCount, 2);
  });

  test('fromData: 카운터 누락 시 0', () {
    final p = Post.fromData('p', {
      'authorUid': 'u',
      'authorName': 'n',
      'imageUrl': 'i',
      'caption': 'c',
    });
    expect(p.likeCount, 0);
    expect(p.commentCount, 0);
  });
}
```
- [ ] **Step 2:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && flutter test test/community/post_test.dart` → FAIL.
- [ ] **Step 3: 구현** — `lib/community/models/post.dart`:
```dart
// lib/community/models/post.dart
// 순수 Dart — Flutter/plugin import 금지.

class Post {
  final String id;
  final String authorUid;
  final String authorName;
  final String imageUrl;
  final String caption;
  final DateTime? createdAt;
  final int likeCount;
  final int commentCount;
  const Post({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.imageUrl,
    required this.caption,
    this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  Map<String, dynamic> toCreateMap({required String imageUrl}) => {
    'authorUid': authorUid,
    'authorName': authorName,
    'imageUrl': imageUrl,
    'caption': caption,
    'likeCount': 0,
    'commentCount': 0,
    'reportCount': 0,
    'hidden': false,
  };

  factory Post.fromData(String id, Map<String, dynamic> data) => Post(
    id: id,
    authorUid: (data['authorUid'] as String?) ?? '',
    authorName: (data['authorName'] as String?) ?? '',
    imageUrl: (data['imageUrl'] as String?) ?? '',
    caption: (data['caption'] as String?) ?? '',
    createdAt: data['createdAt'] as DateTime?,
    likeCount: (data['likeCount'] as int?) ?? 0,
    commentCount: (data['commentCount'] as int?) ?? 0,
  );
}
```
- [ ] **Step 4:** `flutter test test/community/post_test.dart` → PASS (3).
- [ ] **Step 5:**
```bash
git add lib/community/models/post.dart test/community/post_test.dart
git commit -m "feat: Post 모델"
```

---

### Task 3: `UserRepository.getProfile`

**Files:** Modify `lib/community/user_repository.dart`

**Interfaces:** `Future<UserProfile?> getProfile(String uid)`.

- [ ] **Step 1:** `ensureProfile` 메서드 아래에 추가:
```dart
  /// /users/{uid} 프로필을 조회한다. 없으면 null.
  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    final data = Map<String, dynamic>.from(snap.data()!);
    final ts = data['createdAt'];
    data['createdAt'] = ts is Timestamp ? ts.toDate() : null;
    return UserProfile.fromData(uid, data);
  }
```
- [ ] **Step 2:** `dart analyze lib/community/user_repository.dart` → No issues found!
- [ ] **Step 3:**
```bash
git add lib/community/user_repository.dart
git commit -m "feat: UserRepository.getProfile 프로필 조회"
```

---

### Task 4: `PostRepository`

**Files:** Create `lib/community/post_repository.dart`

**Interfaces:**
- `Future<Post> createPost({required String uid, required String authorName, required File image, required String caption})`
- `Stream<List<Post>> feed({int limit = 30})`
- `Future<void> toggleLike({required String postId, required String uid})`
- `Stream<bool> likedByMe({required String postId, required String uid})`

- [ ] **Step 1: 구현** — `lib/community/post_repository.dart`:
```dart
// lib/community/post_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'models/post.dart';

/// Firestore /posts + Storage 접근. 판단 로직 없음.
class PostRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  PostRepository({FirebaseFirestore? db, FirebaseStorage? storage})
    : _db = db ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  /// 이미지를 Storage에 올리고 게시물 문서를 생성한다.
  Future<Post> createPost({
    required String uid,
    required String authorName,
    required File image,
    required String caption,
  }) async {
    final ref = _db.collection('posts').doc();
    final postId = ref.id;
    final storageRef = _storage.ref('post_images/$uid/$postId.jpg');
    await storageRef.putFile(
      image,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final imageUrl = await storageRef.getDownloadURL();
    final post = Post(
      id: postId,
      authorUid: uid,
      authorName: authorName,
      imageUrl: imageUrl,
      caption: caption,
    );
    await ref.set({
      ...post.toCreateMap(imageUrl: imageUrl),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return post;
  }

  /// 최신순 피드(숨김 제외).
  Stream<List<Post>> feed({int limit = 30}) {
    return _db
        .collection('posts')
        .where('hidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (q) => q.docs
              .map((d) => Post.fromData(d.id, _withDate(d.data())))
              .toList(),
        );
  }

  /// 좋아요 토글(문서 생성/삭제). likeCount는 함수가 관리.
  Future<void> toggleLike({
    required String postId,
    required String uid,
  }) async {
    final ref = _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }

  Stream<bool> likedByMe({required String postId, required String uid}) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists);
  }

  Map<String, dynamic> _withDate(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    final ts = data['createdAt'];
    data['createdAt'] = ts is Timestamp ? ts.toDate() : null;
    return data;
  }
}
```
- [ ] **Step 2:** `dart analyze lib/community/post_repository.dart` → No issues found!
- [ ] **Step 3:**
```bash
git add lib/community/post_repository.dart
git commit -m "feat: PostRepository — 업로드·피드·좋아요"
```

---

### Task 5: 좋아요 집계 함수 + 보안 규칙

**Files:** Create `functions/src/likes.ts`, `functions/test/likes.test.ts`, Modify `functions/src/index.ts`, `firestore.rules`, Create `storage.rules`, Modify `firebase.json`

**Interfaces:** `likeDelta(before: boolean, after: boolean) -> number`, trigger `onLikeWrite`.

- [ ] **Step 1: 실패 테스트** — `functions/test/likes.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { likeDelta } from "../src/likes.js";

describe("likeDelta", () => {
  it("생성(+1)", () => expect(likeDelta(false, true)).toBe(1));
  it("삭제(-1)", () => expect(likeDelta(true, false)).toBe(-1));
  it("변화 없음(0)", () => {
    expect(likeDelta(true, true)).toBe(0);
    expect(likeDelta(false, false)).toBe(0);
  });
});
```
- [ ] **Step 2:** `cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run likes` → FAIL.
- [ ] **Step 3: 구현** — `functions/src/likes.ts`:
```ts
// functions/src/likes.ts
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

if (getApps().length === 0) initializeApp();

/** 좋아요 문서 생성/삭제 delta: 생기면 +1, 사라지면 -1, 그 외 0. */
export function likeDelta(before: boolean, after: boolean): number {
  if (!before && after) return 1;
  if (before && !after) return -1;
  return 0;
}

export const onLikeWrite = onDocumentWritten(
  "posts/{postId}/likes/{uid}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    const delta = likeDelta(before, after);
    if (delta === 0) return;
    const postId = event.params.postId as string;
    await getFirestore()
      .collection("posts")
      .doc(postId)
      .update({ likeCount: FieldValue.increment(delta) });
  },
);
```
- [ ] **Step 4: export 추가** — `functions/src/index.ts`에 줄 추가:
```ts
export { onLikeWrite } from "./likes.js";
```
- [ ] **Step 5: Firestore 규칙** — `firestore.rules`의 catch-all `match /{document=**}` **위에** 추가:
```
    // 게시물: 로그인 사용자 읽기, 작성자만 생성. 카운터/hidden은 함수 전용.
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.authorUid == request.auth.uid
                    && request.resource.data.likeCount == 0
                    && request.resource.data.commentCount == 0
                    && request.resource.data.reportCount == 0
                    && request.resource.data.hidden == false;
      allow update, delete: if false;
      match /likes/{uid} {
        allow read: if request.auth != null;
        allow create, delete: if request.auth != null && request.auth.uid == uid;
      }
    }
```
- [ ] **Step 6: Storage 규칙** — `storage.rules` 생성:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /post_images/{uid}/{file} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == uid
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
    match /{allPaths=**} { allow read, write: if false; }
  }
}
```
그리고 `firebase.json` 최상위 객체에 `"storage": { "rules": "storage.rules" }` 키를 추가한다(기존 `firestore`/`functions` 키와 나란히, 유효한 JSON 유지).
- [ ] **Step 7: 통과+빌드+커밋**
```bash
cd /Users/soonbok/Projects/junicode/똥손카메라/functions && npx vitest run && npm run build && cd ..
git add functions/src/likes.ts functions/src/index.ts functions/test/likes.test.ts firestore.rules storage.rules firebase.json
git commit -m "feat: 좋아요 집계 함수 + posts/storage 보안 규칙"
```
> 배포는 사람: `firebase deploy --only functions,firestore:rules,storage`.

---

### Task 6: 피드 화면

**Files:** Create `lib/community/screens/feed_screen.dart`

**Interfaces:** `class FeedScreen extends StatelessWidget { FeedScreen({required AuthService auth, PostRepository? posts}) }`. Consumes `PostRepository`(T4), `CreatePostScreen`(T7).

- [ ] **Step 1: 구현** — `lib/community/screens/feed_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../post_repository.dart';
import '../auth_service.dart';
import '../models/post.dart';
import 'create_post_screen.dart';

/// 최신순 게시물 피드. 로그인 게이트 뒤에서 진입.
class FeedScreen extends StatelessWidget {
  final AuthService auth;
  final PostRepository posts;
  FeedScreen({super.key, required this.auth, PostRepository? posts})
    : posts = posts ?? PostRepository();

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('커뮤니티')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatePostScreen(auth: auth, posts: posts),
          ),
        ),
        child: const Icon(Icons.add_a_photo),
      ),
      body: StreamBuilder<List<Post>>(
        stream: posts.feed(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('불러오지 못했어요'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('아직 게시물이 없어요. 첫 사진을 올려보세요!'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _PostCard(post: items[i], posts: posts, uid: uid),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final PostRepository posts;
  final String uid;
  const _PostCard({required this.post, required this.posts, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              post.authorName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: Image.network(post.imageUrl, fit: BoxFit.cover),
          ),
          Padding(padding: const EdgeInsets.all(12), child: Text(post.caption)),
          Row(
            children: [
              StreamBuilder<bool>(
                stream: posts.likedByMe(postId: post.id, uid: uid),
                builder: (_, s) {
                  final liked = s.data ?? false;
                  return IconButton(
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.red : null,
                    ),
                    onPressed: uid.isEmpty
                        ? null
                        : () => posts.toggleLike(postId: post.id, uid: uid),
                  );
                },
              ),
              Text('${post.likeCount}'),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
    );
  }
}
```
- [ ] **Step 2:** 이 파일은 아직 없는 `create_post_screen.dart`를 import하므로 단독 분석은 에러가 정상. 파일만 작성하고 커밋(다음 태스크에서 함께 분석 통과).
- [ ] **Step 3:**
```bash
git add lib/community/screens/feed_screen.dart
git commit -m "feat: 커뮤니티 피드 화면"
```

---

### Task 7: 작성 화면 + 커뮤니티 진입 버튼

**Files:** Create `lib/community/screens/create_post_screen.dart`, Modify `lib/screens/camera_screen.dart`

**Interfaces:** `class CreatePostScreen extends StatefulWidget { CreatePostScreen({required AuthService auth, required PostRepository posts}) }`. Consumes `PostRepository`(T4), `UserRepository.getProfile`(T3), `showSignInSheet`/`AuthService`(기존).

- [ ] **Step 1: 작성 화면** — `lib/community/screens/create_post_screen.dart`:
```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth_service.dart';
import '../post_repository.dart';
import '../user_repository.dart';

/// 사진 선택 → 캡션 → 업로드. (가림 편집 단계는 계획 C에서 삽입)
class CreatePostScreen extends StatefulWidget {
  final AuthService auth;
  final PostRepository posts;
  const CreatePostScreen({super.key, required this.auth, required this.posts});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final _users = UserRepository();
  File? _image;
  bool _uploading = false;

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _submit() async {
    final image = _image;
    final uid = widget.auth.currentUser?.uid;
    if (image == null || uid == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final profile = await _users.getProfile(uid);
      await widget.posts.createPost(
        uid: uid,
        authorName: profile?.nickname ?? '익명',
        image: image,
        caption: _caption.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('업로드에 실패했어요')));
      }
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 올리기'),
        actions: [
          TextButton(
            onPressed: (_image != null && !_uploading) ? _submit : null,
            child: const Text('올리기'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pick,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                  image: _image != null
                      ? DecorationImage(
                          image: FileImage(_image!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _image == null
                    ? const Center(
                        child: Icon(Icons.add_photo_alternate, size: 48),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            maxLength: 140,
            decoration: const InputDecoration(
              hintText: '한 줄 팁을 남겨보세요',
              border: OutlineInputBorder(),
            ),
          ),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
```
- [ ] **Step 2: 카메라 화면 진입 버튼** — `lib/screens/camera_screen.dart` import에 추가:
```dart
import '../community/screens/feed_screen.dart';
```
build의 `if (_camera.canSwitch)` Positioned **다음에** 커뮤니티 버튼 Positioned 추가:
```dart
            Positioned(
              top: 44,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.people, color: Colors.white, size: 30),
                onPressed: () async {
                  if (!_auth.isSignedIn) {
                    final ok = await showSignInSheet(context, _auth);
                    if (!ok) return;
                  }
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FeedScreen(auth: _auth)),
                  );
                },
              ),
            ),
```
- [ ] **Step 3:** `dart analyze lib test` → No issues found!
- [ ] **Step 4:**
```bash
git add lib/community/screens/create_post_screen.dart lib/screens/camera_screen.dart
git commit -m "feat: 게시물 작성 화면 + 커뮤니티 진입 버튼"
```

---

### Task 8: 최종 검증

- [ ] **Step 1:** `export PATH="/Users/soonbok/flutter/bin:$PATH" && tool/verify.sh` → `✅ verify 통과`.
- [ ] **Step 2:** `cd functions && npx vitest run` → 전부 PASS.
- [ ] **Step 3: 기기 수동 검증 (사람)** — Task 0(Storage) + 규칙/함수 배포 후 `flutter run`:
  - 커뮤니티(사람 아이콘) → 로그인 → 피드(빈 문구).
  - + → 갤러리 사진 + 캡션 → 올리기 → 피드 표시.
  - 하트 토글 → likeCount 증감(함수 반영).

---

## Self-Review (작성자 확인)
- **스펙 커버리지(B):** Post=T2, 업로드/피드/좋아요=T4, likeCount 함수=T5, 규칙(posts/likes/storage)=T5, 피드=T6, 작성+진입=T7, 닉네임 조회=T3, 의존성=T1, Storage=T0.
- **플레이스홀더:** 코드·테스트 실제 내용 포함. T6이 T7(create_post) 의존함을 명시.
- **타입 일관성:** `Post`, `PostRepository.{createPost,feed,toggleLike,likedByMe}`, `UserRepository.getProfile`, `likeDelta`, `FeedScreen({auth,posts})`, `CreatePostScreen({auth,posts})` — 태스크 간 일치.
- **주의:** firebase_storage/image_picker 버전은 solver 결과대로. 규칙/함수 배포는 사람. 업로드는 아직 가림 없음(C에서 추가).
