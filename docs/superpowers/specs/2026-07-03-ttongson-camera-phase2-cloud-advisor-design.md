# 똥손카메라 Phase 2 — 클라우드 AI 구도 추천 기획서

- **작성일**: 2026-07-03
- **문서 유형**: 개발 기획서 (구현용)
- **상태**: 설계 확정, 구현 계획 수립 전
- **선행**: Phase 0+1 (온디바이스 실시간 가이드) 완료 — `docs/superpowers/specs/2026-07-02-ttongson-camera-design.md` 4.4절이 이 문서의 출발점.

---

## 1. 개요

### 1.1 한 줄 정의
사용자가 요청할 때(또는 카메라가 잠시 정지했을 때) **현재 화면 1장을 클라우드 AI(비전)에 보내 장면(인물·배경·위치)을 분석하고, "이렇게 찍으면 좋아요" 고급 구도 추천**을 자연어 + 방향 힌트로 돌려주는 기능.

### 1.2 Phase 1과의 관계
- Phase 1의 온디바이스 가이드(격자·수평·포즈·각도·줌)는 **매 프레임 실시간**, 네트워크 0회.
- Phase 2는 **온디맨드 1회** 클라우드 호출. 실시간 가이드를 대체하지 않고, 그 위에 "고급 추천"을 얹는다.
- 실패 시 조용히 온디바이스 가이드로 폴백 — 앱 흐름을 막지 않는다.

### 1.3 핵심 가치
> 규칙 기반 실시간 가이드로 부족한 **"장면 맥락을 이해한 구도 제안"**을, 사용자가 원할 때 한 번 받아본다.

---

## 2. 기술 스택

| 영역 | 선택 | 비고 |
|---|---|---|
| 앱 | Flutter (Phase 0+1과 동일) | 기존 `CameraService`/`GuideMetrics` 재사용 |
| 앱→백엔드 호출 | `cloud_functions` (Firebase callable) | URL 하드코딩 불필요, App Check 연동 |
| 남용 방지 | Firebase **App Check** | 정식 앱에서 온 호출만 허용 |
| 백엔드 | **Firebase Cloud Functions (2nd gen, TypeScript, Node)** | 키 보관·Claude 호출·레이트리밋 |
| AI | Anthropic **`claude-sonnet-4-6`** (vision) | 공식 `@anthropic-ai/sdk` |
| 출력 강제 | `output_config.format` (json_schema) | 구조화 JSON으로 파싱 안정화 |
| 키 보관 | Firebase **Secret Manager** (`ANTHROPIC_API_KEY`) | 앱/클라이언트에 키 노출 없음 |
| 이미지 인코딩 | JPEG, 긴 변 ~1080px | 토큰·대역폭 절감 |

> **하이브리드 원칙 유지:** 실시간 = 온디바이스, 고급 추천 = 클라우드. API 키는 앱에 절대 넣지 않는다(백엔드 프록시).

---

## 3. 아키텍처

```
[CameraScreen]
   │  '구도 추천' 버튼 탭  또는  카메라 2초 정지 자동 감지
   ▼
[CloudAdvisor (Dart)]
   │  현재 프레임 → JPEG(긴 변 ~1080px, base64) + 온디바이스 GuideMetrics 요약
   │  Firebase callable: advise(payload)          (App Check 토큰 자동 첨부)
   ▼
[Cloud Function: advise (TS)]
   │  App Check 검증 → 페이로드 검증 → Anthropic SDK 호출
   │    model=claude-sonnet-4-6, image(base64) + text 프롬프트,
   │    output_config.format = CompositionAdvice json_schema
   │  이미지 미보관(요청 처리 후 폐기)
   ▼
[CompositionAdvice JSON]
   ▼
[CloudAdvisor 파싱] → [AdviceOverlay: 카드(headline/rationale) + 방향 힌트]
```

### 3.1 모듈 (spec 모듈 4 = CloudAdvisor)

각 유닛은 단일 책임 + 명확한 인터페이스.

#### 앱: `CloudAdvisor` (Dart, `lib/cloud/cloud_advisor.dart`)
- **하는 일**: 프레임 인코딩(JPEG·다운사이즈·base64), 지표 요약 첨부, callable 호출, 응답을 `CompositionAdvice`로 파싱, 타임아웃/오류 처리.
- **인터페이스**:
  - `Future<CompositionAdvice> suggest(CameraImageOrFile frame, GuideMetrics metrics)`
  - 실패 시 `CloudAdviceException` throw (호출측이 폴백).
- **의존**: `cloud_functions`, 이미지 인코딩 유틸.
- **판단 로직 없음** — 서버가 판단, 이 유닛은 전송·파싱만.

#### 앱: `CompositionAdvice` 모델 (`lib/cloud/composition_advice.dart`, 순수 Dart)
- `headline: String`, `directions: List<AdviceDirection>`, `rationale: String`.
- `AdviceDirection { axis: AdviceAxis(move|tilt|zoom|angle), instruction: String }`.
- `fromJson`로 파싱, 필드 누락에 견고.

#### 앱: `AdviceOverlay` (`lib/cloud/advice_overlay.dart`)
- `CompositionAdvice`를 카드(headline + rationale) + 방향 힌트로 표시. 순수 표시.

#### 백엔드: `advise` Cloud Function (`functions/src/advise.ts`)
- **하는 일**: App Check 검증 → 입력 검증(이미지 크기·형식) → Anthropic 호출(structured output) → `CompositionAdvice` 반환. 레이트리밋·타임아웃·오류 매핑.
- **인터페이스(요청)**: `{ imageBase64: string, mediaType: "image/jpeg", metrics?: {...} }`
- **인터페이스(응답)**: `CompositionAdvice` (아래 스키마).
- **의존**: `@anthropic-ai/sdk`, Secret Manager(`ANTHROPIC_API_KEY`).

### 3.2 데이터 흐름
1. 사용자 트리거 → `CameraScreen`이 스트림 정지, 현재 프레임 확보.
2. `CloudAdvisor.suggest()`가 JPEG로 인코딩·다운사이즈 후 `metrics` 요약과 함께 callable 호출.
3. `advise` 함수가 App Check 검증 → Claude에 이미지+프롬프트 전송(구조화 출력) → JSON 반환.
4. 앱이 `CompositionAdvice` 파싱 → `AdviceOverlay` 표시.
5. 실패/타임아웃 → 폴백(온디바이스 가이드 유지), 사용자에겐 짧은 안내.

---

## 4. 데이터 계약 (구조화 출력)

Cloud Function이 Claude를 `output_config.format`의 `json_schema`로 강제한다. 스키마(개념):

```json
{
  "type": "object",
  "properties": {
    "headline":  { "type": "string" },
    "directions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "axis": { "type": "string", "enum": ["move", "tilt", "zoom", "angle"] },
          "instruction": { "type": "string" }
        },
        "required": ["axis", "instruction"],
        "additionalProperties": false
      }
    },
    "rationale": { "type": "string" }
  },
  "required": ["headline", "directions", "rationale"],
  "additionalProperties": false
}
```

- `headline`: 한 줄 핵심 추천(한국어). 예: "인물을 오른쪽 3분할선에 맞추고 살짝 낮은 각도로".
- `directions`: 실행 힌트 목록. `axis`로 앱이 아이콘/화살표를 매핑.
- `rationale`: 짧은 이유(선택 표시).
- 프롬프트는 **한국어 출력**, 간결·실행 가능하게 지시. 온디바이스 `metrics`(기울기·인물 위치)를 컨텍스트로 함께 전달해 중복·모순 감소.

---

## 5. 트리거 & UX

- **수동 트리거**: 하단 "구도 추천" 버튼.
- **자동 트리거(옵션)**: 카메라 2초 정지(움직임/센서 안정) 감지 시 1회. 과호출 방지를 위해 쿨다운(예: 10초) + 직전 호출과 장면 유사 시 스킵.
- **로딩**: 인디케이터 표시(호출 중 촬영 버튼은 유지).
- **결과**: `AdviceOverlay` 카드 + 방향 힌트. 닫기/다시 요청 가능.
- **실패**: 5초 타임아웃 또는 오류 → 조용히 온디바이스 가이드로 폴백, "추천을 못 받았어요, 다시 시도" 정도의 짧은 스낵바.
- **색·톤**: Phase 1 규약과 일관(녹색=좋음, 빨강=주의; 추천 카드는 중립 톤).

---

## 6. 프라이버시 (spec 7절 확장)

- **첫 사용 전 명시적 동의**: "구도 추천 시 현재 화면 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다." 동의 전에는 클라우드 기능 비활성.
- **서버 이미지 미보관**: 요청 처리 후 폐기(로그에 이미지 미기록).
- **전송 보안**: HTTPS(Firebase callable 기본).
- **오프라인 불변**: Phase 1 전 기능은 네트워크 0회 유지. 클라우드는 이 기능에서만.
- **최소 전송**: 프레임 다운사이즈, 불필요한 메타데이터 미포함.

---

## 7. 비기능 요구사항

- **지연**: 요청→응답 체감 목표 < 3초. 초과 시 폴백.
- **비용 보호**: 백엔드 레이트리밋(예: 사용자/기기당 분당 N회), App Check로 비정상 호출 차단.
- **견고성**: 타임아웃·재시도(1회)·오류 매핑; 어떤 실패도 앱을 멈추지 않음.
- **토큰 절감**: 이미지 긴 변 ~1080px JPEG, 프롬프트 간결화.
- **접근성**: 카드 텍스트 대비·크기 확보, 색 + 텍스트 병행.

---

## 8. 범위 밖 (Out of Scope)

- 실시간(매 프레임) 클라우드 분석 — 온디맨드 1회만.
- 사용자 계정/로그인, 추천 이력 저장·동기화.
- 다중 인물(2명+) 정밀 배치 최적화.
- 백엔드 A/B 프롬프트 실험 인프라.
- 오프라인 캐시된 AI 추천.

---

## 9. 리스크 및 대응

| 리스크 | 대응 |
|---|---|
| 클라우드 지연/실패로 UX 저하 | 온디맨드만·타임아웃·온디바이스 폴백·쿨다운 |
| 과금 폭주(자동 트리거·남용) | App Check + 백엔드 레이트리밋 + 자동 트리거 쿨다운/유사장면 스킵 |
| 프라이버시 우려(프레임 전송) | 명시적 동의·미보관·최소 전송·HTTPS |
| 구조화 출력 파싱 실패 | `output_config.format` 강제 + `fromJson` 방어적 파싱 + 폴백 |
| Firebase 초기 설정 복잡도 | Phase 2는 별도 plan에서 세팅 태스크를 앞단에 배치 |
| 온디바이스 지표와 추천 모순 | `metrics`를 컨텍스트로 전달, 프롬프트에서 일관성 지시 |

---

## 10. 성공 지표 (Phase 2)

- 구도 추천 요청→표시 성공률, 체감 지연 p50/p95.
- 추천 사용 시 사용자 만족도(정성).
- 폴백 발생률(낮을수록 좋음), 호출당 비용.

---

## 11. 구현 단계 (Phasing, plan에서 상세화)

| 단계 | 범위 |
|---|---|
| P2-A | Firebase 프로젝트·App Check·Secret 세팅, `advise` 함수 뼈대(헬스체크) |
| P2-B | `advise` 함수: Claude vision + structured output, 입력검증·레이트리밋 |
| P2-C | 앱 `CompositionAdvice`/`CloudAdvisor`(TDD 가능한 파싱·인코딩 로직 중심) |
| P2-D | `AdviceOverlay` + `CameraScreen` 트리거·로딩·폴백·동의 UX |

> 계산·파싱 등 순수 로직(예: `CompositionAdvice.fromJson`, 이미지 다운사이즈 계산)은 Phase 1과 동일하게 **TDD**. Firebase/카메라/네트워크 경계는 구현 + 기기/에뮬레이터 검증.
