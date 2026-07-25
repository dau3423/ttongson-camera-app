# 커뮤니티 다중 이미지(최대 10장) + 전체화면 뷰어 — 설계

작성일: 2026-07-25

## 목표

1. 커뮤니티 게시글에 **최대 10장**의 사진을 한 번에 등록할 수 있게 한다.
2. 커뮤니티에서 **이미지를 터치하면 전체화면**으로 보고, **핀치 제스처로 줌 인/아웃**·좌우 스와이프로 장 이동할 수 있게 한다.

## 결정 사항 (사용자 확정)

- **마스킹 흐름**: 자동 마스킹 + 선택 편집. 고른 사진 전부에 얼굴 자동 감지·모자이크를 일괄 적용해 그리드로 보여주고, 원하는 장만 탭해 마스크를 수정.
- **피드 표시**: 스와이프 캐러셀 + 점 인디케이터(인스타그램 방식).
- **하위호환**: 기존 단일 이미지(`imageUrl`) 게시글도 정상 표시.
- **뷰어**: Flutter 내장 `InteractiveViewer`+`PageView`로 무의존성 구현.

## 현재 상태 (조사 결과)

단일 이미지 파이프라인. 주요 지점:

- `lib/community/models/post.dart` — `final String imageUrl;`. `toCreateMap`/`fromData`가 단일 URL 가정.
- `lib/community/post_repository.dart` — `createPost({required File image, ...})`. Storage `post_images/{uid}/{postId}.jpg` 1개 업로드 → Firestore `imageUrl`.
- `lib/community/screens/create_post_screen.dart` — `File? _image`, `pickImage()`(단일), `MaskEditorScreen(image:)`로 마스크 편집 후 단일 미리보기.
- `lib/community/screens/mask_editor_screen.dart` — `final File image`. `_load`에서 얼굴 감지, `_done`에서 `applyMasks(image, regions)` → 마스킹본 1개 반환.
- `lib/community/mask_processor.dart` — `detectFaceRegions(File)`·`applyMasks(File, regions)` 순수/아이솔레이트 처리(둘 다 존재).
- `lib/community/screens/feed_screen.dart` — `_PostCard`에서 `Image.network(post.imageUrl)` 1장.
- `lib/community/screens/post_detail_screen.dart` — `Image.network(post.imageUrl)` 1장.
- `firestore.rules` — posts create 시 `imageUrl` 존재 가정. `storage.rules`는 `post_images/{uid}/{file}` 와일드카드라 다중 파일 이미 허용(파일당 <5MB, image/*).
- `image_picker: ^1.1.2` 존재. `pickMultiImage` 미사용.

## 아키텍처 (단위 분리)

### 1. Post 모델 (`lib/community/models/post.dart`)

- `imageUrl: String` → **`imageUrls: List<String>`** (항상 1~10, 비어있지 않음).
- `fromData`: `data['imageUrls']`가 List면 그것을 사용, 없으면 `data['imageUrl']`(String)을 `[url]`로 감싼다(둘 다 없으면 `['']` 방어). 순수 역직렬화.
- `toCreateMap({required List<String> imageUrls})`: `'imageUrls': imageUrls` **및** `'imageUrl': imageUrls.first`를 함께 기록(아직 업데이트 안 한 클라이언트 대비 레거시 필드).
- 커버 이미지 접근자 `String get coverUrl => imageUrls.first;`.

### 2. 저장소 (`lib/community/post_repository.dart`)

- `createPost({required List<File> images, ...})`로 시그니처 변경(1~10장).
- 각 이미지를 `post_images/{uid}/{postId}_{i}.jpg`(i=0..n-1)로 **순서대로** 업로드하여 URL 리스트 구성(순서 보존).
- Firestore 문서: `post.toCreateMap(imageUrls: urls)` + `createdAt`.
- 읽기/스트림은 `Post.fromData` 경유라 모델 변경만으로 다중 대응.

### 3. 자동 마스킹 (`lib/community/mask_processor.dart`)

- 추가: `Future<File> autoMaskFaces(File src)` — `detectFaceRegions(src)`로 얼굴 영역을 구해 전부 enabled로 `applyMasks(src, regions)` 적용, 마스킹본 File 반환. **얼굴이 없어도 `applyMasks(src, const [])`를 그대로 호출**(방향 정리·EXIF 제거를 일관되게 수행) → 항상 정제된 사본을 반환. UI 없음.
- 기존 `detectFaceRegions`/`applyMasks`는 그대로 재사용.

### 4. 작성 화면 (`lib/community/screens/create_post_screen.dart`)

- 상태: `List<_PickedImage> _images`(각 슬롯 `{File original; File masked;}`), `bool _masking`.
- **선택**: `ImagePicker().pickMultiImage()` → 최대 10장으로 제한(초과분은 앞에서 10장까지, "최대 10장" 스낵바). 이미 담긴 수 + 새로 고른 수가 10을 넘으면 여유분만 추가.
- **자동 마스킹**: 새로 추가된 각 원본에 `autoMaskFaces` 적용(진행 표시 `_masking`), 슬롯에 `{original, masked}` 저장.
- **그리드 미리보기**: 정사각 썸네일 그리드(마스킹본 표시). 각 썸네일에 삭제(×) 버튼. 썸네일 탭 → `MaskEditorScreen(image: slot.original)`로 열어 마스크 재편집 → 반환된 마스킹본으로 해당 슬롯 `masked` 교체. 그리드 끝에 10장 미만이면 "추가" 타일.
- **제출**: `_images`의 `masked` 리스트를 `createPost(images: [...])`로 업로드. 0장이면 제출 비활성.

### 5. 전체화면 뷰어 (신규 `lib/community/screens/image_viewer.dart`)

- `FullscreenImageViewer({required List<String> imageUrls, int initialIndex})` — 전체화면 라우트.
- 구성: `PageView`(좌우 스와이프) × 각 페이지 `InteractiveViewer`(minScale 1.0, maxScale 4.0)로 `Image.network`. 배경 검정.
- 더블탭 시 1x↔2x 토글 줌(TapDown 위치 기준). 상단 `현재/총장수` 텍스트 + 닫기(X) 버튼. 뒤로가기/닫기로 종료.
- 1장짜리 게시글도 동일 뷰어로 열리며 줌 동작(스와이프는 페이지 1개라 무동작).

### 6. 이미지 캐러셀 (신규 `lib/community/screens/post_image_carousel.dart`)

- `PostImageCarousel({required List<String> imageUrls})` StatefulWidget.
- 구성: 고정 `AspectRatio(1)` 안에 `PageView`(자체 `PageController`) + 하단 점 인디케이터(현재 페이지 강조). 장수 1이면 인디케이터 숨김.
- 이미지 탭 → `FullscreenImageViewer(imageUrls: imageUrls, initialIndex: 현재페이지)` push.
- 피드 카드(`_PostCard`)와 상세 화면이 공용으로 사용.

### 7. 피드/상세 반영

- `feed_screen.dart` `_PostCard`: `Image.network(post.imageUrl)` 자리를 `PostImageCarousel(imageUrls: post.imageUrls)`로 교체.
- `post_detail_screen.dart`: 단일 `Image.network`를 `PostImageCarousel(imageUrls: post.imageUrls)`로 교체.

### 8. 보안 규칙 (`firestore.rules`)

- posts create 조건에 `request.resource.data.imageUrls is list && request.resource.data.imageUrls.size() >= 1 && request.resource.data.imageUrls.size() <= 10` 추가. 기존 caption 길이 검증 유지. (storage.rules는 변경 없음.)

## 데이터 흐름 (신규 게시 → 열람)

1. FAB → 작성 화면 → `pickMultiImage`(≤10) → 각 원본 `autoMaskFaces` → 그리드(마스킹본).
2. (선택) 썸네일 탭 → `MaskEditorScreen(원본)` → 마스크 수정 → 슬롯 masked 교체.
3. 제출 → 마스킹본 N장을 `post_images/{uid}/{postId}_{i}.jpg`로 업로드 → `imageUrls`(+레거시 `imageUrl`) Firestore 기록.
4. 피드/상세 → `PostImageCarousel`가 `imageUrls`를 스와이프 캐러셀+점으로 표시.
5. 이미지 탭 → `FullscreenImageViewer`에서 핀치 줌·더블탭 줌·좌우 스와이프.

## 하위호환

- 기존 게시글은 Firestore에 `imageUrl`만 있음 → `Post.fromData`가 `[imageUrl]`로 감싸 1장 캐러셀로 정상 표시·뷰어 동작.
- 신규 게시글은 `imageUrls` + `imageUrl`(첫 장)을 함께 기록 → 아직 업데이트 안 한 앱도 첫 장은 표시.

## 테스트 전략

- **단위(순수)**: `Post.fromData` — (a) `imageUrls` 리스트 우선, (b) `imageUrls` 없으면 `imageUrl` 폴백, (c) 둘 다 없으면 빈 방어. `toCreateMap` — `imageUrls`와 `imageUrl`(=first) 동시 기록, 순서 보존. `coverUrl`=first.
- **기기 수동 검증**: 다중 선택·10장 제한, 자동 마스킹 결과, 썸네일 재편집/삭제/추가, 업로드 순서, 피드·상세 캐러셀·점, 전체화면 핀치/더블탭 줌·스와이프, 구 단일 게시글 표시.

## 완료 정의

- 최대 10장 선택·자동 마스킹·개별 편집/삭제/추가 후 게시 가능.
- 피드·상세에서 스와이프 캐러셀 + 점 인디케이터로 여러 장 표시.
- 이미지 탭 시 전체화면 뷰어에서 핀치·더블탭 줌 및 좌우 스와이프 동작.
- 기존 단일 이미지 게시글 정상 표시.
- `firestore.rules`가 `imageUrls` 1~10 검증.
- `tool/verify.sh`(format+analyze+test) 통과, 모델 단위 테스트 포함.

## 비목표 (YAGNI)

- 동영상/GIF, 이미지 재정렬(드래그) — 초기 범위 제외(추가 요청 시 별도).
- 업로드 병렬화·재시도 큐(순차 업로드로 충분).
- 캐러셀 자동재생, 확대 상태 공유 히어로 애니메이션.
- 기존 게시글의 `imageUrl`→`imageUrls` 데이터 마이그레이션(런타임 폴백으로 충분).
