# AI 사진 이름·태그 — 설계 (spec)

- 작성일: 2026-07-19
- 상태: 설계 합의 완료 (구현 계획 작성 전)
- 관련: 무드 보정의 결과 화면(`CaptureResultScreen`) 확장, 통일된 OpenAI 인프라(`functions/src/openai.ts` `visionJson`) 재사용

## 1. 목적 / 한 줄 정의

촬영한 사진에 AI가 **재밌는 이름**을 지어 주고 **검색용 태그**를 붙여, 파일명·EXIF에 담아 저장한다.
이름 짓는 재미 + 나중에 검색 편의가 목적.

## 2. 사용자 흐름

```
촬영(셔터) → 결과 화면(CaptureResultScreen) 진입 — 셔터에서 즉시 저장하지 않는다
  → (최초 1회 동의) 원본 이미지를 서버로 전송 → {name, tags[]} 자동 생성
  → 이름: 편집 가능한 텍스트 필드 / 태그: 칩으로 표시(MVP는 표시만)
  → [저장]:
       · 원본을 {이름}.jpg + EXIF(이름·태그)로 갤러리에 저장
       · 무드를 골랐으면 보정본도 {이름}_보정.jpg + EXIF로 함께 저장
```

- **저장 지점 일원화**: 무드 기능이 셔터에서 원본을 즉시 저장하던 동작을 **제거**하고, 결과 화면 [저장]에서
  이름을 붙여 저장한다. (이름은 촬영 후 생성되므로 원본도 이름을 받으려면 저장을 뒤로 미뤄야 함)
- 사진 유실 방지: 결과 화면을 벗어나기 전 저장하지 않으면 저장 안 됨 — 저장 버튼이 유일 경로.

## 3. 이름·태그 규칙

- `name`: 짧고 재밌는 **한국어 제목**, 최대 20자. 예) "노을 삼킨 커피잔".
- `tags`: 3–5개 한국어 키워드(검색용). 예) ["커피","노을","카페","감성"].
- 자동 생성: 결과 화면 진입 시 1회(동의 후). 이름은 사용자가 편집 가능.

## 4. 서버 (기존 통일 인프라 재사용)

- 새 콜러블 `describe`: 입력 `{imageBase64, mediaType, deviceId}` → `visionJson`(GPT-5 mini, strict) →
  출력 `{name: string, tags: string[]}`.
- 스키마(strict): `name`(string), `tags`(array of string). `additionalProperties: false`, 둘 다 required.
- **App Check 강제·레이트리밋·auth 재사용**(enhance/suggestPose 패턴 미러), 시크릿 `OPENAI_API_KEY`.
- 프롬프트: "사진을 보고 짧고 재밌는 한국어 제목(≤20자)과 검색용 태그 3~5개를 짓는다."

## 5. 저장 상세

- 최종 이미지(원본, 그리고 무드 적용 시 보정본)를 `image` 패키지로 **EXIF 기록**:
  - ImageDescription = 이름(+ 태그를 함께 담는다: 예 "이름 · 태그1, 태그2").
  - 가능하면 키워드 필드도 기록. 최소한 ImageDescription에 이름·태그가 들어가면 됨.
- 파일명: 이름을 **파일시스템 안전 문자열로 sanitize**(금지문자 제거, 공백→_, 길이 제한) 후
  `{sanitized}.jpg`(보정본 `{sanitized}_보정.jpg`)로 임시 저장 → `CameraService.saveToGallery`(파일명 유지).
- 이름 충돌/빈 이름: 빈/무효면 기본 파일명(타임스탬프)로 폴백.

## 6. 구조 (계산=순수 TDD, 렌더/IO/서버 분리)

| 파일 | 책임 | 검증 |
|---|---|---|
| `lib/analysis/photo_naming.dart` | **순수** — `sanitizeFilename(name)`(금지문자·공백·길이), `formatExifDescription(name, tags)` | 엄격 TDD |
| `functions/src/describe.ts` | 순수: `DESCRIBE_SCHEMA`, `buildDescribeSystem/User`, `parseDescribe(text)` | vitest |
| `functions/src/describe_callable.ts` | onCall(visionJson 재사용, App Check·레이트리밋·auth) | 배포 검증 |
| `functions/src/index.ts` | `describe` export | — |
| `lib/cloud/describe_advisor.dart` | `describe` 호출·파싱·폴백 | 파싱 테스트 |
| `lib/edit/exif_tagger.dart` | EXIF 기록 + `{name}.jpg` 임시 파일 생성(image 패키지, 아이솔레이트) | 기기 |
| `lib/screens/capture_result_screen.dart`(수정) | 진입 시 자동 생성, 이름 필드·태그 칩, 저장 시 원본/보정본 이름 적용 | 기기 |
| `lib/screens/camera_screen.dart`(수정) | 셔터에서 즉시 저장 제거 → 결과 화면 push만 | 기기 |

- 기존 `lib/cloud/advice_image.dart`(다운사이즈·base64), `device_id.dart`, `advice_consent.dart` 재사용.

## 7. 데이터 흐름

```
[셔터] takePicture → 원본 경로 → CaptureResultScreen(원본)
  진입: (동의) describe_advisor(다운사이즈 원본) → {name, tags} → 이름 필드·태그 칩 표시
  [저장]: exif_tagger(원본, name, tags) → {sanitize(name)}.jpg → saveToGallery
          무드 선택 시: exif_tagger(보정본, name, tags) → {sanitize(name)}_보정.jpg → saveToGallery
```

## 8. 에러 / 폴백

- describe 실패·오프라인·미동의 → 이름·태그 없이 기본 파일명으로 저장(기능 유지, 사진 유실 없음).
- 이름 편집 결과가 빈 값 → 기본 파일명.
- EXIF 기록 실패(디코드 등) → 태그 없이 원본 저장 + 안내.

## 9. 테스트 전략

- `photo_naming.dart`(순수): sanitize(금지문자·길이·빈값), formatExifDescription. 엄격 TDD.
- `functions/src/describe.ts`(순수): 스키마·프롬프트·parseDescribe(방어·비JSON throw). vitest.
- exif_tagger·describe_advisor·화면·콜러블: 기기/배포 검증.

## 10. 개인정보 / 스토어

- 이미지가 OpenAI로 전송(이름·태그 생성). 개인정보 처리방침의 "AI 구도 추천·사진 보정"에 준하는 처리 →
  방침 문구에 "사진 이름·태그 생성"을 포함하도록 소폭 보강(이미 OpenAI 수탁 명시됨).
- 기능 실기기 검증 후에만 스토어 설명에 기재.

## 11. 범위 밖 (YAGNI / 후속)

- 태그 편집·추가·삭제(MVP는 표시만, 이름만 편집).
- 앱 내 사진 라이브러리·검색 화면(파일명·EXIF에만 저장; 검색은 갤러리 앱에 의존).
- 여러 이름 후보 제시·재생성 버튼.
- XMP dc:subject 등 표준 키워드 필드 완전 지원(우선 EXIF ImageDescription).
