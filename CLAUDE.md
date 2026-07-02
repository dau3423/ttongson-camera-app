# 똥손카메라 (Butterfingers Camera)

사진을 잘 못 찍는 사람을 위해, 카메라 프리뷰에서 **실시간으로 구도·각도·줌·인물 배치를 가이드**하고 필요 시 **AI가 더 나은 구도를 추천**하는 촬영 보조 앱.

## 문서 (읽는 순서)

- 기획서(spec): `docs/superpowers/specs/2026-07-02-ttongson-camera-design.md`
- 구현 계획(plan): `docs/superpowers/plans/2026-07-02-ttongson-camera-phase0-1.md`
- 실행 루프: `docs/LOOP.md`

새 작업은 항상 **plan의 태스크 번호 기준**으로 진행한다.

## 스택

- **Flutter (Dart)**, null-safety. 패키지명 `ttongson_camera`.
- `camera`(프리뷰/프레임 스트림), `sensors_plus`(기울기), `google_ml_kit`(pose/face), `path_provider`, `gallery_saver`.
- Flutter SDK: `/Users/soonbok/flutter/bin` (flutter/dart 모두 PATH에 존재).

## 구조 (책임 분리)

```
lib/
  models/person_box.dart        # 정규화 bbox 값 객체
  analysis/                     # 계산부 — 순수 Dart, plugin import 금지, TDD 대상
    tilt.dart thirds.dart headroom.dart crop.dart angle_zoom.dart
    guide_metrics.dart          # 집계 모델
    person_detector.dart        # 인터페이스 + ML Kit 구현 (플러그인 의존)
    analysis_engine.dart        # 조립 (순수)
  camera/camera_service.dart    # 카메라 래퍼 (플러그인 의존)
  overlay/guide_overlay.dart    # CustomPainter 렌더 (판단 없음)
  screens/camera_screen.dart    # 전체 조립
```

**핵심 원칙: 계산(순수 함수) ↔ 렌더/플러그인을 분리한다.** 판단 로직은 전부 `analysis/`의 순수 함수로 두고 TDD한다. 렌더러·플러그인 래퍼에는 판단 로직을 넣지 않는다.

## 규약 (Global Constraints)

- 좌표계: 모든 인물/포인트 좌표는 **정규화 0.0~1.0**, 원점 **좌상단**(x→오른쪽, y→아래).
- 각도 단위: **도(degree)**. 수평 허용오차 기본 **±1.5°**, 눈높이 허용오차 **±10°**.
- 머리 공간 적정 비율: **0.05~0.15**. 피사체 높이 적정 비율: **0.5~0.8**.
- `lib/analysis/` 중 `person_detector.dart`·`analysis_engine.dart`를 제외한 파일은 **Flutter/plugin import 금지**(순수 Dart).
- **Phase 0+1은 네트워크 호출 0회.** 모든 분석은 온디바이스.
- 정렬 판정 문자열은 `'좋아요'`로 통일(GuideMetrics·GuidePainter가 이 값으로 분기).

## 명령

```bash
tool/verify.sh          # format 검사 + analyze + test (완료 게이트)
flutter test            # 순수 로직 테스트
flutter test test/analysis/tilt_test.dart   # 단일 파일
dart format lib test    # 포맷
flutter run             # 실기기에서 앱 실행 (카메라/오버레이 수동 검증)
```

## 개발 규율

- **계산부(analysis/의 순수 함수): 엄격 TDD.** 실패 테스트 → 최소 구현 → 통과 → 커밋.
- **카메라/오버레이/플러그인: 구현 + 기기 수동 검증.** 단위 테스트가 무의미하므로 억지 테스트를 만들지 않는다.
- 태스크 하나 = 독립적으로 테스트 가능한 산출물 하나. 태스크 끝에 커밋.
- 커밋 메시지: Conventional Commits (`feat:`/`test:`/`chore:`).
- 완료를 주장하기 전 `tool/verify.sh`가 통과하는지 실제로 확인한다(증거 우선).

## 완료 정의 (Phase 0+1)

네트워크 없이: 프리뷰 위 격자·수평계 동작, 인물 박스·잘림 경고 표시, 머리공간/각도/줌 힌트 표시, 촬영→갤러리 저장. `tool/verify.sh` 통과.
