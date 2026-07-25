# 커뮤니티 다중 이미지(최대 10장) + 전체화면 뷰어 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 커뮤니티 게시글을 최대 10장까지 등록하고(자동 마스킹+개별 편집), 피드·상세에서 스와이프 캐러셀로 보며, 이미지 탭 시 전체화면에서 핀치/더블탭 줌·스와이프로 감상한다.

**Architecture:** `Post.imageUrl`(String)을 `imageUrls`(List<String>)로 바꾸되 구 필드 폴백으로 하위호환. 저장소는 N장 순차 업로드. 작성 화면은 다중 선택 후 얼굴 자동 모자이크(기존 순수 함수 재사용)하고 그리드에서 개별 편집. 피드·상세는 공용 `PostImageCarousel`, 이미지 탭은 무의존성 `FullscreenImageViewer`(`PageView`×`InteractiveViewer`).

**Tech Stack:** Flutter(Dart), `image_picker`(pickMultiImage), Firebase Storage/Firestore, `google_mlkit_face_detection`(기존), `image`(기존), Flutter 내장 `InteractiveViewer`/`PageView`.

## Global Constraints

- `lib/community/models/post.dart`는 **순수 Dart(Flutter/plugin import 금지)** — 파일 상단 주석 규약 유지.
- 정적 분석 게이트: `dart analyze lib test` (`flutter analyze`는 한글 경로 크래시 — 사용 금지).
- 완료 게이트: `tool/verify.sh`(format + `dart analyze lib test` + `flutter test`).
- 커밋: Conventional Commits.
- 최대 이미지 수: **10장**. 초과 시 앞에서 10장까지만, "사진은 최대 10장까지 올릴 수 있어요" 안내.
- Storage 경로: `post_images/{uid}/{postId}_{i}.jpg` (i=0..n-1, 선택 순서 보존).
- Firestore 저장: `imageUrls`(정식) + `imageUrl`=첫 장(레거시 클라 호환) 병기.
- 하위호환: 구 게시글(`imageUrl`만 존재)도 1장 캐러셀로 정상 표시.
- 마스킹본은 `applyMasks` 산출물(방향 정리·EXIF 제거·≤1600px). 편집을 위해 슬롯마다 **원본+마스킹본** 보관.
- 기기 수동 검증 항목은 사람이 확인(플러그인·UI). Firestore 규칙 배포도 사람 몫.

---

### Task 1: Post 모델 다중 URL 마이그레이션 (하위호환) + 읽기 지점 정리

**Files:**
- Modify: `lib/community/models/post.dart`
- Modify: `lib/community/post_repository.dart` (생성 부분만)
- Modify: `lib/community/screens/feed_screen.dart` (이미지 참조 1곳)
- Modify: `lib/community/screens/post_detail_screen.dart` (이미지 참조 1곳)
- Test: `test/community/post_test.dart`

**Interfaces:**
- Consumes: `ShootingMode`/`ShootingModeWire`(기존).
- Produces:
  - `class Post` — `final List<String> imageUrls;`, 생성자 `required this.imageUrls`, `String get coverUrl`(첫 장 또는 '').
  - `Map<String, dynamic> toCreateMap({required List<String> imageUrls})` — `imageUrls`와 `imageUrl`(=first) 동시 기록.
  - `factory Post.fromData(String id, Map<String,dynamic> data)` — `imageUrls` 우선, 없으면 `imageUrl` 폴백.

- [ ] **Step 1: 실패 테스트 작성 (기존 테스트 갱신 + 하위호환 추가)**

`test/community/post_test.dart` 전체를 아래로 교체:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/models/post.dart';

void main() {
  test('toCreateMap: imageUrls와 레거시 imageUrl(첫 장) 병기, 순서 보존', () {
    const p = Post(
      id: '',
      authorUid: 'u1',
      authorName: '귀여운너구리1',
      imageUrls: ['https://x/0.jpg', 'https://x/1.jpg'],
      caption: '역광에서 살짝 밑에서',
    );
    final m = p.toCreateMap(
      imageUrls: ['https://x/0.jpg', 'https://x/1.jpg'],
    );
    expect(m['imageUrls'], ['https://x/0.jpg', 'https://x/1.jpg']);
    expect(m['imageUrl'], 'https://x/0.jpg'); // 레거시 = 첫 장
    expect(m['authorUid'], 'u1');
    expect(m['likeCount'], 0);
    expect(m['reportCount'], 0);
    expect(m['hidden'], false);
    expect(m.containsKey('createdAt'), isFalse);
  });

  test('coverUrl: 첫 장', () {
    const p = Post(
      id: 'p',
      authorUid: 'u',
      authorName: 'n',
      imageUrls: ['a', 'b', 'c'],
      caption: 'c',
    );
    expect(p.coverUrl, 'a');
  });

  test('fromData: imageUrls 리스트 우선', () {
    final p = Post.fromData('post9', {
      'authorUid': 'u2',
      'authorName': '느긋한수달2',
      'imageUrls': ['https://a/0.jpg', 'https://a/1.jpg'],
      'imageUrl': 'https://a/0.jpg',
      'caption': '가운데 정렬',
      'likeCount': 5,
      'commentCount': 2,
    });
    expect(p.imageUrls, ['https://a/0.jpg', 'https://a/1.jpg']);
    expect(p.coverUrl, 'https://a/0.jpg');
    expect(p.likeCount, 5);
    expect(p.commentCount, 2);
  });

  test('fromData: imageUrls 없으면 구 imageUrl 폴백(1장)', () {
    final p = Post.fromData('p', {
      'authorUid': 'u',
      'authorName': 'n',
      'imageUrl': 'https://a/b.jpg',
      'caption': 'c',
    });
    expect(p.imageUrls, ['https://a/b.jpg']);
    expect(p.coverUrl, 'https://a/b.jpg');
  });

  test('fromData: 둘 다 없으면 빈 리스트, coverUrl 빈 문자열', () {
    final p = Post.fromData('p', {
      'authorUid': 'u',
      'authorName': 'n',
      'caption': 'c',
    });
    expect(p.imageUrls, isEmpty);
    expect(p.coverUrl, '');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/community/post_test.dart`
Expected: FAIL (컴파일 에러 — `imageUrls`/`coverUrl` 미정의, `toCreateMap(imageUrls:)` 없음).

- [ ] **Step 3: 모델 구현**

`lib/community/models/post.dart` 전체를 아래로 교체:
```dart
// lib/community/models/post.dart
// 순수 Dart — Flutter/plugin import 금지.
import '../../models/shooting_mode.dart';

class Post {
  final String id;
  final String authorUid;
  final String authorName;
  final List<String> imageUrls;
  final String caption;
  final ShootingMode? mode; // 촬영 모드(인물/자연/사물). 과거 글은 null.
  final DateTime? createdAt;
  final int likeCount;
  final int commentCount;
  const Post({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.imageUrls,
    required this.caption,
    this.mode,
    this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  /// 피드 커버·레거시 필드용 첫 이미지. 비어 있으면 ''.
  String get coverUrl => imageUrls.isNotEmpty ? imageUrls.first : '';

  /// 생성 저장용 맵. createdAt은 저장소가 serverTimestamp로 넣으므로 제외.
  /// imageUrls(정식)와 imageUrl(=첫 장, 아직 업데이트 안 한 클라 호환)을 함께 기록.
  Map<String, dynamic> toCreateMap({required List<String> imageUrls}) => {
    'authorUid': authorUid,
    'authorName': authorName,
    'imageUrls': imageUrls,
    'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
    'caption': caption,
    'mode': mode?.wire,
    'likeCount': 0,
    'commentCount': 0,
    'reportCount': 0,
    'hidden': false,
  };

  factory Post.fromData(String id, Map<String, dynamic> data) {
    final raw = data['imageUrls'];
    final List<String> urls;
    if (raw is List) {
      urls = raw.whereType<String>().where((s) => s.isNotEmpty).toList();
    } else {
      final single = (data['imageUrl'] as String?) ?? '';
      urls = single.isEmpty ? const [] : [single];
    }
    return Post(
      id: id,
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      imageUrls: urls,
      caption: (data['caption'] as String?) ?? '',
      mode: ShootingModeWire.fromWire(data['mode'] as String?),
      createdAt: data['createdAt'] as DateTime?,
      likeCount: (data['likeCount'] as int?) ?? 0,
      commentCount: (data['commentCount'] as int?) ?? 0,
    );
  }
}
```

- [ ] **Step 4: 저장소 생성부 컴파일 픽스**

`lib/community/post_repository.dart`의 `createPost` 내부에서 `Post(...)` 생성과 `toCreateMap` 호출을 다중 필드로 맞춘다(시그니처는 이 태스크에선 단일 `File image` 유지 — 다중 업로드는 Task 2). 기존:
```dart
    final post = Post(
      id: postId,
      authorUid: uid,
      authorName: authorName,
      imageUrl: imageUrl,
      caption: caption,
      mode: mode,
    );
    await ref.set({
      ...post.toCreateMap(imageUrl: imageUrl),
      'createdAt': FieldValue.serverTimestamp(),
    });
```
→ 변경:
```dart
    final post = Post(
      id: postId,
      authorUid: uid,
      authorName: authorName,
      imageUrls: [imageUrl],
      caption: caption,
      mode: mode,
    );
    await ref.set({
      ...post.toCreateMap(imageUrls: [imageUrl]),
      'createdAt': FieldValue.serverTimestamp(),
    });
```

- [ ] **Step 5: 표시 지점 컴파일 픽스 (coverUrl)**

`lib/community/screens/feed_screen.dart`에서 `Image.network(post.imageUrl, fit: BoxFit.cover)` → `Image.network(post.coverUrl, fit: BoxFit.cover)`.
`lib/community/screens/post_detail_screen.dart`에서 `Image.network(post.imageUrl, fit: BoxFit.cover)` → `Image.network(post.coverUrl, fit: BoxFit.cover)`.
그리고 `grep -rn '\.imageUrl\b' lib/` 로 남은 `post.imageUrl` 참조가 없는지 확인(없어야 함).

- [ ] **Step 6: 테스트·분석 통과 확인**

Run: `flutter test test/community/post_test.dart && dart analyze lib test`
Expected: 5 tests PASS, `No issues found!`.

- [ ] **Step 7: 커밋**

```bash
git add lib/community/models/post.dart lib/community/post_repository.dart lib/community/screens/feed_screen.dart lib/community/screens/post_detail_screen.dart test/community/post_test.dart
git commit -m "feat: Post 다중 이미지 URL(imageUrls) 모델 마이그레이션 + 하위호환"
```

---

### Task 2: 저장소 다중 업로드

**Files:**
- Modify: `lib/community/post_repository.dart`
- Modify: `lib/community/screens/create_post_screen.dart` (호출부만 — 빌드 그린 유지)

**Interfaces:**
- Consumes: `Post`(Task 1), `toCreateMap({required List<String> imageUrls})`.
- Produces: `Future<Post> createPost({required String uid, required String authorName, required List<File> images, required String caption, ShootingMode? mode})` — N장 순차 업로드, `imageUrls` 저장.

- [ ] **Step 1: createPost 다중화**

`lib/community/post_repository.dart`의 `createPost`를 아래로 교체:
```dart
  /// 이미지 N장을 Storage에 순서대로 올리고 게시물 문서를 생성한다(1~10장).
  Future<Post> createPost({
    required String uid,
    required String authorName,
    required List<File> images,
    required String caption,
    ShootingMode? mode,
  }) async {
    final ref = _db.collection('posts').doc();
    final postId = ref.id;
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final storageRef = _storage.ref('post_images/$uid/${postId}_$i.jpg');
      await storageRef.putFile(
        images[i],
        SettableMetadata(contentType: 'image/jpeg'),
      );
      urls.add(await storageRef.getDownloadURL());
    }
    final post = Post(
      id: postId,
      authorUid: uid,
      authorName: authorName,
      imageUrls: urls,
      caption: caption,
      mode: mode,
    );
    await ref.set({
      ...post.toCreateMap(imageUrls: urls),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return post;
  }
```

- [ ] **Step 2: 호출부 임시 정합(빌드 그린)**

`lib/community/screens/create_post_screen.dart` `_submit`에서 `image: image,` → `images: [image],` 로 변경(작성 화면 다중 UI는 Task 4).

- [ ] **Step 3: 분석 + 기존 테스트**

Run: `dart analyze lib test && flutter test`
Expected: `No issues found!`, 전체 테스트 PASS(개수 불변).

- [ ] **Step 4: 커밋**

```bash
git add lib/community/post_repository.dart lib/community/screens/create_post_screen.dart
git commit -m "feat: 게시물 다중 이미지 순차 업로드(createPost images 리스트)"
```

---

### Task 3: 얼굴 자동 마스킹 함수

**Files:**
- Modify: `lib/community/mask_processor.dart`

**Interfaces:**
- Consumes: `detectFaceRegions(File)`, `applyMasks(File, List<MaskRegion>)`(기존).
- Produces: `Future<File> autoMaskFaces(File src)` — 얼굴 자동 감지 후 전부 모자이크한 마스킹본 반환.

- [ ] **Step 1: autoMaskFaces 추가**

`lib/community/mask_processor.dart` 끝(파일 하단, `_mosaic` 뒤)에 추가:
```dart

/// 얼굴을 자동 감지해 전부 모자이크한 마스킹본을 만든다(UI 없음).
/// detectFaceRegions는 감지 영역을 enabled=true로 돌려주므로 그대로 적용한다.
/// 얼굴이 없어도 applyMasks(빈 영역)로 방향 정리·EXIF 제거·축소된 사본을 반환한다.
Future<File> autoMaskFaces(File src) async {
  final regions = await detectFaceRegions(src);
  return applyMasks(src, regions);
}
```

- [ ] **Step 2: 감지 영역 enabled 기본값 확인**

Run: `grep -n "enabled" lib/community/masking.dart lib/community/models/mask_region.dart`
Expected: `faceBoxToRegion`(또는 `MaskRegion` 기본)이 `enabled: true`로 영역을 만든다는 것을 확인. 만약 기본이 false라면 `autoMaskFaces`에서 `regions.map((r) => r.copyWith(enabled: true)).toList()`(또는 동등)로 강제한 뒤 `applyMasks`에 넘긴다. (마스크 편집기가 얼굴을 기본 ON으로 모자이크하므로 통상 true.)

- [ ] **Step 3: 분석**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 4: 커밋**

```bash
git add lib/community/mask_processor.dart
git commit -m "feat: autoMaskFaces — 얼굴 자동 감지·모자이크(UI 없음)"
```

---

### Task 4: 작성 화면 다중 선택 + 자동 마스킹 + 그리드 편집

**Files:**
- Modify: `lib/community/screens/create_post_screen.dart`

**Interfaces:**
- Consumes: `autoMaskFaces(File)`(Task 3), `createPost({images: List<File>, ...})`(Task 2), `MaskEditorScreen(image: File)`(기존, 완료 시 `File` 반환/취소 시 null).
- Produces: 최대 10장 선택·자동 마스킹·개별 편집/삭제/추가 후 업로드하는 작성 화면.

- [ ] **Step 1: 상태·로직 교체**

`lib/community/screens/create_post_screen.dart`에서 `_CreatePostScreenState`의 필드와 `_pick`/`_submit`을 아래로 교체하고, 파일 상단에 슬롯 클래스를 추가한다.

상단(클래스 밖, `CreatePostScreen` 위)에 추가:
```dart
/// 작성 중 슬롯: 편집을 위해 원본을, 표시·업로드를 위해 마스킹본을 함께 보관.
class _PickedImage {
  final File original;
  File masked;
  _PickedImage({required this.original, required this.masked});
}
```

`_CreatePostScreenState` 필드 교체:
```dart
  final _caption = TextEditingController();
  final List<_PickedImage> _images = [];
  ShootingMode _mode = ShootingMode.person;
  bool _uploading = false;
  bool _masking = false;
  static const _maxImages = 10;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty || !mounted) return;
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      _snack('사진은 최대 10장까지 올릴 수 있어요');
      return;
    }
    var toAdd = picked;
    if (picked.length > remaining) {
      toAdd = picked.sublist(0, remaining);
      _snack('사진은 최대 10장까지 올릴 수 있어요');
    }
    setState(() => _masking = true);
    try {
      for (final x in toAdd) {
        final original = File(x.path);
        final masked = await autoMaskFaces(original);
        if (!mounted) return;
        setState(() {
          _images.add(_PickedImage(original: original, masked: masked));
        });
      }
    } finally {
      if (mounted) setState(() => _masking = false);
    }
  }

  Future<void> _editAt(int i) async {
    final masked = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => MaskEditorScreen(image: _images[i].original),
      ),
    );
    if (masked != null && mounted) {
      setState(() => _images[i].masked = masked);
    }
  }

  void _removeAt(int i) => setState(() => _images.removeAt(i));

  Future<void> _submit() async {
    final uid = widget.auth.currentUser?.uid;
    if (_images.isEmpty || uid == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final profile = await widget.auth.ensureMyProfile();
      await widget.posts.createPost(
        uid: uid,
        authorName: profile?.nickname ?? '익명',
        images: _images.map((e) => e.masked).toList(),
        caption: _caption.text.trim(),
        mode: _mode,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        _snack('업로드에 실패했어요');
      }
    }
  }
```

`autoMaskFaces` 사용을 위해 import 추가: `import '../mask_processor.dart';`.

- [ ] **Step 2: build 교체 (그리드 + 제출 조건)**

`build`의 AppBar `actions`의 활성 조건과 body의 단일 미리보기(GestureDetector→AspectRatio 블록)를 교체.

AppBar actions:
```dart
          actions: [
            TextButton(
              onPressed: (_images.isNotEmpty && !_uploading) ? _submit : null,
              child: const Text('올리기'),
            ),
          ],
```

body의 `ListView(...)` 첫 자식(단일 미리보기 `GestureDetector` 블록 전체)을 아래 그리드로 교체:
```dart
            // 선택한 사진 그리드(마스킹본 표시). 탭=마스크 재편집, ×=삭제, +=추가.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _editAt(i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _images[i].masked,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removeAt(i),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_images.length < _maxImages)
                  GestureDetector(
                    onTap: _masking ? null : _pick,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _masking
                          ? const Center(child: CircularProgressIndicator())
                          : const Center(
                              child: Icon(Icons.add_photo_alternate, size: 32),
                            ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_images.length}/$_maxImages · 얼굴은 자동으로 가려집니다. 사진을 탭해 수정할 수 있어요.',
              style: TextStyle(fontSize: 12, color: p.text.withValues(alpha: 0.6)),
            ),
```

(기존 `if (_uploading) ... CircularProgressIndicator` 블록은 그대로 둔다.)

- [ ] **Step 3: 분석**

Run: `dart analyze lib/community/screens/create_post_screen.dart`
Expected: `No issues found!` (미사용 import·`_image` 잔재 없어야 함 — 있으면 제거).

- [ ] **Step 4: 기기 수동 검증**

Run: `flutter run` → 커뮤니티 FAB → 사진 올리기.
Expected: 여러 장 선택(10장 초과 시 안내), 자동 모자이크된 썸네일 그리드, 썸네일 탭 시 마스크 편집기로 수정 반영, × 삭제, + 추가(10장에서 숨김), 올리기 성공.

- [ ] **Step 5: 커밋**

```bash
git add lib/community/screens/create_post_screen.dart
git commit -m "feat: 작성 화면 다중 선택(≤10)·자동 마스킹·그리드 편집"
```

---

### Task 5: 전체화면 이미지 뷰어

**Files:**
- Create: `lib/community/screens/image_viewer.dart`

**Interfaces:**
- Produces: `class FullscreenImageViewer extends StatefulWidget` — 생성자 `FullscreenImageViewer({Key? key, required List<String> imageUrls, int initialIndex = 0})`. 전체화면 라우트로 push해서 사용.

- [ ] **Step 1: 뷰어 구현**

`lib/community/screens/image_viewer.dart` 생성:
```dart
import 'package:flutter/material.dart';

/// 전체화면 이미지 뷰어 — 좌우 스와이프(PageView) + 핀치/더블탭 줌(InteractiveViewer).
class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _page = PageController(
    initialPage: widget.initialIndex,
  );
  late int _current = widget.initialIndex;
  final Map<int, TransformationController> _controllers = {};
  TapDownDetails? _lastDoubleTap;

  TransformationController _controllerFor(int i) =>
      _controllers.putIfAbsent(i, () => TransformationController());

  @override
  void dispose() {
    _page.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleDoubleTap(int i) {
    final c = _controllerFor(i);
    if (c.value != Matrix4.identity()) {
      c.value = Matrix4.identity();
      return;
    }
    final pos = _lastDoubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    c.value = Matrix4.identity()
      ..translate(-pos.dx * (scale - 1), -pos.dy * (scale - 1))
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: urls.length,
            itemBuilder: (context, i) => GestureDetector(
              onDoubleTapDown: (d) => _lastDoubleTap = d,
              onDoubleTap: () => _handleDoubleTap(i),
              child: InteractiveViewer(
                transformationController: _controllerFor(i),
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(urls[i], fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (urls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_current + 1}/${urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 분석**

Run: `dart analyze lib/community/screens/image_viewer.dart`
Expected: `No issues found!`

- [ ] **Step 3: 커밋**

```bash
git add lib/community/screens/image_viewer.dart
git commit -m "feat: 전체화면 이미지 뷰어(스와이프+핀치/더블탭 줌)"
```

---

### Task 6: 게시물 이미지 캐러셀 (피드·상세 공용)

**Files:**
- Create: `lib/community/screens/post_image_carousel.dart`

**Interfaces:**
- Consumes: `FullscreenImageViewer`(Task 5).
- Produces: `class PostImageCarousel extends StatefulWidget` — 생성자 `PostImageCarousel({Key? key, required List<String> imageUrls})`. 1:1 비율 스와이프 캐러셀 + 점 인디케이터, 탭 시 뷰어 push.

- [ ] **Step 1: 캐러셀 구현**

`lib/community/screens/post_image_carousel.dart` 생성:
```dart
import 'package:flutter/material.dart';
import 'image_viewer.dart';

/// 게시물 이미지 캐러셀(1:1) — 좌우 스와이프 + 하단 점 인디케이터.
/// 이미지 탭 시 전체화면 뷰어를 현재 인덱스로 연다. 피드·상세 공용.
class PostImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  const PostImageCarousel({super.key, required this.imageUrls});

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  final _page = PageController();
  int _current = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _openViewer(int i) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imageUrls: widget.imageUrls,
          initialIndex: i,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: urls.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _openViewer(i),
              child: Image.network(urls[i], fit: BoxFit.cover),
            ),
          ),
          if (urls.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < urls.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _current
                            ? Colors.white
                            : Colors.white54,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 분석**

Run: `dart analyze lib/community/screens/post_image_carousel.dart`
Expected: `No issues found!`

- [ ] **Step 3: 커밋**

```bash
git add lib/community/screens/post_image_carousel.dart
git commit -m "feat: 게시물 이미지 캐러셀(스와이프+점 인디케이터, 탭→뷰어)"
```

---

### Task 7: 피드·상세에 캐러셀 적용

**Files:**
- Modify: `lib/community/screens/feed_screen.dart`
- Modify: `lib/community/screens/post_detail_screen.dart`

**Interfaces:**
- Consumes: `PostImageCarousel`(Task 6), `Post.imageUrls`(Task 1).

- [ ] **Step 1: 피드 카드 교체**

`lib/community/screens/feed_screen.dart` 상단에 `import 'post_image_carousel.dart';` 추가. `_PostCard`의 이미지 블록:
```dart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(post.coverUrl, fit: BoxFit.cover),
              ),
            ),
          ),
```
→ 변경:
```dart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: PostImageCarousel(imageUrls: post.imageUrls),
            ),
          ),
```

- [ ] **Step 2: 상세 화면 교체**

`lib/community/screens/post_detail_screen.dart` 상단에 `import 'post_image_carousel.dart';` 추가. 이미지 블록:
```dart
                  AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(post.coverUrl, fit: BoxFit.cover),
                  ),
```
→ 변경:
```dart
                  PostImageCarousel(imageUrls: post.imageUrls),
```

- [ ] **Step 3: 분석**

Run: `dart analyze lib test`
Expected: `No issues found!` (미사용 import 없어야 함).

- [ ] **Step 4: 기기 수동 검증**

Run: `flutter run` → 피드/상세.
Expected: 여러 장 게시글이 스와이프 캐러셀+점으로 표시, 1장 게시글은 점 없이 1장, 이미지 탭 시 전체화면 뷰어에서 핀치/더블탭 줌·좌우 스와이프. 구 단일 게시글도 정상.

- [ ] **Step 5: 커밋**

```bash
git add lib/community/screens/feed_screen.dart lib/community/screens/post_detail_screen.dart
git commit -m "feat: 피드·상세에 이미지 캐러셀 적용"
```

---

### Task 8: Firestore 규칙 — imageUrls 검증

**Files:**
- Modify: `firestore.rules`

**Interfaces:**
- Consumes: 없음(규칙만).

- [ ] **Step 1: posts create 조건 추가**

`firestore.rules`의 `match /posts/{postId}`의 `allow create:` 조건에 아래 3줄을 추가(기존 `caption.size() <= 140` 유지):
```
                    && request.resource.data.imageUrls is list
                    && request.resource.data.imageUrls.size() >= 1
                    && request.resource.data.imageUrls.size() <= 10
```
결과 예:
```
      allow create: if request.auth != null
                    && request.resource.data.authorUid == request.auth.uid
                    && request.resource.data.likeCount == 0
                    && request.resource.data.commentCount == 0
                    && request.resource.data.reportCount == 0
                    && request.resource.data.hidden == false
                    && request.resource.data.caption.size() <= 140
                    && request.resource.data.imageUrls is list
                    && request.resource.data.imageUrls.size() >= 1
                    && request.resource.data.imageUrls.size() <= 10;
```

- [ ] **Step 2: 규칙 문법 확인 및 배포 안내**

Run: `grep -n "imageUrls" firestore.rules`
Expected: 3줄 확인. (실제 배포 `firebase deploy --only firestore:rules`는 **사람**이 수행 — 커밋 메시지·완료 보고에 명시.)

- [ ] **Step 3: 커밋**

```bash
git add firestore.rules
git commit -m "chore: Firestore 규칙 — posts imageUrls(1~10) 검증(배포는 수동)"
```

---

### Task 9: 전체 검증

**Files:** (없음 — 게이트만)

- [ ] **Step 1: 잔여 단일 참조 점검**

Run: `grep -rn 'post\.imageUrl\b\|imageUrl:' lib/`
Expected: `post.imageUrl` 읽기 없음. `toCreateMap`/Storage의 `imageUrl` 키 기록은 모델 내부(`post.dart`)에만 존재(레거시 필드) — 그 외 없음.

- [ ] **Step 2: 완료 게이트**

Run: `tool/verify.sh`
Expected: `✅ verify 통과` (format + `dart analyze lib test` + `flutter test` 전부 통과).

- [ ] **Step 3: 최종 기기 회귀**

Run: `flutter run`
Expected:
- 최대 10장 등록(자동 마스킹·개별 편집/삭제/추가) 후 게시.
- 피드·상세 캐러셀+점, 이미지 탭→전체화면 핀치/더블탭 줌·스와이프.
- 구 단일 게시글 정상 표시.

- [ ] **Step 4: 출시 전 사람 확인 항목 보고**

`firebase deploy --only firestore:rules` 배포 필요를 완료 보고에 명시.

---

## Self-Review 결과

- **스펙 커버리지**: 모델 마이그레이션+하위호환(T1) / 다중 업로드(T2) / 자동 마스킹(T3) / 작성 다중 UI(T4) / 전체화면 뷰어(T5) / 캐러셀(T6) / 피드·상세 적용(T7) / 규칙(T8) / 검증(T9). 스펙의 8개 아키텍처 항목·완료 정의 모두 대응.
- **플레이스홀더**: 없음(모든 코드 완전 기재). Task 3 Step 2는 조건부 대체 코드까지 명시.
- **타입 일관성**: `Post.imageUrls: List<String>`, `coverUrl`, `toCreateMap({required List<String> imageUrls})`, `createPost({required List<File> images, ...})`, `autoMaskFaces(File)→Future<File>`, `FullscreenImageViewer({required List<String> imageUrls, int initialIndex})`, `PostImageCarousel({required List<String> imageUrls})` — 태스크 전반 일치. Storage 경로 `post_images/{uid}/{postId}_{i}.jpg` 일관.
- **빌드 그린 순서**: T1이 읽기지점을 `coverUrl`로 정리해 컴파일 유지, T2가 시그니처 변경과 동시에 호출부 `[image]` 임시 정합, T4가 다중 UI로 마무리. 각 커밋 컴파일 가능.
