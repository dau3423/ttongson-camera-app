# 똥손카메라 — 순차 단계형 가이드 기획서

- **작성일**: 2026-07-05
- **문서 유형**: 개발 기획서 (구현용)
- **상태**: 설계 확정, 구현 계획 수립 전
- **선행**: 시각 구도 가이드(`targetBox`), 촬영 모드(인물/자연/사물) 완료.
  이 문서는 기존 "동시에 뜨는 여러 힌트" 방식을 **한 번에 하나씩 지시하는 단계형 가이드**로 바꾼다.

---

## 1. 개요

### 1.1 한 줄 정의
매 프레임 **가장 급한 문제 하나**만 크게 지시하고, 그것을 해결하면 다음 단계로 넘어가,
모두 맞으면 "**✓ 찍으세요!**"를 띄우는 순차 가이드.

### 1.2 문제 정의
현재 가이드는 격자·수평선·인물박스·3분할 링·머리공간·각도·줌 힌트가 **동시에** 뜬다.
사진을 잘 못 찍는 사용자(주 대상)는 이 중 **무엇을 먼저 해야 할지** 모른다. 또한:
- "무엇을 하라는 건지"가 불명확 — 링이 떠 있어도 "얼굴을 여기 두라"는 지시가 없다.
- 이동 방향이 상단 한국어 텍스트로만 떠서 읽어야 한다.
- 성공을 색(초록)만으로 표현해 의미 학습이 필요하다.

### 1.3 핵심 가치
> 지금 이 순간 **딱 하나의 행동**을 크고 분명하게. 따라 하다 보면 좋은 사진이 완성된다.

### 1.4 이 문서가 바꾸는 기존 규정
기존 스펙의 "**자연 = 수평·격자만, 감지 없음**"을 폐기하고,
"**자연 = 수평 + (주제 검출 시) 구도·거리 안내**"로 갱신한다. CLAUDE.md 규약도 이에 맞춘다.
네트워크 0회·온디바이스 원칙은 그대로 유지.

---

## 2. 단계 모델 (핵심 계약)

### 2.1 통합 우선순위
하나의 순수 함수 `computeCurrentStep(GuideMetrics)`가 아래 우선순위로 지표를 훑어
**활성(문제 있는) 첫 단계**를 반환한다. 활성 단계가 없으면 `ready`.

| 순위 | 단계(kind) | 활성 조건 | 근거 지표 |
|---|---|---|---|
| 1 | `level` (수평) | `tilt.isLevel == false` | `tilt` |
| 2 | `crop` (잘림) | `crop != null && crop.any` | `crop` |
| 3 | `distance` (거리/줌) | `zoom != null && zoom.hint` 비어있지 않음 | `zoom` |
| 4 | `position` (위치) | `thirds != null && thirds.hint != '좋아요'` | `thirds` |
| 5 | `headroom` (머리공간) | `headroom != null && headroom.hint` 비어있지 않음 | `headroom` |
| 6 | `angle` (각도) | `angle.hint` 비어있지 않음 | `angle` |
| — | `ready` (완료) | 위 어느 것도 활성 아님 | — |

- **없는 지표는 자동 skip**된다(null 이거나 hint가 빈 문자열). 모드 분기는 `AnalysisEngine`이
  지표를 채우거나 비우는 것으로 이미 끝나므로, **스텝 함수는 모드를 알 필요가 없다.**
- 각 단계의 화면 문구는 근거 지표의 기존 `hint` 문자열을 그대로 쓴다(예: `tilt.hint` = "왼쪽을 내리세요").
- `position` 단계는 문구 외에 **현재점→목표점** 좌표를 함께 반환해 화살표를 그린다(2.3).

### 2.2 모드별 결과 단계
위 우선순위 + 모드별 지표 유무의 조합으로 다음이 도출된다.

| 순위 | 인물 | 사물 | 자연 |
|---|---|---|---|
| 1 | 수평 | 수평 | 수평 |
| 2 | 잘림(얼굴) | 잘림(사물) | — |
| 3 | 거리(줌) | 거리(줌) | 거리(줌) |
| 4 | 얼굴 위치(화살표) | 사물 위치(화살표) | 주제 위치(화살표) |
| 5 | 머리공간 | — | — |
| 6 | 눈높이 각도 | 정면·수평 각도 | 앞뒤 기울기 |
| ✓ | 찍으세요! | 찍으세요! | 찍으세요! |

- **자연 모드에서 주제가 안 잡히면** `thirds`·`zoom`이 null → 위치/거리 단계가 skip되어
  "수평(+각도) 맞추면 찍으세요"로 자연스럽게 축소된다.

### 2.3 위치 단계의 화살표 데이터
`position` 단계는 현재 피사체점에서 목표(3분할 교차점)로 향하는 화살표가 핵심이다.
이를 위해 `ThirdsAlignment`에 **현재 좌표**를 추가한다.

```
ThirdsAlignment {
  double currentX, currentY;   // 신규: 입력으로 받은 피사체 중심(cx,cy)
  double targetX, targetY;     // 가장 가까운 3분할 교차점
  double distance, score;
  String hint;                 // '좋아요' | 방향 문자열
}
```

오버레이는 `(currentX,currentY) → (targetX,targetY)`를 정규화 좌표로 받아
프리뷰 박스 기준으로 마커·화살표·목표 링을 그린다.

---

## 3. 성공 신호 (시각 + 진동 + 소리)

| 시점 | 시각 | 진동(Haptic) | 소리(SystemSound) |
|---|---|---|---|
| 단계 하나 통과 | 해당 요소 초록 + ✓ | `HapticFeedback.mediumImpact` | `SystemSoundType.click` |
| 전부 통과(ready 진입) | 중앙 "✓ 찍으세요!" 배너 | `HapticFeedback.heavyImpact` | `SystemSoundType.alert` |

- 진동·소리는 Flutter 내장 `HapticFeedback`/`SystemSound`만 사용 — **새 패키지·에셋 없음**.
  더 풍부한 효과음이 필요하면 후속 작업에서 음원 에셋 + 오디오 패키지 추가(범위 밖).
- **발생 규칙**: 신호는 "단계가 실제로 전진했을 때"만 1회 울린다. 매 프레임 재발생을 막기 위해
  화면 상태로 **직전 단계 kind**를 들고 있다가, 현재 kind가 달라지고(또는 ready로 진입) 그
  변화가 "더 진전된 방향"일 때만 트리거한다. 뒤로 후퇴(피사체가 다시 틀어짐)는 무음.

---

## 4. 화면 구성 (정보 과다 해소)

- **항상 표시**: 격자(옅게), 수평선.
- **현재 단계만 크게**:
  - `position`: 현재 마커(●) + 화살표 + 목표 링(◯) + 한 줄 문구("얼굴을 여기로")
  - 그 외 단계: 상단 중앙 **한 줄 문구 1개**(+ 관련 요소 강조)
  - `ready`: 화면 중앙 "✓ 찍으세요!" 배너 + 촬영 버튼 강조
- 기존처럼 7개 힌트를 동시에 쌓는 표시는 **제거**한다.
- 인물 박스는 유지하되 현재 단계 색 규칙을 따른다(정렬/경고).

---

## 5. 아키텍처 (책임 분리 · TDD)

계산(순수) ↔ 렌더/플러그인 분리 원칙을 유지한다.

### 5.1 신규/변경 파일

| 파일 | 성격 | 변경 |
|---|---|---|
| `lib/analysis/guide_step.dart` | 순수 (신규, TDD) | `GuideStep` 모델 + `computeCurrentStep(GuideMetrics)`. **우선순위 판단 전부 여기.** |
| `lib/analysis/thirds.dart` | 순수 (변경, TDD) | `ThirdsAlignment`에 `currentX/currentY` 추가 |
| `lib/analysis/analysis_engine.dart` | 순수 (변경, TDD) | 자연 모드도 검출 지표(zoom·thirds) 채움. 사물/자연에 각도, 사물에 잘림 지표를 모드에 맞게 채움 |
| `lib/analysis/angle_zoom.dart` | 순수 (변경, TDD) | 각도 힌트를 모드(인물=눈높이 / 사물·자연=정면·수평)에 맞게 산출 |
| `lib/overlay/guide_overlay.dart` | 렌더 (변경) | 현재 단계 하나만 렌더(화살표·링·배너). 판단 없음 |
| `lib/screens/camera_screen.dart` | 조립 (변경) | 자연 모드에서도 객체 검출 실행. 단계 전진/완료 감지 → 진동·소리 |

### 5.2 `GuideStep` 모델(안)

```
enum GuideStepKind { level, crop, distance, position, headroom, angle, ready }

class GuideStep {
  final GuideStepKind kind;
  final String message;          // 화면 문구(빈 문자열이면 배너/아이콘만)
  final ThirdsAlignment? target; // position 단계에서만 채움(현재점·목표점 포함)
}
```

- `ready`의 `message`는 "찍으세요!"로 통일(기존 정렬 문자열 `'좋아요'` 관례와 유사하게 단일 상수).

### 5.3 데이터 흐름
```
frame → detector → PersonBox/ObjectBox
  → AnalysisEngine.buildMetrics(mode) → GuideMetrics
  → computeCurrentStep(metrics) → GuideStep        (순수)
  → GuideOverlay(step) 렌더 + CameraScreen 이 전 단계와 비교해 진동/소리
```

---

## 6. 테스트 계획

- **`guide_step_test.dart`** (신규): 우선순위(급한 것부터 선택), 각 단계 활성/해결 판정,
  없는 지표 skip, 모두 해결 시 `ready`, `position`에 target 좌표 포함.
- **`thirds_test.dart`** (보강): `currentX/currentY` 반환 검증.
- **`analysis_engine_test.dart` / `analysis_engine_mode_test.dart`** (보강): 자연 모드가 검출 시
  zoom·thirds를 채움, 사물의 잘림/각도, 자연·사물의 각도 문구.
- **`angle_zoom_test.dart`** (보강): 모드별 각도 문구.
- **오버레이·진동·소리·자연 검출**: 실기기 수동 검증(단위 테스트 무의미).

---

## 7. 범위 밖 (YAGNI)

- 커스텀 효과음/음원 에셋, 오디오 패키지.
- 단계 순서의 사용자 커스터마이즈.
- 클라우드 ✨ 추천 흐름 변경(그대로 유지).
- 가로(landscape) 방향 최적화(세로 기준으로 구현, 별도 검증).

---

## 8. 완료 정의

- 세 모드 모두 한 번에 한 단계씩 지시하고, 해결 시 진동·소리·초록✓, 전부 맞으면 "찍으세요!"가 뜬다.
- 자연 모드가 주제 검출로 위치·거리를 안내하고, 미검출 시 수평(+각도)만으로 축소된다.
- `computeCurrentStep`·`thirds`·엔진·각도 로직이 TDD로 커버된다.
- `tool/verify.sh` 통과.
