# 맞춤 포즈 추천 (실루엣 오버레이 + AI 추천) — 설계 (spec)

- 작성일: 2026-07-19
- 상태: 설계 합의 완료 (구현 계획 작성 전)
- 관련: 기존 AI 추천 인프라(`lib/cloud/`, `functions/src/`), 무드 보정과 별개 기능

## 1. 목적 / 한 줄 정의

카메라만 켜면 얼어붙는 사용자를 위해, 카테고리별 **포즈 실루엣을 반투명 오버레이**로 보여주고,
원하면 **AI가 현재 장면에 맞는 포즈를 추천**해 자동으로 얹어 주는 촬영 보조 기능.

- 실루엣 콘텐츠는 **OpenAI로 오프라인 생성**한 PNG를 앱에 번들(스크래핑/저작권 위험 회피 —
  OpenAI 생성물은 약관상 사용자 귀속).
- 오버레이는 촬영 가이드일 뿐 저장 사진에는 들어가지 않는다(Flutter 위젯 레이어).

## 2. 사용자 흐름

```
카메라 화면 → [포즈] 버튼
  → 포즈 피커(카테고리 탭: 셀카·전신·커플·우정 + 가로 썸네일)
      · 포즈 탭 → 반투명 실루엣이 프리뷰 위에 오버레이 → 따라 하기 → 촬영
      · [AI 추천] → (동의) 현재 프레임+후보목록 전송 → 어울리는 포즈 자동 오버레이 + 이유 안내
      · [숨기기] 토글로 오버레이 off
```

- 오버레이 상태에서 기존 셔터로 촬영(오버레이는 사진에 안 찍힘).

## 3. 콘텐츠 규모 (MVP)

4 카테고리 × 약 8개 ≈ **32 포즈**.

| category(키) | 라벨 | 예시 |
|---|---|---|
| `selfie` | 셀카 | 상반신, 한 팔 들어 폰 잡기, 턱 괴기 등 |
| `fullbody` | 전신 | 허리에 손, 무게중심 한쪽, 걷는 자세 등 |
| `couple` | 커플 | 나란히·어깨동무·마주보기 등 |
| `friends` | 우정 | 두세 명 나란히·점프·하이파이브 등 |

## 4. 콘텐츠 생성 파이프라인 (오프라인, 개발 시 1회)

- `tool/pose_manifest.json` — 32개 `{id, category, label, promptPose}`(생성용 포즈 영어 설명 포함).
- `tool/pose_gen.py` — 매니페스트를 읽어 각 포즈를 OpenAI 이미지(`gpt-image-1`, 세로,
  투명 배경)로 생성 → **후처리(투명 배경 보장/흰 배경 키잉, 여백 트림, 512×768 축소)** →
  `assets/poses/{category}/{id}.png` 저장. `OPENAI_API_KEY` 필요, Pillow로 후처리.
- 생성 스크립트가 앱용 매니페스트 `assets/poses/poses.json`(`[{id, category, label, asset}]`,
  `promptPose` 제외)도 함께 출력.
- **앱 런타임과 분리**: 사용자가 본인 키로 실행. 앱은 결과 PNG·poses.json만 번들.
- `pubspec.yaml`의 `flutter: assets:`에 `assets/poses/` 등록.
- 실루엣 스타일 고정 프롬프트(프로토타입 검증됨, `docs/pose-samples/openai_gen.py`):
  단일 인물·전신·단색 실루엣·얼굴/디테일/배경 없음·투명 배경.

## 5. 오버레이 (판단 없음, 렌더만)

- 생성 실루엣은 검정/투명 → 렌더 시 `ColorFilter.mode(accent, srcIn)`로 **앰버 틴트**,
  **불투명도 ~0.35**, 프리뷰 박스에 `BoxFit.contain` 중앙 정렬.
- 오버레이는 프리뷰 위 Flutter 위젯이라 `takePicture()` 센서 이미지에 포함되지 않음 → 저장 사진 깨끗.
- 숨기기 토글 제공.

## 6. AI 장면 맞춤 추천 (OpenAI)

- **변경점**: 이 기능의 추천 AI는 **OpenAI**를 쓴다(이미지 생성과 동일 제공자로 통일).
  기존 `advise`·`enhance`(무드 보정)는 Claude 그대로 유지 — 이번 변경은 새 포즈 기능에 한정.
- 서버 콜러블 `suggestPose`:
  - 입력: `imageBase64`, `mediaType`, `deviceId`, `candidates:[{id,label,category}]`.
    후보는 **전체 카탈로그(32개)**를 보낸다 — AI가 장면(인원수·구도)에 맞는 카테고리까지
    골라 추천할 수 있게 한다(예: 2명 감지 시 `couple` 포즈 선택).
  - **OpenAI Chat Completions + Structured Outputs(`response_format: json_schema`, 비전 입력)**.
    Structured Outputs는 비전 입력과 호환되며 GPT-5 계열에서 스키마 준수 신뢰도가 가장 높다.
  - 모델: **GPT-5 미니 급**(정확한 ID는 환경/상수 설정값, 예: `gpt-5-mini`).
  - 출력 스키마: `{ poseId: string, reason: string }`. `poseId`는 요청의 candidate id 집합을
    **enum으로 제약**해 항상 유효 값이 나오게 한다(Structured Outputs enum 지원).
  - 시크릿 `OPENAI_API_KEY`(생성 파이프라인과 동일 키), `openai` npm SDK 추가.
  - **App Check 강제·레이트리밋·auth guard·consent 게이트**는 기존 `advise` 패턴 재사용.
- 클라이언트 `pose_advisor.dart`: 다운사이즈 프레임 + 후보 목록 전송 → `poseId` 수신 →
  카탈로그에서 찾아 오버레이. 목록에 없으면 카테고리 첫 포즈 폴백.

## 7. 구조 (계산=순수 TDD, 렌더/IO/서버 분리)

| 파일 | 책임 | 검증 |
|---|---|---|
| `lib/poses/pose.dart` | **순수** — `Pose` 모델·`PoseCategory` enum·poses.json 파싱·카테고리 그룹핑·방어 파싱 | 엄격 TDD |
| `lib/poses/pose_catalog.dart` | rootBundle로 poses.json 로드(얇은 로더) | 기기 검증 |
| `lib/overlay/pose_overlay.dart` | 선택 포즈 실루엣 틴트·불투명 렌더 위젯 | 기기 검증 |
| `lib/poses/pose_advisor.dart` | `suggestPose` 호출·파싱·폴백(무효 poseId 처리) | 기기 검증 |
| `lib/poses/pose_picker.dart` | 카테고리 탭 + 썸네일 선택 UI | 기기 검증 |
| `functions/src/pose.ts` | 순수: candidate 검증·poseId enum 스키마 빌드·프롬프트·결과 파싱 | vitest |
| `functions/src/suggest_pose.ts` | onCall: OpenAI 호출(App Check·레이트리밋·auth) | 기기/배포 검증 |
| `functions/src/index.ts` | `suggestPose` export | — |
| `tool/pose_gen.py` + `tool/pose_manifest.json` | 오프라인 에셋 생성 | 수동 실행 |
| `lib/screens/camera_screen.dart` | '포즈' 버튼 → picker/overlay/AI추천 연결 | 기기 검증 |
| `pubspec.yaml` | `assets/poses/` 등록 | — |

## 8. 데이터 흐름

```
[포즈] → PoseCatalog.load(poses.json) → 카테고리별 그룹
  포즈 탭 → pose_overlay(선택 포즈 asset) → 프리뷰 위 오버레이
  [AI 추천] → consent → 다운사이즈 프레임 + candidates → suggestPose(OpenAI) → {poseId, reason}
            → 카탈로그에서 poseId 조회(없으면 폴백) → 오버레이 + reason 스낵바
  셔터 → 기존 촬영(오버레이 미포함)
```

## 9. 에러 처리

- AI 실패/오프라인/미동의 → 추천만 불가, **수동 선택·오버레이는 정상**(에셋 번들이라 오프라인 OK).
- `poseId` 무효 → 해당 카테고리 첫 포즈 폴백.
- poses.json 파싱 실패 → 포즈 기능 비활성 + 안내(앱 나머지는 정상).
- 에셋 이미지 로드 실패 → 그 포즈 오버레이 스킵 + 안내.

## 10. 테스트 전략

- `pose.dart`(순수): poses.json 파싱(누락/이상 타입 방어), 카테고리 그룹핑, 개수/무결성. TDD.
- `functions/src/pose.ts`(순수): candidate 검증, poseId enum 스키마 빌드, 결과 파싱(무효 id·비JSON throw). vitest.
- 나머지(로더·오버레이·picker·advisor·생성 스크립트·화면): 기기/수동 검증(단위 테스트 무의미).

## 11. 스토어 영향

- 이미지를 OpenAI로 전송(AI 추천)하므로 **개인정보 처리방침에 "OpenAI(제3자)"를 추가**해야 한다
  (현재 방침엔 Anthropic만 명시). 방침 문서 갱신 + 재배포 필요.
- 기능이 실기기 검증된 후에만 스토어 설명에 "맞춤 포즈 추천" 기재(허위광고 방지).

## 12. 범위 밖 (YAGNI / 후속)

- **AI 제공자 통일(후속 마이그레이션)**: `advise`(구도)·`enhance`(무드)를 Claude→OpenAI로 옮겨
  전체 AI를 OpenAI 한 제공자로 통일한다. 클라이언트 계약은 불변이라 **서버 함수 내부만** 변경
  (Anthropic SDK→OpenAI, `ANTHROPIC_API_KEY`→`OPENAI_API_KEY` 단일화, 프롬프트 GPT-5 미세조정,
  재배포, 개인정보 방침 정리). 출시·검증된 코드라 **별도 spec/plan으로 신중히 재검증**한다.
  본 포즈 기능(포즈 추천만 OpenAI) 완료 후 진행.
- 포즈 정렬 판정(ML Kit pose로 "맞췄는지" 피드백) — 이번엔 시각 가이드만.
- 100+ 확장(에셋 추가 생성으로 대응), 진짜 사진 실루엣 팩 교체.
- 오버레이 좌우 반전·크기 조절·불투명도 슬라이더(고정값으로 시작).
- 커플/우정 다인원 정렬 보조.
