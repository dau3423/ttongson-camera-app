# 똥손카메라 Phase 2 — 클라우드 AI 구도 추천 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사용자가 요청하면 현재 프레임 1장을 Firebase Cloud Function을 거쳐 Claude(vision)로 보내 구도 추천(`CompositionAdvice`)을 받아 오버레이로 보여준다. 실패 시 온디바이스 가이드로 폴백.

**Architecture:** 앱의 `CloudAdvisor`가 캡처 프레임을 다운사이즈·JPEG 인코딩해 Firebase callable `advise`를 호출한다. `advise`(TypeScript, 2nd gen)는 App Check를 강제하고 `@anthropic-ai/sdk`로 `claude-sonnet-4-6`을 structured-output(json_schema)으로 호출한 뒤 `CompositionAdvice` JSON을 반환한다. 순수 로직(파싱·다운사이즈 계산)은 TDD, Firebase/카메라/네트워크 경계는 구현+검증.

**Tech Stack:** Flutter(Dart), `firebase_core`/`cloud_functions`/`firebase_app_check`/`image`; Firebase Cloud Functions(Node 22, TypeScript), `firebase-functions` v2, `@anthropic-ai/sdk`, `vitest`(백엔드 유닛테스트), Secret Manager.

## Global Constraints

- 앱 프레임워크: Flutter(Dart), null-safety. 패키지명 `ttongson_camera`. Flutter/dart at `/Users/soonbok/flutter/bin`.
- **API 키는 앱에 절대 넣지 않는다.** `ANTHROPIC_API_KEY`는 Firebase Secret Manager에만 존재하고, `advise` 함수에서만 읽는다.
- 모델 ID는 정확히 **`claude-sonnet-4-6`** (날짜 접미사 금지).
- Claude 호출은 반드시 **`output_config.format`의 `json_schema`**로 구조화 출력을 강제한다(아래 스키마 고정).
- `CompositionAdvice` 계약(앱·백엔드 동일): `headline: String`, `directions: [{axis: "move"|"tilt"|"zoom"|"angle", instruction: String}]`, `rationale: String`.
- 좌표/각도 규약은 Phase 1과 동일(정규화 0~1, 도 단위). 색 규약: 좋음=녹색, 주의=빨강.
- **Phase 1 기능은 네트워크 0회 유지.** 클라우드는 이 기능에서만.
- 이미지 다운사이즈: 긴 변 **1080px**, JPEG quality **80**. 업스케일 금지.
- 앱 정적분석은 `dart analyze lib test`(한글 경로로 `flutter analyze` 크래시). 백엔드는 `npm run build`(tsc) + `npm test`(vitest).
- 커밋: Conventional Commits. 작업 디렉토리 `/Users/soonbok/Projects/junicode/똥손카메라`.

---

## File Structure

```
functions/                              # Firebase Cloud Functions (TypeScript, Node 22)
  package.json  tsconfig.json  vitest.config.ts
  src/
    index.ts                            # export { advise }
    schema.ts                           # COMPOSITION_SCHEMA + SYSTEM_PROMPT + buildUserText()
    advice.ts                           # CompositionAdvice type, parseAdvice(), requestAdvice()  [pure/testable]
    advise.ts                           # onCall handler (App Check, validation, requestAdvice)
  test/
    advice.test.ts                      # parseAdvice + buildUserText unit tests
firebase.json  .firebaserc              # Firebase config (project root)
lib/cloud/
  composition_advice.dart               # CompositionAdvice + AdviceDirection + AdviceAxis + fromJson  [pure, TDD]
  advice_image.dart                     # fitWithin() [pure, TDD] + encodeDownsizedJpeg() [impl]
  cloud_advisor.dart                    # CloudAdvisor.suggest() — callable call + parse + timeout/error
  advice_overlay.dart                   # AdviceOverlay widget (display only)
  advice_consent.dart                   # AdviceConsentStore (SharedPreferences-backed consent flag)
test/cloud/
  composition_advice_test.dart
  advice_image_test.dart
lib/camera/camera_service.dart          # MODIFY: add captureFrameForAdvice()
lib/screens/camera_screen.dart          # MODIFY: consent gate + advice trigger + loading + fallback
lib/main.dart                           # MODIFY: Firebase.initializeApp + App Check activate
pubspec.yaml                            # MODIFY: add firebase deps + image + shared_preferences
```

파일 분리 원칙: 파싱·계산 등 순수 로직은 자체 파일 + 테스트(단일 책임). callable/카메라/위젯은 판단 로직 없이 전송·표시만.

---

## Task 1: Firebase 프로젝트 + Functions 스캐폴드 + Secret/App Check 설정

**Files:**
- Create: `firebase.json`, `.firebaserc`, `functions/package.json`, `functions/tsconfig.json`, `functions/src/index.ts`
- Modify: `.gitignore` (functions 빌드 산출물)

**Interfaces:**
- Consumes: 없음
- Produces: 배포/에뮬레이터로 실행 가능한 빈 functions 프로젝트, `ANTHROPIC_API_KEY` Secret 등록 안내.

> 이 태스크는 계정/프로젝트가 필요한 설정 작업이다. 실제 `firebase login`/프로젝트 생성은 사람이 수행해야 할 수 있다 — 로그인/프로젝트가 없으면 아래 명령의 출력과 함께 NEEDS_CONTEXT로 보고하고 멈춘다(가짜 값으로 진행하지 말 것).

- [ ] **Step 1: Firebase 로그인 상태 확인**

Run: `firebase projects:list`
Expected: 프로젝트 목록이 보이면 로그인됨. "not logged in"이면 사용자에게 `! firebase login` 실행을 요청하고 NEEDS_CONTEXT로 보고.

- [ ] **Step 2: functions 스캐폴드 수동 작성 (init 대화형 회피)**

`firebase init`은 대화형이라 스킵하고 파일을 직접 만든다.

`.firebaserc`:
```json
{
  "projects": {
    "default": "ttongson-camera"
  }
}
```
> `ttongson-camera`는 실제 Firebase 프로젝트 ID로 교체. 존재하지 않으면 `firebase projects:create ttongson-camera`(또는 콘솔에서 생성) 후 진행. 생성 권한이 없으면 NEEDS_CONTEXT.

`firebase.json`:
```json
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs22"
  },
  "emulators": {
    "functions": { "port": 5001 },
    "auth": { "port": 9099 },
    "ui": { "enabled": true }
  }
}
```

`functions/package.json`:
```json
{
  "name": "ttongson-functions",
  "type": "module",
  "engines": { "node": "22" },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "serve": "npm run build && firebase emulators:start --only functions"
  },
  "dependencies": {
    "@anthropic-ai/sdk": "^0.70.0",
    "firebase-admin": "^13.0.0",
    "firebase-functions": "^6.1.0"
  },
  "devDependencies": {
    "typescript": "^5.6.0",
    "vitest": "^2.1.0"
  }
}
```

`functions/tsconfig.json`:
```json
{
  "compilerOptions": {
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "target": "ES2022",
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"],
  "exclude": ["test"]
}
```

`functions/src/index.ts` (임시 헬스체크):
```typescript
export { advise } from "./advise.js";
```
> 주의: `advise.ts`는 Task 3에서 생성한다. 지금은 index.ts가 컴파일되도록 임시로 아래 placeholder를 `functions/src/advise.ts`에 둔다(Task 3에서 교체):
```typescript
// functions/src/advise.ts (placeholder — Task 3에서 실제 구현으로 교체)
import { onCall } from "firebase-functions/v2/https";
export const advise = onCall(() => ({ ok: true }));
```

- [ ] **Step 3: 의존성 설치 + 빌드**

Run: `cd functions && npm install && npm run build && cd ..`
Expected: `functions/lib/index.js` 생성, 에러 없음.

- [ ] **Step 4: Secret 등록 안내 + gitignore**

`.gitignore`에 추가(맨 아래):
```
# Firebase functions build
functions/lib/
functions/node_modules/
.firebase/
```

Secret 등록(키가 있어야 함 — 없으면 사용자에게 요청):
Run: `firebase functions:secrets:set ANTHROPIC_API_KEY`
Expected: 값 입력 프롬프트 → 등록됨. 키가 없으면 이 단계는 사용자 몫으로 남기고 보고에 명시.

- [ ] **Step 5: Commit**

```bash
git add .firebaserc firebase.json functions/package.json functions/tsconfig.json functions/src .gitignore
git commit -m "chore: scaffold Firebase functions for cloud advisor"
```

---

## Task 2: 백엔드 구조화 출력 스키마 + 파서 (TDD)

**Files:**
- Create: `functions/src/schema.ts`, `functions/src/advice.ts`, `functions/test/advice.test.ts`, `functions/vitest.config.ts`
- Modify: `functions/package.json` (이미 vitest 포함)

**Interfaces:**
- Consumes: 없음
- Produces:
  - `functions/src/advice.ts`: `export interface CompositionAdvice { headline: string; directions: AdviceDirection[]; rationale: string }`, `export interface AdviceDirection { axis: "move"|"tilt"|"zoom"|"angle"; instruction: string }`, `export function parseAdvice(text: string): CompositionAdvice` (형식 위반 시 throw), `export interface OnDeviceMetrics { tiltDeg?: number; personCenterX?: number; personCenterY?: number; hasPerson?: boolean }`.
  - `functions/src/schema.ts`: `export const COMPOSITION_SCHEMA` (json_schema 객체), `export const SYSTEM_PROMPT: string`, `export function buildUserText(metrics?: OnDeviceMetrics): string`.

- [ ] **Step 1: vitest 설정 + 실패 테스트 작성**

`functions/vitest.config.ts`:
```typescript
import { defineConfig } from "vitest/config";
export default defineConfig({ test: { include: ["test/**/*.test.ts"] } });
```

`functions/test/advice.test.ts`:
```typescript
import { describe, it, expect } from "vitest";
import { parseAdvice } from "../src/advice.js";
import { buildUserText } from "../src/schema.js";

describe("parseAdvice", () => {
  it("유효한 JSON을 CompositionAdvice로 파싱", () => {
    const text = JSON.stringify({
      headline: "인물을 오른쪽 3분할선으로",
      directions: [{ axis: "move", instruction: "오른쪽으로 한 걸음" }],
      rationale: "여백이 넓어 답답합니다",
    });
    const a = parseAdvice(text);
    expect(a.headline).toBe("인물을 오른쪽 3분할선으로");
    expect(a.directions).toHaveLength(1);
    expect(a.directions[0].axis).toBe("move");
    expect(a.rationale).toContain("여백");
  });

  it("필수 필드 누락이면 throw", () => {
    expect(() => parseAdvice(JSON.stringify({ headline: "x" }))).toThrow();
  });

  it("잘못된 axis 값이면 throw", () => {
    const bad = JSON.stringify({
      headline: "x",
      directions: [{ axis: "spin", instruction: "y" }],
      rationale: "z",
    });
    expect(() => parseAdvice(bad)).toThrow();
  });

  it("JSON이 아니면 throw", () => {
    expect(() => parseAdvice("not json")).toThrow();
  });
});

describe("buildUserText", () => {
  it("인물 지표가 있으면 프롬프트에 위치를 포함", () => {
    const t = buildUserText({ hasPerson: true, personCenterX: 0.2, personCenterY: 0.5, tiltDeg: 3 });
    expect(t).toContain("인물");
    expect(t).toContain("0.2");
  });

  it("지표가 없어도 유효한 지시문을 만든다", () => {
    const t = buildUserText(undefined);
    expect(t.length).toBeGreaterThan(0);
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd functions && npx vitest run 2>&1 | tail -20 ; cd ..`
Expected: FAIL — `advice.js`/`schema.js` 모듈/심볼 없음.

- [ ] **Step 3: schema.ts 구현**

```typescript
// functions/src/schema.ts
import type { OnDeviceMetrics } from "./advice.js";

export const COMPOSITION_SCHEMA = {
  type: "object",
  properties: {
    headline: { type: "string" },
    directions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          axis: { type: "string", enum: ["move", "tilt", "zoom", "angle"] },
          instruction: { type: "string" },
        },
        required: ["axis", "instruction"],
        additionalProperties: false,
      },
    },
    rationale: { type: "string" },
  },
  required: ["headline", "directions", "rationale"],
  additionalProperties: false,
} as const;

export const SYSTEM_PROMPT =
  "당신은 사진 구도 코치입니다. 사용자가 카메라로 보고 있는 장면 사진 한 장을 받고, " +
  "인물·배경·위치를 고려해 더 좋은 구도로 찍는 방법을 제안합니다. " +
  "반드시 한국어로, 간결하고 바로 실행 가능한 조언만 제공합니다. " +
  "headline은 한 줄 핵심, directions는 실행 힌트 목록(axis: move=이동, tilt=수평 기울기, zoom=줌/거리, angle=촬영 각도), " +
  "rationale은 한 문장 이유입니다. 이미 좋은 부분은 굳이 바꾸라고 하지 마세요.";

export function buildUserText(metrics?: OnDeviceMetrics): string {
  const lines = ["이 장면을 더 좋은 구도로 찍는 방법을 제안해 주세요."];
  if (metrics) {
    if (metrics.hasPerson && metrics.personCenterX != null && metrics.personCenterY != null) {
      lines.push(
        `참고(온디바이스 감지): 인물 중심이 정규화 좌표 (${metrics.personCenterX}, ${metrics.personCenterY})에 있습니다.`,
      );
    }
    if (metrics.tiltDeg != null) {
      lines.push(`참고: 현재 좌우 기울기 약 ${metrics.tiltDeg}도.`);
    }
  }
  return lines.join("\n");
}
```

- [ ] **Step 4: advice.ts 구현 (파서)**

```typescript
// functions/src/advice.ts
export interface AdviceDirection {
  axis: "move" | "tilt" | "zoom" | "angle";
  instruction: string;
}

export interface CompositionAdvice {
  headline: string;
  directions: AdviceDirection[];
  rationale: string;
}

export interface OnDeviceMetrics {
  tiltDeg?: number;
  personCenterX?: number;
  personCenterY?: number;
  hasPerson?: boolean;
}

const VALID_AXES = new Set(["move", "tilt", "zoom", "angle"]);

/** 모델이 반환한 JSON 텍스트를 CompositionAdvice로 검증·파싱. 위반 시 throw. */
export function parseAdvice(text: string): CompositionAdvice {
  const raw = JSON.parse(text); // JSON 아니면 SyntaxError throw
  if (typeof raw.headline !== "string" || typeof raw.rationale !== "string") {
    throw new Error("headline/rationale 누락");
  }
  if (!Array.isArray(raw.directions)) {
    throw new Error("directions 누락");
  }
  const directions: AdviceDirection[] = raw.directions.map((d: unknown) => {
    const dir = d as Record<string, unknown>;
    if (!VALID_AXES.has(dir.axis as string) || typeof dir.instruction !== "string") {
      throw new Error(`잘못된 direction: ${JSON.stringify(d)}`);
    }
    return { axis: dir.axis as AdviceDirection["axis"], instruction: dir.instruction };
  });
  return { headline: raw.headline, directions, rationale: raw.rationale };
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd functions && npx vitest run 2>&1 | tail -20 ; cd ..`
Expected: PASS (6개).

- [ ] **Step 6: Commit**

```bash
git add functions/src/schema.ts functions/src/advice.ts functions/test/advice.test.ts functions/vitest.config.ts
git commit -m "feat(functions): add composition schema, prompt, and advice parser (TDD)"
```

---

## Task 3: `advise` Callable 핸들러 (App Check + Claude 호출)

**Files:**
- Modify: `functions/src/advise.ts` (Task 1의 placeholder 교체)
- Create: `functions/src/claude.ts`

**Interfaces:**
- Consumes: `parseAdvice`, `OnDeviceMetrics`, `COMPOSITION_SCHEMA`, `SYSTEM_PROMPT`, `buildUserText`.
- Produces: callable `advise` — 요청 `{ imageBase64: string, mediaType: "image/jpeg", metrics?: OnDeviceMetrics }` → 응답 `CompositionAdvice`. App Check 강제, 입력 검증, 오류를 `HttpsError`로 매핑.

> 실기기/에뮬레이터 의존이라 자동 유닛테스트 없음. 게이트는 `npm run build`(tsc) 통과 + 에뮬레이터 수동 호출. 파서·스키마는 Task 2에서 이미 테스트됨.

- [ ] **Step 1: claude.ts 구현 (Anthropic 호출)**

```typescript
// functions/src/claude.ts
import Anthropic from "@anthropic-ai/sdk";
import { COMPOSITION_SCHEMA, SYSTEM_PROMPT, buildUserText } from "./schema.js";
import { parseAdvice, type CompositionAdvice, type OnDeviceMetrics } from "./advice.js";

export async function requestAdvice(
  apiKey: string,
  imageBase64: string,
  mediaType: "image/jpeg",
  metrics: OnDeviceMetrics | undefined,
): Promise<CompositionAdvice> {
  const client = new Anthropic({ apiKey });
  const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: SYSTEM_PROMPT,
    output_config: { format: { type: "json_schema", schema: COMPOSITION_SCHEMA } },
    messages: [
      {
        role: "user",
        content: [
          { type: "image", source: { type: "base64", media_type: mediaType, data: imageBase64 } },
          { type: "text", text: buildUserText(metrics) },
        ],
      },
    ],
  });
  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("모델 응답에 텍스트 블록이 없습니다");
  }
  return parseAdvice(textBlock.text);
}
```
> 주의: 설치된 `@anthropic-ai/sdk` 버전의 이미지/`output_config` 타입이 다르면, 이 스킬 문서(claude-api)의 TypeScript 예시에 맞춰 필드명을 조정한다. `npm run build`가 통과해야 한다.

- [ ] **Step 2: advise.ts 핸들러 구현 (placeholder 교체)**

```typescript
// functions/src/advise.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { requestAdvice } from "./claude.js";
import type { OnDeviceMetrics } from "./advice.js";

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

const MAX_IMAGE_BYTES = 4 * 1024 * 1024; // base64 기준 대략 상한

export const advise = onCall(
  {
    secrets: [ANTHROPIC_API_KEY],
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (request) => {
    const data = request.data as {
      imageBase64?: string;
      mediaType?: string;
      metrics?: OnDeviceMetrics;
    };

    if (typeof data.imageBase64 !== "string" || data.imageBase64.length === 0) {
      throw new HttpsError("invalid-argument", "imageBase64가 필요합니다");
    }
    if (data.imageBase64.length > MAX_IMAGE_BYTES) {
      throw new HttpsError("invalid-argument", "이미지가 너무 큽니다");
    }
    if (data.mediaType !== "image/jpeg") {
      throw new HttpsError("invalid-argument", "mediaType은 image/jpeg만 지원합니다");
    }

    try {
      return await requestAdvice(
        ANTHROPIC_API_KEY.value(),
        data.imageBase64,
        "image/jpeg",
        data.metrics,
      );
    } catch (err) {
      console.error("advise failed", err);
      throw new HttpsError("internal", "구도 추천 생성에 실패했습니다");
    }
  },
);
```

- [ ] **Step 3: 빌드 확인**

Run: `cd functions && npm run build 2>&1 | tail -20 ; cd ..`
Expected: tsc 에러 없음, `functions/lib/advise.js` 생성.

- [ ] **Step 4: 에뮬레이터 수동 검증 (선택, 실기기 연동 전)**

Run: `cd functions && firebase emulators:start --only functions` (별도 터미널)
확인: 에뮬레이터가 `advise` 함수를 로드하고 크래시 없이 뜬다. App Check 강제 때문에 브라우저 직접 호출은 거부되는 게 정상(앱에서 검증은 Task 10). 확인 후 종료.

- [ ] **Step 5: Commit**

```bash
git add functions/src/advise.ts functions/src/claude.ts
git commit -m "feat(functions): advise callable with App Check and Claude vision"
```

---

## Task 4: 앱 Firebase/이미지 의존성 추가 + 초기화

**Files:**
- Modify: `pubspec.yaml`, `lib/main.dart`
- (플랫폼 설정은 `flutterfire configure`가 생성)

**Interfaces:**
- Consumes: 없음
- Produces: `Firebase.initializeApp` + App Check 활성화된 앱 진입점. `cloud_functions`/`image`/`shared_preferences` 사용 가능.

> `flutterfire configure`는 Firebase 프로젝트와 로그인이 필요하다. 없으면 NEEDS_CONTEXT로 보고. 앱은 Firebase 초기화 실패 시에도 카메라 기능은 동작해야 한다(초기화는 try/catch, 실패해도 진행).

- [ ] **Step 1: 의존성 추가**

Run:
```bash
flutter pub add firebase_core cloud_functions firebase_app_check image shared_preferences
```
Expected: `pubspec.yaml`에 5개 추가, `flutter pub get` 성공.

- [ ] **Step 2: FlutterFire 설정 생성**

Run: `flutterfire configure --project=ttongson-camera`
Expected: `lib/firebase_options.dart` 생성 + android/ios에 Firebase 설정 파일 추가. (CLI 미설치 시 `dart pub global activate flutterfire_cli` 후 재시도. 로그인/프로젝트 없으면 NEEDS_CONTEXT.)

- [ ] **Step 3: main.dart에서 초기화**

`lib/main.dart`를 아래로 교체:
```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAppCheck.instance.activate(
      // 디버그: 개발 중에는 debug provider, 배포 시 Play Integrity/DeviceCheck로 교체.
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } catch (e) {
    // Firebase 초기화 실패해도 온디바이스 카메라 기능은 계속 동작.
    debugPrint('Firebase init failed: $e');
  }
  runApp(const TtongsonApp());
}

class TtongsonApp extends StatelessWidget {
  const TtongsonApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '똥손카메라',
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}
```
> 기존 `SystemChrome.setPreferredOrientations(portraitUp)` 호출이 Phase 1 main.dart에 있었다면 유지한다(위 코드에 추가):
```dart
import 'package:flutter/services.dart';
// main() 안, Firebase 초기화 전:
await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
```

- [ ] **Step 4: 분석 확인**

Run: `dart analyze lib 2>&1 | tail -5`
Expected: 에러 없음. (`firebase_options.dart` 없으면 이 태스크의 Step 2가 필요 — 미완이면 보고.)

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/firebase_options.dart android ios
git commit -m "chore: add Firebase core/app-check/functions and init in app"
```

---

## Task 5: `CompositionAdvice` 앱 모델 (TDD)

**Files:**
- Create: `lib/cloud/composition_advice.dart`, `test/cloud/composition_advice_test.dart`

**Interfaces:**
- Consumes: 없음(순수 Dart)
- Produces:
  - `enum AdviceAxis { move, tilt, zoom, angle }`
  - `class AdviceDirection { final AdviceAxis axis; final String instruction; }`
  - `class CompositionAdvice { final String headline; final List<AdviceDirection> directions; final String rationale; }`
  - `factory CompositionAdvice.fromJson(Map<String, dynamic> json)` — 누락/이상 값에 방어적. 알 수 없는 axis는 해당 direction을 건너뛴다.

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/cloud/composition_advice_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/composition_advice.dart';

void main() {
  test('정상 JSON을 파싱한다', () {
    final a = CompositionAdvice.fromJson({
      'headline': '인물을 오른쪽 3분할선으로',
      'directions': [
        {'axis': 'move', 'instruction': '오른쪽으로 한 걸음'},
        {'axis': 'angle', 'instruction': '살짝 낮게'},
      ],
      'rationale': '여백이 넓어 답답합니다',
    });
    expect(a.headline, '인물을 오른쪽 3분할선으로');
    expect(a.directions.length, 2);
    expect(a.directions.first.axis, AdviceAxis.move);
    expect(a.directions[1].axis, AdviceAxis.angle);
    expect(a.rationale, contains('여백'));
  });

  test('알 수 없는 axis는 건너뛴다', () {
    final a = CompositionAdvice.fromJson({
      'headline': 'x',
      'directions': [
        {'axis': 'spin', 'instruction': 'y'},
        {'axis': 'zoom', 'instruction': '조금 당기세요'},
      ],
      'rationale': 'z',
    });
    expect(a.directions.length, 1);
    expect(a.directions.first.axis, AdviceAxis.zoom);
  });

  test('directions 누락 시 빈 목록', () {
    final a = CompositionAdvice.fromJson({'headline': 'x', 'rationale': 'z'});
    expect(a.directions, isEmpty);
    expect(a.headline, 'x');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/cloud/composition_advice_test.dart`
Expected: FAIL — `composition_advice.dart` 없음.

- [ ] **Step 3: 구현**

```dart
// lib/cloud/composition_advice.dart
enum AdviceAxis { move, tilt, zoom, angle }

AdviceAxis? _axisFromString(String? s) {
  switch (s) {
    case 'move':
      return AdviceAxis.move;
    case 'tilt':
      return AdviceAxis.tilt;
    case 'zoom':
      return AdviceAxis.zoom;
    case 'angle':
      return AdviceAxis.angle;
    default:
      return null;
  }
}

class AdviceDirection {
  final AdviceAxis axis;
  final String instruction;
  const AdviceDirection({required this.axis, required this.instruction});
}

/// 클라우드 구도 추천 결과. 방어적 파싱 — 누락/이상 값에도 견고.
class CompositionAdvice {
  final String headline;
  final List<AdviceDirection> directions;
  final String rationale;

  const CompositionAdvice({
    required this.headline,
    required this.directions,
    required this.rationale,
  });

  factory CompositionAdvice.fromJson(Map<String, dynamic> json) {
    final rawDirs = json['directions'];
    final directions = <AdviceDirection>[];
    if (rawDirs is List) {
      for (final d in rawDirs) {
        if (d is Map) {
          final axis = _axisFromString(d['axis'] as String?);
          final instruction = d['instruction'];
          if (axis != null && instruction is String) {
            directions.add(AdviceDirection(axis: axis, instruction: instruction));
          }
        }
      }
    }
    return CompositionAdvice(
      headline: (json['headline'] as String?) ?? '',
      directions: directions,
      rationale: (json['rationale'] as String?) ?? '',
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/cloud/composition_advice_test.dart`
Expected: PASS (3개).

- [ ] **Step 5: Commit**

```bash
git add lib/cloud/composition_advice.dart test/cloud/composition_advice_test.dart
git commit -m "feat: add CompositionAdvice model with defensive fromJson (TDD)"
```

---

## Task 6: 이미지 다운사이즈 계산 (TDD) + JPEG 인코더

**Files:**
- Create: `lib/cloud/advice_image.dart`, `test/cloud/advice_image_test.dart`

**Interfaces:**
- Consumes: `image` 패키지(인코더 부분).
- Produces:
  - `class ScaledSize { final int width; final int height; }`
  - `ScaledSize fitWithin(int width, int height, int maxLongEdge)` — 긴 변이 maxLongEdge를 넘으면 비율 유지 축소, 이미 작으면 그대로(업스케일 금지). [순수, TDD]
  - `Future<String> encodeDownsizedJpeg(String srcPath, {int maxLongEdge = 1080, int quality = 80})` — 파일을 읽어 다운사이즈·JPEG 인코딩해 임시 경로에 저장, base64 아님(경로 반환). [impl]
  - `Future<String> fileToBase64(String path)` — 파일을 base64 문자열로. [impl, thin]

- [ ] **Step 1: fitWithin 실패 테스트 작성**

```dart
// test/cloud/advice_image_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/advice_image.dart';

void main() {
  test('긴 변이 한계를 넘으면 비율 유지 축소 (가로)', () {
    final s = fitWithin(4000, 3000, 1080);
    expect(s.width, 1080);
    expect(s.height, 810); // 3000 * 1080/4000
  });

  test('긴 변이 한계를 넘으면 비율 유지 축소 (세로)', () {
    final s = fitWithin(3000, 4000, 1080);
    expect(s.height, 1080);
    expect(s.width, 810);
  });

  test('이미 작으면 그대로 (업스케일 금지)', () {
    final s = fitWithin(800, 600, 1080);
    expect(s.width, 800);
    expect(s.height, 600);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/cloud/advice_image_test.dart`
Expected: FAIL — `advice_image.dart`/`fitWithin` 없음.

- [ ] **Step 3: 구현**

```dart
// lib/cloud/advice_image.dart
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

class ScaledSize {
  final int width;
  final int height;
  const ScaledSize({required this.width, required this.height});
}

/// 긴 변이 maxLongEdge를 넘으면 비율 유지 축소, 아니면 원본 유지(업스케일 금지).
ScaledSize fitWithin(int width, int height, int maxLongEdge) {
  final longEdge = width > height ? width : height;
  if (longEdge <= maxLongEdge) {
    return ScaledSize(width: width, height: height);
  }
  final scale = maxLongEdge / longEdge;
  return ScaledSize(
    width: (width * scale).round(),
    height: (height * scale).round(),
  );
}

/// srcPath 이미지를 다운사이즈·JPEG로 재인코딩해 임시 파일 경로를 반환.
Future<String> encodeDownsizedJpeg(
  String srcPath, {
  int maxLongEdge = 1080,
  int quality = 80,
}) async {
  final bytes = await File(srcPath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('이미지 디코딩 실패: $srcPath');
  }
  final target = fitWithin(decoded.width, decoded.height, maxLongEdge);
  final resized = (target.width == decoded.width && target.height == decoded.height)
      ? decoded
      : img.copyResize(decoded, width: target.width, height: target.height);
  final jpeg = img.encodeJpg(resized, quality: quality);
  final outPath = '$srcPath.advice.jpg';
  await File(outPath).writeAsBytes(jpeg);
  return outPath;
}

/// 파일을 base64 문자열로 인코딩.
Future<String> fileToBase64(String path) async {
  final bytes = await File(path).readAsBytes();
  return base64Encode(bytes);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/cloud/advice_image_test.dart`
Expected: PASS (3개).

- [ ] **Step 5: Commit**

```bash
git add lib/cloud/advice_image.dart test/cloud/advice_image_test.dart
git commit -m "feat: add image downsize calc (TDD) and JPEG encoder"
```

---

## Task 7: `CloudAdvisor` (callable 호출 + 파싱 + 타임아웃)

**Files:**
- Create: `lib/cloud/cloud_advisor.dart`

**Interfaces:**
- Consumes: `cloud_functions`, `CompositionAdvice` (Task 5), `encodeDownsizedJpeg`/`fileToBase64` (Task 6), `GuideMetrics` (Phase 1, `lib/analysis/guide_metrics.dart`).
- Produces:
  - `class CloudAdviceException implements Exception { final String message; }`
  - `class CloudAdvisor { CloudAdvisor({FirebaseFunctions? functions}); Future<CompositionAdvice> suggest(String jpegPath, GuideMetrics metrics, String deviceId); }`
  - `suggest`: 다운사이즈→base64→callable `advise` 호출(5초 타임아웃, `deviceId` 포함)→`CompositionAdvice.fromJson`. 실패 시 `CloudAdviceException` throw. `deviceId`는 백엔드 레이트리밋 키(Task 11).

> callable/네트워크 의존이라 자동 유닛테스트 없음. 게이트는 `dart analyze` + 기기 검증(Task 10). 파싱·인코딩은 Task 5/6에서 테스트됨.

- [ ] **Step 1: 구현**

```dart
// lib/cloud/cloud_advisor.dart
import 'package:cloud_functions/cloud_functions.dart';
import '../analysis/guide_metrics.dart';
import 'advice_image.dart';
import 'composition_advice.dart';

class CloudAdviceException implements Exception {
  final String message;
  CloudAdviceException(this.message);
  @override
  String toString() => 'CloudAdviceException: $message';
}

/// 현재 프레임을 클라우드 함수로 보내 구도 추천을 받는다. 판단 없음(전송·파싱만).
class CloudAdvisor {
  final FirebaseFunctions _functions;
  CloudAdvisor({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<CompositionAdvice> suggest(
    String jpegPath,
    GuideMetrics metrics,
    String deviceId,
  ) async {
    try {
      final downsized = await encodeDownsizedJpeg(jpegPath);
      final base64 = await fileToBase64(downsized);
      final callable = _functions.httpsCallable(
        'advise',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 5)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64,
        'mediaType': 'image/jpeg',
        'deviceId': deviceId,
        'metrics': _metricsPayload(metrics),
      });
      return CompositionAdvice.fromJson(Map<String, dynamic>.from(result.data));
    } on FirebaseFunctionsException catch (e) {
      throw CloudAdviceException(e.message ?? '구도 추천 실패');
    } catch (e) {
      throw CloudAdviceException('구도 추천 실패: $e');
    }
  }

  Map<String, dynamic> _metricsPayload(GuideMetrics m) {
    final person = m.person;
    return {
      'tiltDeg': double.parse(m.tilt.rollDegrees.toStringAsFixed(1)),
      'hasPerson': person != null,
      if (person != null) 'personCenterX': double.parse(person.centerX.toStringAsFixed(2)),
      if (person != null) 'personCenterY': double.parse(person.centerY.toStringAsFixed(2)),
    };
  }
}
```
> `GuideMetrics.tilt.rollDegrees`, `GuideMetrics.person`(nullable `PersonBox`), `PersonBox.centerX/centerY`는 Phase 1에 존재한다(확인됨).

- [ ] **Step 2: 분석 확인**

Run: `dart analyze lib/cloud/cloud_advisor.dart`
Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
git add lib/cloud/cloud_advisor.dart
git commit -m "feat: add CloudAdvisor callable client with downsize and timeout"
```

---

## Task 8: `CameraService.captureFrameForAdvice()` (갤러리 저장 없이 프레임 확보)

**Files:**
- Modify: `lib/camera/camera_service.dart`

**Interfaces:**
- Consumes: `camera`.
- Produces: `Future<String> captureFrameForAdvice()` — 스트림 정지→`takePicture()`→(갤러리 저장 안 함) 파일 경로 반환. 호출측이 이후 스트림 재개.

- [ ] **Step 1: 메서드 추가**

`lib/camera/camera_service.dart`의 `captureAndSave()` 아래에 추가:
```dart
  /// 구도 추천용으로 현재 프레임을 촬영해 임시 파일 경로를 반환한다.
  /// 갤러리에 저장하지 않는다. 호출 후 스트림 재개는 호출측 책임.
  Future<String> captureFrameForAdvice() async {
    if (_streaming) await stopStream();
    final file = await controller.takePicture();
    return file.path;
  }
```

- [ ] **Step 2: 분석 확인**

Run: `dart analyze lib/camera/camera_service.dart`
Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
git add lib/camera/camera_service.dart
git commit -m "feat: add captureFrameForAdvice (no gallery save)"
```

---

## Task 9: `AdviceOverlay` 위젯 + 동의 저장소 + DeviceId

**Files:**
- Create: `lib/cloud/advice_overlay.dart`, `lib/cloud/advice_consent.dart`, `lib/cloud/device_id.dart`

**Interfaces:**
- Consumes: `CompositionAdvice`/`AdviceAxis` (Task 5), `shared_preferences`.
- Produces:
  - `class AdviceOverlay extends StatelessWidget { final CompositionAdvice advice; final VoidCallback onClose; }` — headline·directions·rationale 카드 표시.
  - `class AdviceConsentStore { Future<bool> hasConsented(); Future<void> setConsented(); }` — SharedPreferences 플래그.
  - `class DeviceId { Future<String> get(); }` — 기기별 안정 UUID를 SharedPreferences에 1회 생성·보관(레이트리밋 키).

> 위젯/플러그인 의존이라 자동 테스트 없음. 게이트는 `dart analyze` + 시각 검증(Task 10).

- [ ] **Step 1: advice_consent.dart 구현**

```dart
// lib/cloud/advice_consent.dart
import 'package:shared_preferences/shared_preferences.dart';

/// 클라우드 구도 추천(프레임 전송) 동의 여부를 저장.
class AdviceConsentStore {
  static const _key = 'cloud_advice_consented';

  Future<bool> hasConsented() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setConsented() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
```

- [ ] **Step 2: advice_overlay.dart 구현**

```dart
// lib/cloud/advice_overlay.dart
import 'package:flutter/material.dart';
import 'composition_advice.dart';

String _axisLabel(AdviceAxis axis) {
  switch (axis) {
    case AdviceAxis.move:
      return '이동';
    case AdviceAxis.tilt:
      return '수평';
    case AdviceAxis.zoom:
      return '줌';
    case AdviceAxis.angle:
      return '각도';
  }
}

/// 클라우드 구도 추천 결과 카드. 판단 없음 — advice를 그대로 표시.
class AdviceOverlay extends StatelessWidget {
  final CompositionAdvice advice;
  final VoidCallback onClose;
  const AdviceOverlay({super.key, required this.advice, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 140,
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      advice.headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),
              for (final d in advice.directions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '· [${_axisLabel(d.axis)}] ${d.instruction}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              if (advice.rationale.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    advice.rationale,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: device_id.dart 구현**

```dart
// lib/cloud/device_id.dart
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// 기기별 안정 식별자(레이트리밋 키). 최초 1회 생성해 SharedPreferences에 보관.
/// 계정/인증이 아니며 프라이버시 목적으로만 사용(개인정보 아님).
class DeviceId {
  static const _key = 'device_id';

  Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _randomId();
    await prefs.setString(_key, id);
    return id;
  }

  String _randomId() {
    // dart:math Random.secure 기반 16바이트 hex (UUID 형식 불필요, 충돌만 회피).
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
```

- [ ] **Step 4: 분석 + 전체 테스트**

Run: `dart analyze lib test && flutter test 2>&1 | tail -3`
Expected: analyze 에러 없음, 기존 테스트 전부 PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/cloud/advice_overlay.dart lib/cloud/advice_consent.dart lib/cloud/device_id.dart
git commit -m "feat: add AdviceOverlay card, consent store, and device id"
```

---

## Task 10: `CameraScreen` 배선 — 동의 게이트 + 추천 트리거 + 로딩 + 폴백

**Files:**
- Modify: `lib/screens/camera_screen.dart`

**Interfaces:**
- Consumes: `CameraService.captureFrameForAdvice`(Task 8), `CloudAdvisor`(Task 7), `AdviceOverlay`/`AdviceConsentStore`(Task 9), `CompositionAdvice`, 기존 `_metrics`(GuideMetrics).
- Produces: 실행 가능한 전체 화면 — "구도 추천" 버튼, 동의 다이얼로그(최초 1회), 로딩 인디케이터, 결과 오버레이, 실패 시 스낵바 폴백 + 스트림 재개.

> 통합/기기 검증. 기존 `camera_screen.dart` 구조(state, `_metrics`, `_camera`, `_capture`, build의 Stack/버튼 Row)를 유지하며 아래를 추가한다.

- [ ] **Step 1: 상태·의존 필드 추가**

`_CameraScreenState` 안에 필드 추가:
```dart
  final CloudAdvisor _advisor = CloudAdvisor();
  final AdviceConsentStore _consent = AdviceConsentStore();
  final DeviceId _deviceId = DeviceId();
  CompositionAdvice? _advice;
  bool _adviceLoading = false;
```
그리고 상단 import 추가:
```dart
import '../cloud/cloud_advisor.dart';
import '../cloud/composition_advice.dart';
import '../cloud/advice_overlay.dart';
import '../cloud/advice_consent.dart';
import '../cloud/device_id.dart';
```

- [ ] **Step 2: 트리거 핸들러 추가**

`_CameraScreenState` 안에 메서드 추가:
```dart
  Future<void> _requestAdvice() async {
    if (_adviceLoading) return;

    // 최초 1회 동의
    if (!await _consent.hasConsented()) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('구도 추천 안내'),
          content: const Text(
            '구도 추천 시 현재 화면 1장을 분석 서버로 전송합니다. '
            '이미지는 저장하지 않습니다.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('동의')),
          ],
        ),
      );
      if (ok != true) return;
      await _consent.setConsented();
    }

    setState(() => _adviceLoading = true);
    String? framePath;
    try {
      final deviceId = await _deviceId.get();
      framePath = await _camera.captureFrameForAdvice();
      final advice = await _advisor.suggest(framePath, _metrics, deviceId);
      if (mounted) setState(() => _advice = advice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('추천을 못 받았어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _adviceLoading = false);
      // 스트림 재개 (captureFrameForAdvice가 멈춤)
      _camera.startStream(_onFrame);
    }
  }
```
> `_onFrame`은 Phase 1 카메라 화면의 프레임 콜백 이름이다(존재 확인). 다르면 실제 이름으로 맞춘다.

- [ ] **Step 3: build에 버튼·오버레이·로딩 추가**

하단 버튼 Row(격자 토글·촬영 버튼이 있는 곳)에 "구도 추천" 버튼을 추가:
```dart
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                  onPressed: _requestAdvice,
                ),
```
그리고 최상위 `Stack`의 children 끝에 오버레이·로딩을 추가:
```dart
          if (_advice != null)
            AdviceOverlay(
              advice: _advice!,
              onClose: () => setState(() => _advice = null),
            ),
          if (_adviceLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
```

- [ ] **Step 4: 분석 + 전체 테스트 + 게이트**

Run: `dart analyze lib test && flutter test 2>&1 | tail -3 && bash tool/verify.sh 2>&1 | tail -3`
Expected: analyze 에러 없음, 기존 순수 로직 테스트 전부 PASS, `verify.sh` 통과.

- [ ] **Step 5: 기기 수동 검증**

연결된 실기기에서 `flutter run` 후 확인:
- "구도 추천"(✨) 버튼 첫 탭 → 동의 다이얼로그 → 동의 시 로딩 → 몇 초 내 추천 카드 표시.
- 카드에 headline/directions/rationale이 한국어로 보인다.
- 네트워크 끊고 탭 → 스낵바 폴백 + 프리뷰 정상 재개(멈추지 않음).
- 재탭 시 동의 다이얼로그가 다시 뜨지 않는다(동의 저장됨).
- 촬영·격자·수평 등 Phase 1 기능이 여전히 정상.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/camera_screen.dart
git commit -m "feat: wire cloud advice trigger, consent, loading, and fallback"
```

---

## Task 11: 백엔드 레이트리밋 (Firestore 고정 윈도우, deviceId 기준)

**Files:**
- Create: `functions/src/ratelimit.ts`, `functions/test/ratelimit.test.ts`
- Modify: `functions/src/advise.ts`

**Interfaces:**
- Consumes: `firebase-admin/firestore`.
- Produces:
  - `functions/src/ratelimit.ts`: `export function windowStart(nowMs: number, windowMs: number): number` (윈도우 시작 ms), `export function overLimit(count: number, max: number): boolean`. [순수, TDD]
  - `advise.ts`: `deviceId` 검증 + Firestore 고정 윈도우 카운터로 분당 `RATE_MAX`회 초과 시 `HttpsError("resource-exhausted")`.

- [ ] **Step 1: 순수 로직 실패 테스트 작성**

`functions/test/ratelimit.test.ts`:
```typescript
import { describe, it, expect } from "vitest";
import { windowStart, overLimit } from "../src/ratelimit.js";

describe("windowStart", () => {
  it("윈도우 경계로 내림", () => {
    expect(windowStart(12_345, 60_000)).toBe(0);
    expect(windowStart(65_000, 60_000)).toBe(60_000);
    expect(windowStart(120_000, 60_000)).toBe(120_000);
  });
});

describe("overLimit", () => {
  it("count가 max 이상이면 true", () => {
    expect(overLimit(5, 5)).toBe(true);
    expect(overLimit(6, 5)).toBe(true);
    expect(overLimit(4, 5)).toBe(false);
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd functions && npx vitest run 2>&1 | tail -20 ; cd ..`
Expected: FAIL — `ratelimit.js` 없음.

- [ ] **Step 3: ratelimit.ts 구현**

```typescript
// functions/src/ratelimit.ts
/** 고정 윈도우 시작 시각(ms). */
export function windowStart(nowMs: number, windowMs: number): number {
  return Math.floor(nowMs / windowMs) * windowMs;
}

/** 현재 카운트가 상한 이상인지. */
export function overLimit(count: number, max: number): boolean {
  return count >= max;
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd functions && npx vitest run 2>&1 | tail -20 ; cd ..`
Expected: PASS (전체, 기존 advice.test 포함).

- [ ] **Step 5: advise.ts에 레이트리밋 통합**

`functions/src/advise.ts` 상단 import·초기화 추가:
```typescript
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { windowStart, overLimit } from "./ratelimit.js";

if (getApps().length === 0) initializeApp();

const RATE_MAX = 20; // deviceId당 분당 최대 호출
const RATE_WINDOW_MS = 60_000;
```
핸들러 내부, 이미지 검증 직후·`requestAdvice` 호출 전에 추가:
```typescript
    const deviceId = data.deviceId;
    if (typeof deviceId !== "string" || deviceId.length === 0 || deviceId.length > 64) {
      throw new HttpsError("invalid-argument", "deviceId가 필요합니다");
    }

    const now = Date.now();
    const win = windowStart(now, RATE_WINDOW_MS);
    const ref = getFirestore().collection("rate_limits").doc(`${deviceId}_${win}`);
    const count = await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = (snap.exists ? (snap.data()?.count as number) : 0) ?? 0;
      tx.set(ref, { count: current + 1, expiresAt: win + RATE_WINDOW_MS }, { merge: true });
      return current + 1;
    });
    if (overLimit(count, RATE_MAX)) {
      throw new HttpsError("resource-exhausted", "요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요.");
    }
```
그리고 요청 타입에 `deviceId`를 추가:
```typescript
    const data = request.data as {
      imageBase64?: string;
      mediaType?: string;
      deviceId?: string;
      metrics?: OnDeviceMetrics;
    };
```

- [ ] **Step 6: 빌드 확인**

Run: `cd functions && npm run build 2>&1 | tail -10 ; cd ..`
Expected: tsc 에러 없음.

- [ ] **Step 7: Commit**

```bash
git add functions/src/ratelimit.ts functions/test/ratelimit.test.ts functions/src/advise.ts
git commit -m "feat(functions): per-device fixed-window rate limiting (TDD)"
```

---

## Task 12: 2초 정지 자동 트리거 (StillnessDetector TDD + 배선)

**Files:**
- Create: `lib/cloud/stillness_detector.dart`, `test/cloud/stillness_detector_test.dart`
- Modify: `lib/screens/camera_screen.dart`

**Interfaces:**
- Consumes: 가속도계 크기(magnitude) 샘플 + 타임스탬프. `_requestAdvice`(Task 10).
- Produces:
  - `class StillnessDetector { StillnessDetector({double moveThreshold, int stillMs}); bool update(double magnitude, int nowMs); void reset(); }` — 연속 정지가 `stillMs` 이상 지속되면 **에피소드당 한 번** true. 다시 움직이면 재무장. [순수, TDD]
  - `camera_screen.dart`: 가속도계 리스너에서 detector에 공급, true + 동의됨 + 쿨다운(10초) 경과 + 비로딩이면 `_requestAdvice()` 자동 호출.

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/cloud/stillness_detector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/stillness_detector.dart';

void main() {
  test('정지가 stillMs 이상 지속되면 한 번 true', () {
    final d = StillnessDetector(moveThreshold: 0.5, stillMs: 2000);
    // 첫 샘플은 기준선(이전 값 없음) → false
    expect(d.update(9.8, 0), isFalse);
    expect(d.update(9.8, 500), isFalse);   // 정지 지속 중이나 2초 미달
    expect(d.update(9.8, 1500), isFalse);
    expect(d.update(9.8, 2000), isTrue);   // 2초 도달 → 발화
    expect(d.update(9.8, 2500), isFalse);  // 같은 에피소드 재발화 안 함
  });

  test('움직이면 타이머 리셋 후 다시 무장', () {
    final d = StillnessDetector(moveThreshold: 0.5, stillMs: 2000);
    d.update(9.8, 0);
    expect(d.update(9.8, 2000), isTrue);   // 첫 발화
    expect(d.update(12.0, 2100), isFalse); // 큰 변화 = 움직임 → 리셋
    expect(d.update(12.0, 4000), isFalse); // 새 정지 구간 2초 미달(기준 2100)
    expect(d.update(12.0, 4100), isTrue);  // 2초 도달 → 재발화
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/cloud/stillness_detector_test.dart`
Expected: FAIL — `stillness_detector.dart` 없음.

- [ ] **Step 3: 구현**

```dart
// lib/cloud/stillness_detector.dart
/// 가속도계 크기 샘플로 "정지 지속"을 감지한다.
/// 연속 정지가 stillMs 이상이면 에피소드당 한 번 true. 순수 로직(플러그인 무관).
class StillnessDetector {
  final double moveThreshold;
  final int stillMs;

  double? _lastMagnitude;
  int _stillSinceMs = 0;
  bool _fired = false;

  StillnessDetector({this.moveThreshold = 0.5, this.stillMs = 2000});

  /// 새 샘플. 정지가 stillMs 이상 지속되는 순간 처음 한 번만 true.
  bool update(double magnitude, int nowMs) {
    final prev = _lastMagnitude;
    _lastMagnitude = magnitude;
    if (prev == null) {
      _stillSinceMs = nowMs;
      return false;
    }
    final moved = (magnitude - prev).abs() > moveThreshold;
    if (moved) {
      _stillSinceMs = nowMs;
      _fired = false;
      return false;
    }
    if (!_fired && nowMs - _stillSinceMs >= stillMs) {
      _fired = true;
      return true;
    }
    return false;
  }

  void reset() {
    _lastMagnitude = null;
    _fired = false;
    _stillSinceMs = 0;
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/cloud/stillness_detector_test.dart`
Expected: PASS (2개).

- [ ] **Step 5: camera_screen.dart에 자동 트리거 배선**

import 추가: `import '../cloud/stillness_detector.dart';` 그리고 `dart:math`(magnitude 계산용) `import 'dart:math' as math;`.
`_CameraScreenState` 필드 추가:
```dart
  final StillnessDetector _stillness = StillnessDetector();
  int _lastAdviceMs = 0;
  static const int _adviceCooldownMs = 10000;
```
기존 가속도계 리스너(Phase 1에서 `accelerometerEventStream().listen(...)`로 `_sensor` 갱신하는 곳)의 콜백 안에 추가:
```dart
      final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_stillness.update(mag, nowMs)) {
        _maybeAutoAdvise(nowMs);
      }
```
그리고 메서드 추가:
```dart
  Future<void> _maybeAutoAdvise(int nowMs) async {
    if (_adviceLoading || _advice != null) return;
    if (nowMs - _lastAdviceMs < _adviceCooldownMs) return;
    if (!await _consent.hasConsented()) return; // 동의 전에는 자동 트리거 안 함
    _lastAdviceMs = nowMs;
    await _requestAdvice();
  }
```
또한 `_requestAdvice` 성공/실패와 무관하게 쿨다운이 갱신되도록, `_requestAdvice`의 `finally`에 추가:
```dart
      _lastAdviceMs = DateTime.now().millisecondsSinceEpoch;
```

> 자동 트리거는 **이미 동의한 경우에만** 발동한다(동의 다이얼로그를 자동으로 띄우지 않음). 수동 버튼이 최초 동의를 받는 경로.

- [ ] **Step 6: 분석 + 전체 테스트 + 게이트**

Run: `dart analyze lib test && flutter test 2>&1 | tail -3 && bash tool/verify.sh 2>&1 | tail -3`
Expected: analyze 에러 없음, 순수 로직 테스트 전부 PASS, `verify.sh` 통과.

- [ ] **Step 7: 기기 수동 검증**

실기기에서 `flutter run`:
- (동의 후) 폰을 2초 이상 가만히 들고 있으면 자동으로 추천이 뜬다.
- 추천 직후 10초 내에는 재자동 트리거되지 않는다(쿨다운).
- 움직이는 동안엔 자동 트리거가 발동하지 않는다.

- [ ] **Step 8: Commit**

```bash
git add lib/cloud/stillness_detector.dart test/cloud/stillness_detector_test.dart lib/screens/camera_screen.dart
git commit -m "feat: add 2s-stillness auto-trigger for cloud advice (TDD)"
```

---

## Self-Review 결과

**Spec 커버리지:**
- §2 스택(Firebase Functions/App Check/Secret/sonnet-4-6/구조화 출력) → Task 1,3,4 ✅
- §3 모듈: CloudAdvisor→Task 7, CompositionAdvice→Task 5, AdviceOverlay→Task 9, advise 함수→Task 3 ✅
- §4 데이터 계약(스키마·필드) → Task 2(백엔드 스키마/파서), Task 5(앱 모델) — 필드·enum 일치 ✅
- §5 트리거/UX(버튼·로딩·결과·폴백·2초 자동 트리거) → Task 10(수동·로딩·폴백), Task 12(2초 자동 트리거) ✅
- §6 프라이버시(동의·미보관·HTTPS·최소 전송) → Task 9(동의), Task 3(미보관/로그), Task 6(다운사이즈) ✅
- §7 비기능(지연 타임아웃·레이트리밋·토큰절감) → Task 7(5초 타임아웃), Task 3(App Check/timeout), Task 11(deviceId 분당 레이트리밋), Task 6(다운사이즈) ✅

**플레이스홀더 스캔:** Task 1의 `advise.ts` placeholder는 Task 3에서 교체하도록 명시 — 잔여 없음. 프로젝트 ID `ttongson-camera`는 실제 값으로 교체 안내. ✅

**타입 일관성:** `CompositionAdvice`/`AdviceDirection`/axis enum(`move|tilt|zoom|angle`)이 백엔드(Task 2)·앱(Task 5)에서 일치. `OnDeviceMetrics`(백엔드)와 `_metricsPayload`(Task 7) 키(`tiltDeg`/`hasPerson`/`personCenterX`/`personCenterY`) 일치. `captureFrameForAdvice`(Task 8)↔`_requestAdvice`(Task 10), `suggest(jpegPath, metrics, deviceId)`(Task 7)↔호출(Task 10) 시그니처 일치. `deviceId`가 앱(Task 9 DeviceId → Task 7 payload) ↔ 백엔드(Task 11 검증/레이트리밋) 일치. `StillnessDetector.update`(Task 12)↔가속도계 리스너 배선 일치. ✅

**범위:** spec의 2초 자동 트리거·백엔드 레이트리밋을 이번 범위에 포함(Task 11, 12)했다.
