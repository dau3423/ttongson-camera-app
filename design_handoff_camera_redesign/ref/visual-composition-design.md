# 똥손카메라 — 시각 구도 가이드 기획서 (Visual Composition Guide)

- **작성일**: 2026-07-05
- **문서 유형**: 개발 기획서 (구현용)
- **상태**: 설계 확정, 구현 계획 수립 전
- **선행**: Phase 2 클라우드 구도 추천 완료 (`docs/superpowers/specs/2026-07-03-ttongson-camera-phase2-cloud-advisor-design.md`). 이 문서는 Phase 2를 **텍스트 카드 → 시각 가이드**로 확장한다.

---

## 1. 개요

### 1.1 한 줄 정의
클라우드 구도 추천을 **글자 카드**로만 보여주던 것을, AI가 돌려준 **목표 위치(인물이 들어갈 박스)**를 프리뷰 위에 **고스트 박스 + 이동 화살표**로 그리고, Phase 1 실시간 인물 감지로 **정렬되면 녹색 피드백**을 주며, **미니맵**으로 "지금 여기 → 여기로"를 한눈에 보여주는 기능.

### 1.2 문제 정의
- 현재 추천은 "인물을 오른쪽 3분할선으로" 같은 **텍스트**라, 사용자가 그게 화면상 어디인지 감을 잡기 어렵다.
- "어디에 놓아야 하는지"와 "카메라를 어디로 옮겨야 하는지"를 **그림으로** 보여주면 훨씬 직관적이다.

### 1.3 핵심 가치
> 추천을 **읽는** 대신 **보고 맞춘다** — 목표 박스에 인물을 넣으면 녹색이 되는 즉각적 시각 피드백.

---

## 2. 데이터 계약 변경 (구조화 출력)

`CompositionAdvice`에 **목표 박스**를 추가하고 `directions`(텍스트 이동 지시)를 **제거**한다. 이동 안내는 온디바이스에서 실시간 계산한 화살표가 더 정확·반응적이므로 AI가 줄 필요가 없다.

### 2.1 새 계약 (앱·백엔드 동일)
```
CompositionAdvice {
  headline: String                      // 한 줄 요약 (유지)
  targetBox: { x, y, width, height }     // 인물이 들어갈 목표 영역, 정규화 0~1, 원점 좌상단 (신규)
  rationale: String                     // 이유 (유지)
}
```
- `targetBox`의 x,y,width,height는 모두 0.0~1.0. (x,y)=좌상단, 원점 좌상단(Phase 1 규약과 동일).
- `directions` 필드 삭제 — 앱·백엔드 모델과 파서에서 제거.

### 2.2 백엔드 json_schema (개념)
```json
{
  "type": "object",
  "properties": {
    "headline":  { "type": "string" },
    "targetBox": {
      "type": "object",
      "properties": {
        "x": { "type": "number" }, "y": { "type": "number" },
        "width": { "type": "number" }, "height": { "type": "number" }
      },
      "required": ["x", "y", "width", "height"],
      "additionalProperties": false
    },
    "rationale": { "type": "string" }
  },
  "required": ["headline", "targetBox", "rationale"],
  "additionalProperties": false
}
```
- 프롬프트: "현재 인물 위치를 고려해 **더 나은 목표 위치**를 정한다. 가능하면 3분할선/교차점에 맞추고, 인물 전체가 프레임에 담기도록 목표 박스를 정규화 좌표로 반환한다." 한국어 headline·rationale 유지.
- 온디바이스 지표(`metrics.personCenterX/Y`, `hasPerson`)는 이미 전송 중 → 현재 위치 컨텍스트로 활용.

---

## 3. 라이브 타겟 오버레이 (주 경험)

추천 수신 후 프리뷰 위에 그린다:
- **목표 고스트 박스**: `targetBox`를 화면 좌표로 변환한 반투명 사각형. 화면 고정.
- **이동 화살표**: 현재 인물 박스(Phase 1 `GuideMetrics.person`) 중심 → 목표 박스 중심 방향. 가까워질수록 짧아진다. 현재 인물이 없으면(감지 실패) 화살표 생략.
- **정렬 피드백**: 정렬 점수가 임계값을 넘으면 고스트 박스가 **빨강→녹색**으로 바뀌고 "좋아요" 표기.
- 화면 고정이므로 사용자가 카메라를 움직이든 인물이 움직이든 실제 인물이 목표 영역에 들어오게 맞추면 된다.
- 목표는 **요청 시점 기준 고정**. 장면이 크게 바뀌면 다시 요청해 새 목표를 받는다.
- 색 규약: 좋음=녹색(0xAA69F0AE), 주의/미정렬=빨강(0xAAFF5252), 중립=흰색 반투명 — Phase 1과 일치.

---

## 4. 미니맵 (보조 예시)

화면 모서리의 작은 개요도:
- **프레임 사각형** + **현재 인물**(실시간, 회색) + **목표 박스**(녹색 외곽) + 둘을 잇는 화살표.
- 라이브 인물 감지로 실시간 갱신, 정렬되면 목표 박스가 채워진 녹색으로.
- 목적: 전체 프레임 대비 "지금 → 목표"를 한눈에.

---

## 5. 텍스트 카드 (축소)

기존 `AdviceOverlay`는 **headline + rationale만** 작게 유지(닫기 가능). `directions` 렌더 제거. 시각 요소가 주, 텍스트는 맥락 보조.

---

## 6. 정렬 판정 로직 (순수 함수, TDD)

판단 로직은 순수 함수로 분리해 Phase 1처럼 단위 테스트한다.

- `TargetBox { double x, y, width, height }` — 정규화 값 객체. getter `centerX`, `centerY`, `right`, `bottom`.
- `AlignmentResult { double score; bool aligned; double dx; double dy; }`
  - `score`: 0~1 (높을수록 정렬). `aligned`: score ≥ 임계값.
  - `dx = target.centerX − current.centerX`, `dy = target.centerY − current.centerY` (화살표 방향).
- `AlignmentResult computeAlignment(PersonBox current, TargetBox target, {double alignThreshold = 0.6})`
  - score = 두 박스의 IoU(교집합/합집합). 겹침이 클수록 1에 근접.
  - aligned = score ≥ alignThreshold.
- 전부 정규화 좌표·순수 계산 → tilt/thirds처럼 TDD.

---

## 7. 모듈 구성 & 데이터 흐름

### 7.1 백엔드 (재배포 필요)
- `functions/src/schema.ts`: `COMPOSITION_SCHEMA`에 `targetBox` 추가, 프롬프트에 목표 박스 지시 추가. (directions 관련 제거)
- `functions/src/advice.ts`: `CompositionAdvice`/`parseAdvice`에 `targetBox` 추가·검증(필드 존재·number), `directions`·`AdviceDirection` 제거.
- `functions/test/advice.test.ts`: targetBox 파싱/검증 케이스로 갱신.

### 7.2 앱
| 파일 | 역할 |
|---|---|
| `lib/cloud/composition_advice.dart` | `TargetBox` 추가, `directions`/`AdviceDirection`/`AdviceAxis` 제거. `fromJson`에 targetBox(누락 시 안전 기본) |
| `lib/cloud/target_alignment.dart` (신규, 순수) | `AlignmentResult`, `computeAlignment()` — **TDD** |
| `lib/cloud/target_guide_overlay.dart` (신규, CustomPainter) | 목표 고스트 박스(정렬 시 녹색) + 이동 화살표 |
| `lib/cloud/advice_minimap.dart` (신규, CustomPainter/위젯) | 프레임+현재+목표+화살표 개요도 |
| `lib/cloud/advice_overlay.dart` | headline+rationale만 남기고 축소(directions 렌더 제거) |
| `lib/screens/camera_screen.dart` | 추천 수신 시 targetBox 저장 → 매 프레임 `_metrics.person`으로 `computeAlignment` → 오버레이·미니맵 갱신. 닫기/재요청 시 초기화 |

### 7.3 데이터 흐름
1. 사용자 트리거 → `CloudAdvisor.suggest` → AI가 `targetBox` 포함 `CompositionAdvice` 반환.
2. `camera_screen`이 `_advice` 저장, `TargetGuideOverlay`·`AdviceMinimap`·축소 카드 표시.
3. 매 프레임: Phase 1 인물 감지(`_metrics.person`) → `computeAlignment(current, targetBox)` → 화살표·정렬색 갱신.
4. 닫기 또는 재요청 시 목표 초기화/교체.

---

## 8. 비기능 요구사항

- **성능**: 정렬 계산은 프레임당 O(1) 순수 계산 — 실시간 부담 없음. 오버레이는 CustomPaint(Phase 1과 동일).
- **견고성**: 인물 미감지 시 화살표·정렬 피드백 생략(고스트 박스·미니맵 목표는 계속 표시). `targetBox` 누락/이상 값이면 방어적 파싱으로 시각 요소 생략하고 카드만 표시.
- **일관성**: 좌표 정규화 0~1·원점 좌상단, 색 규약(녹=좋음/빨=주의) Phase 1과 동일.
- **프라이버시/네트워크**: Phase 2와 동일 — 클라우드는 추천 요청 시 1회. 시각 가이드는 그 결과를 온디바이스에서 그릴 뿐 추가 네트워크 없음.

---

## 9. 범위 밖 (Out of Scope)

- 인물 실루엣(포즈 형태) 렌더 — 이번엔 사각형 목표 박스까지. 실루엣은 후속.
- 다중 인물 각각의 목표 배치.
- 목표 박스의 실시간 재계산(장면 변화 추적) — 목표는 요청 시점 고정, 변화 크면 재요청.
- 배경/수평선 등 인물 외 구도 요소의 시각 타겟.
- 3D 각도(피치) 목표의 그래픽 표현 — 각도 안내는 Phase 1 텍스트 유지.

---

## 10. 리스크 및 대응

| 리스크 | 대응 |
|---|---|
| AI가 비현실적/범위 밖 목표 박스 반환 | 파싱 시 0~1 클램프, 이상하면 시각 요소 생략+카드만 |
| 목표 박스가 화면 종횡비와 안 맞아 어긋나 보임 | 프리뷰 실제 rect/종횡비에 맞춰 좌표 매핑(기기 검증 항목) |
| 인물 감지 불안정으로 화살표 흔들림 | 감지 없을 때 화살표 숨김, 필요 시 경미한 평활화(후속) |
| 계약 변경(directions 제거)이 기존 코드 파손 | 백엔드+앱 동시 변경, 테스트 갱신, 재배포를 한 계획에 묶음 |

---

## 11. 성공 지표

- 추천 후 사용자가 **목표 박스에 인물을 정렬(녹색)**시키는 성공률.
- "시각 가이드가 텍스트보다 이해하기 쉽다"는 정성 피드백.
- 정렬까지 걸린 조작 횟수/시간 감소.

---

## 12. 완료 정의

추천 요청 시 프리뷰에 목표 고스트 박스·이동 화살표·미니맵이 뜨고, 실제 인물을 목표에 맞추면 녹색으로 바뀐다. 순수 정렬 로직 + 백엔드 스키마 테스트 통과, `tool/verify.sh` 통과, 백엔드 재배포 후 실기기에서 동작 확인.
