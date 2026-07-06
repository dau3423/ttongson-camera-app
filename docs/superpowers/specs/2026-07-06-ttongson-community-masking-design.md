# 똥손카메라 — 커뮤니티 계획 C: 개인정보 가림 설계

> 상위 스펙 `2026-07-05-ttongson-community-design.md` §3(개인정보 가림)의 구현 결정을 확정하는 서브 스펙.
> 계획 B(게시·피드·좋아요)는 완료·병합됨. C는 B의 작성 흐름(선택→캡션→업로드)에 **가림 편집 단계**를 삽입한다.

## 1. 목표 / 원칙

- 가림은 **전부 기기에서** 수행하고 **가려진(재인코딩된) 이미지만** 업로드한다. 원본 바이트·EXIF는 서버로 나가지 않는다.
- 얼굴 자동 가림 + 수동 박스 가림. **모자이크(픽셀화)** 한 가지 방식만. (스티커는 후속 C2, YAGNI)
- 계산(순수 함수) ↔ 렌더/플러그인/이미지처리 분리. 순수 로직은 TDD.
- **네트워크 호출은 업로드 1회뿐**(감지·처리는 온디바이스).

## 2. 핵심 결정 (확정)

- **가림 방식**: 모자이크만. 영역별 방식 선택 없음.
- **업로드 게이트**: 편집 화면은 **항상** 거치되, **가림 영역 0개여도 업로드 허용**. 강제 가림 없음.
- **안전망**: 얼굴 감지 시 편집 진입 시점에 각 얼굴을 `enabled: true` 모자이크로 **기본 ON**. 사용자는 영역별 **토글로 OFF**(삭제와 별개) 또는 삭제 가능.
- **원본 미전송 보장**: 작성 흐름은 언제나 처리 파이프라인의 결과 File만 업로드한다. 가림이 없어도 파이프라인이 축소·JPEG 재인코딩하여 **EXIF/GPS를 제거**한다.
- **기본값**: 모자이크 강도 = 영역 긴 변 기준 약 **12블록**(최소 블록 크기 floor 적용). 처리 이미지 **최장변 상한 1600px**(업스케일 금지). JPEG 품질 ~85.
- **좌표 규약**: 모든 가림 좌표는 정규화 0.0~1.0, 원점 좌상단(CLAUDE.md 전역 규약과 동일).

## 3. 아키텍처 (접근 1: 순수 데이터 마스크 + 아이솔레이트 합성)

```
lib/community/
  models/mask_region.dart        # 순수 값 객체 (TDD)
  masking.dart                   # 순수 계산: 좌표 매핑·모자이크 블록·정규화·축소 치수 (TDD)
  mask_processor.dart            # 비순수: 얼굴 감지 + 아이솔레이트 픽셀 합성 (기기 검증)
  screens/
    mask_editor_screen.dart      # 가림 편집 UI (기기 검증)
    create_post_screen.dart      # (수정) 선택→[가림 편집]→캡션→업로드 조립
```

의존성: 추가 없음. `google_mlkit_face_detection`, `image`, `image_picker`, `firebase_storage` 모두 기존 존재.

## 4. 데이터 모델 — `MaskRegion` (순수)

값 객체. Flutter/plugin import 금지.

```
class MaskRegion {
  final double left, top, width, height;   // 정규화 0~1, 원점 좌상단
  final bool isAuto;                        // 얼굴 자동 감지 여부
  final bool enabled;                       // 처리 대상 여부 (enabled인 영역만 합성)
  const MaskRegion({left, top, width, height, isAuto=false, enabled=true});
  MaskRegion copyWith({bool? enabled});
  // == / hashCode
}
```

- 자동 얼굴: `isAuto: true, enabled: true`로 생성.
- 수동 박스: `isAuto: false, enabled: true`.
- OFF: `enabled: false`로 토글(리스트에서 유지, 재ON 가능). 삭제는 리스트에서 제거.

## 5. 순수 로직 — `masking.dart` (TDD)

- `IntRect pixelRect(MaskRegion r, int imgW, int imgH)` — 정규화 rect를 픽셀 rect로, 이미지 경계로 clamp(음수/초과 방지).
- `int mosaicBlockSize(int rectW, int rectH, {int targetBlocks = 12, int minBlock = 4})` — 영역 긴 변이 약 `targetBlocks`개 블록으로 픽셀화되도록 블록 크기 계산, `minBlock` floor 적용, 최소 1.
- `MaskRegion faceBoxToRegion(Rect pixelBox, int imgW, int imgH)` — 감지된 픽셀 박스를 정규화 `MaskRegion(isAuto: true)`로. 경계 clamp.
- `(int, int) fitDimensions(int w, int h, int maxLongSide)` — 최장변이 상한을 넘으면 비율 유지 축소, 이미 작으면 그대로(업스케일 금지). (계획 2의 advice_image 축소 로직과 동일 규약)

`IntRect`는 이 파일 내 간단한 순수 값 타입(l,t,w,h int)로 정의(dart:ui Rect 미사용 — 순수 유지).

## 6. 이미지 처리 — `mask_processor.dart` (비순수)

- `Future<List<MaskRegion>> detectFaceRegions(File src)`
  - `FaceDetector(FaceDetectorOptions(performanceMode: fast))`, `processImage(InputImage.fromFilePath(src.path))`.
  - 결과 이미지의 픽셀 크기 기준으로 각 face `boundingBox`를 `masking.faceBoxToRegion`으로 정규화.
  - 실패/미감지 시 빈 리스트 반환(비차단).
- `Future<File> applyMasks(File src, List<MaskRegion> regions)`
  - **아이솔레이트**(`Isolate.run` 또는 `compute`)에서 수행:
    1. `image` 패키지로 디코드, **EXIF 방향 반영(bake orientation)**.
    2. `masking.fitDimensions(w, h, 1600)`으로 축소.
    3. `enabled == true`인 각 영역: `pixelRect`로 픽셀 사각형을 구하고, `mosaicBlockSize`로 블록 크기 `b`를 정한 뒤 **영역 다운스케일→업스케일**로 픽셀화한다 — 해당 영역을 `ceil(rectW/b) × ceil(rectH/b)`로 축소(평균 샘플링) 후 nearest-neighbor로 원래 크기로 확대해 원본 영역에 덮어쓴다(상위 스펙 §3.4 규약과 동일).
    4. JPEG 재인코딩(품질 85), **EXIF 미포함**.
  - 임시 디렉토리에 `{uuid}.jpg`로 쓰고 File 반환. 호출측이 업로드 후 정리.
- **방향 일관성 주의**: 감지와 합성이 같은 방향 기준을 쓰도록, 좌표는 항상 "EXIF 방향 반영된 이미지" 픽셀 공간에서 다룬다. ML Kit `fromFilePath`가 EXIF를 반영하므로 합성 디코드도 동일하게 방향 반영한다.

## 7. 편집 화면 — `mask_editor_screen.dart`

- 진입 시 `detectFaceRegions(image)` 실행(로딩 스피너) → 감지 얼굴을 `enabled:true`로 상태에 채움.
- 사진을 `BoxFit.contain`으로 렌더, 그 위에 `CustomPainter`로 영역 오버레이(모자이크 예정 영역은 반투명 사각형 + 테두리; 선택 영역 강조; `enabled:false`는 흐리게).
- 제스처:
  - **드래그**: 새 수동 박스 생성(정규화 좌표로 저장).
  - **탭**: 영역 선택.
  - 선택 영역 **삭제** 버튼, 영역별 **enable 토글**.
- 위젯 좌표 ↔ 정규화 좌표 변환은 작은 순수 헬퍼(`normFromWidget`, `widgetFromNorm`; 레터박스 오프셋/스케일 보정)로 분리 — 순수라 단위 테스트 가능.
- **완료**: `applyMasks(image, regions)` 실행(진행 표시) → 처리된 File을 `Navigator.pop(file)`로 반환. 취소(뒤로가기): 편집 유지 후 사용자가 취소 시 null 반환.

## 8. 작성 흐름 통합 — `create_post_screen.dart` 수정

- 기존 `_pick()`(갤러리 선택) 후 곧바로 `MaskEditorScreen`를 push하고 처리된 File을 받아 `_image`로 삼는다.
  - 흐름: **선택 → MaskEditor(처리 File 반환) → 캡션 입력 → 올리기**.
  - MaskEditor가 null 반환(취소) 시 이미지 미설정 상태 유지.
- 업로드는 기존 `PostRepository.createPost(image: 처리된 File, ...)` 그대로 재사용. B의 닉네임 조회·에러 처리 변경 없음.

## 9. 에러 처리

- 얼굴 감지 실패 → 자동 영역 없이 편집 계속(짧은 토스트).
- `applyMasks` 실패 → 토스트 + 편집 화면 유지. **원본 업로드 금지**(create 흐름은 처리 File만 받음).
- 처리 결과가 5MB를 넘을 가능성은 축소(1600px)+품질85로 사실상 방지.

## 10. 테스트 전략

- **순수 TDD**:
  - `mask_region_test.dart` — 생성·동등성·`copyWith(enabled)`.
  - `masking_test.dart` — `pixelRect` clamp, `mosaicBlockSize`(targetBlocks/minBlock/긴 변 기준), `faceBoxToRegion` 정규화·clamp, `fitDimensions` 축소·업스케일 금지.
  - 좌표 변환 헬퍼 테스트(레터박스 보정).
- **비순수(감지·아이솔레이트·UI)**: 구현 + 기기 수동 검증. 억지 단위테스트 없음(프로젝트 규율).
- 게이트: 앱 `tool/verify.sh`, 정적분석 `dart analyze lib test`(`flutter analyze` 금지).

## 11. 범위 밖 (YAGNI)

- 스티커/이모지 가림(C2).
- 모자이크 강도 사용자 슬라이더(기본값 고정).
- 실시간(카메라 프리뷰) 가림 — C는 갤러리 선택 이미지 대상.
- 되돌리기(undo) 스택 — 영역 개별 삭제로 충분.

## 12. 완료 정의 (계획 C)

갤러리 선택 → 가림 편집 화면에서 얼굴 자동 가림(기본 ON, 토글 가능) + 수동 박스 추가/삭제 → 완료 시 온디바이스 모자이크·EXIF 제거된 JPEG 생성 → 캡션 → 업로드되어 피드에 가려진 이미지가 표시된다. 원본·위치정보는 업로드되지 않는다. `tool/verify.sh` 통과.
