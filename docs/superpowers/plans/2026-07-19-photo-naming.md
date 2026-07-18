# AI 사진 이름·태그 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 촬영 결과 화면 진입 시 AI가 사진 이름·태그를 자동 생성하고, [저장] 시 원본(및 무드 보정본)을 `{이름}.jpg` + EXIF(이름·태그)로 갤러리에 저장한다.

**Architecture:** 이름 sanitize·EXIF 문자열 조립은 순수 Dart(`analysis/photo_naming.dart`)로 TDD한다. 서버 `describe` 콜러블은 통일 헬퍼 `functions/src/openai.ts`의 `visionJson`(GPT-5 mini, strict)을 재사용해 `{name, tags}`를 반환한다. EXIF 기록(`image` 패키지)·서버·화면은 분리한다. 셔터의 즉시 저장을 제거하고 저장을 결과 화면으로 일원화해 원본도 이름을 받게 한다.

**Tech Stack:** Flutter/Dart, `image` ^4.9.1(EXIF·다운사이즈), `cloud_functions`, `path_provider`, `gallery_saver_plus`; Firebase Functions(TypeScript, nodejs22) + `openai`(`gpt-5-mini`), vitest.

## Global Constraints

- `lib/analysis/photo_naming.dart`는 **순수 Dart**(Flutter/plugin/`image` import 금지).
- `name`: 짧고 재밌는 한국어 제목(AI는 ≤20자 지향); 파일명 sanitize는 금지문자 제거·공백→`_`·최대 **40자**·빈값이면 `photo` 폴백. `tags`: 3–5개, 파서에서 최대 5개로 제한.
- EXIF: `image` 패키지로 **ImageDescription**에 이름·태그 문자열 기록. 파일명 = sanitize된 이름(`{name}.jpg`, 보정본 `{name}_보정.jpg`).
- AI 호출은 **OpenAI GPT-5 mini**를 `visionJson`으로. **App Check·레이트리밋·auth·consent** 재사용.
- **저장 일원화**: 셔터(`camera_screen._capture`)의 `saveToGallery` 제거 → 결과 화면 [저장]에서 원본(및 보정본) 저장.
- 실패·오프라인·미동의·빈이름 → 이름·태그 없이/기본 파일명으로 저장(사진 유실 없음).
- 정적 분석 **`dart analyze lib test`**, 완료 게이트 **`tool/verify.sh`**, 서버 `cd functions && npm run build && npx vitest run`.
- Conventional Commits. Flutter SDK PATH: `/Users/soonbok/flutter/bin`.

---

### Task 1: 파일명 sanitize + EXIF 문자열 (순수)

**Files:**
- Create: `lib/analysis/photo_naming.dart`
- Test: `test/analysis/photo_naming_test.dart`

**Interfaces:**
- Consumes: 없음.
- Produces:
  - `String sanitizeFilename(String name, {String fallback = 'photo'})`
  - `String formatExifDescription(String name, List<String> tags)`

- [ ] **Step 1: 실패 테스트 작성**

`test/analysis/photo_naming_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/photo_naming.dart';

void main() {
  group('sanitizeFilename', () {
    test('금지문자 제거', () {
      expect(sanitizeFilename('노을/커피:잔*?'), '노을커피잔');
    });
    test('공백은 밑줄로, 앞뒤 정리', () {
      expect(sanitizeFilename('  노을 삼킨 커피잔 '), '노을_삼킨_커피잔');
    });
    test('빈 값/공백뿐이면 fallback', () {
      expect(sanitizeFilename('   '), 'photo');
      expect(sanitizeFilename('///'), 'photo');
      expect(sanitizeFilename('', fallback: 'shot'), 'shot');
    });
    test('40자로 제한', () {
      final long = 'ㄱ' * 60;
      expect(sanitizeFilename(long).length, 40);
    });
  });

  group('formatExifDescription', () {
    test('이름과 태그를 합침', () {
      expect(
        formatExifDescription('노을 커피', ['커피', '노을']),
        '노을 커피 · 커피, 노을',
      );
    });
    test('태그 없으면 이름만', () {
      expect(formatExifDescription('노을 커피', const []), '노을 커피');
    });
    test('이름 비면 태그만', () {
      expect(formatExifDescription('', ['커피', '노을']), '커피, 노을');
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/analysis/photo_naming_test.dart`
Expected: FAIL (`photo_naming.dart` 없음).

- [ ] **Step 3: 최소 구현**

`lib/analysis/photo_naming.dart` (⚠️ Flutter/image import 금지):

```dart
// lib/analysis/photo_naming.dart
// 순수 Dart — 파일명 안전화와 EXIF 설명 문자열 조립.

/// 파일시스템 안전 파일명(확장자 제외). 금지문자 제거, 공백→_, 최대 40자, 빈값이면 fallback.
String sanitizeFilename(String name, {String fallback = 'photo'}) {
  // 금지문자(/ \ : * ? " < > | 및 제어문자) 제거
  var s = name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]'), '');
  // 공백 런을 _로
  s = s.trim().replaceAll(RegExp(r'\s+'), '_');
  if (s.isEmpty) return fallback;
  if (s.length > 40) s = s.substring(0, 40);
  return s;
}

/// EXIF ImageDescription용 문자열. 이름과 태그를 사람이 읽기 좋게 합친다.
String formatExifDescription(String name, List<String> tags) {
  final n = name.trim();
  final t = tags.where((e) => e.trim().isNotEmpty).join(', ');
  if (n.isEmpty) return t;
  if (t.isEmpty) return n;
  return '$n · $t';
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/analysis/photo_naming_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/analysis/photo_naming.dart test/analysis/photo_naming_test.dart
git commit -m "feat: 파일명 sanitize·EXIF 설명 문자열(순수 TDD)"
```

---

### Task 2: 서버 describe 순수 로직

**Files:**
- Create: `functions/src/describe.ts`
- Create: `functions/test/describe.test.ts`

**Interfaces:**
- Consumes: 없음.
- Produces:
  - `DESCRIBE_SCHEMA`(strict json schema)
  - `buildDescribeSystem(): string`
  - `buildDescribeUser(): string`
  - `parseDescribe(text: string): { name: string; tags: string[] }`

- [ ] **Step 1: 실패 테스트 작성**

`functions/test/describe.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { DESCRIBE_SCHEMA, parseDescribe, buildDescribeUser } from "../src/describe.js";

describe("DESCRIBE_SCHEMA", () => {
  it("name·tags required, additionalProperties false", () => {
    const s = DESCRIBE_SCHEMA as any;
    expect(s.required).toEqual(["name", "tags"]);
    expect(s.additionalProperties).toBe(false);
    expect(s.properties.tags.type).toBe("array");
  });
});

describe("buildDescribeUser", () => {
  it("한국어 제목·태그 지시를 포함", () => {
    const t = buildDescribeUser();
    expect(t).toContain("제목");
    expect(t).toContain("태그");
  });
});

describe("parseDescribe", () => {
  it("유효 JSON 파싱", () => {
    const r = parseDescribe(JSON.stringify({ name: "노을 커피", tags: ["커피", "노을"] }));
    expect(r.name).toBe("노을 커피");
    expect(r.tags).toEqual(["커피", "노을"]);
  });
  it("태그는 최대 5개로 제한, 비문자열 제거", () => {
    const r = parseDescribe(
      JSON.stringify({ name: "x", tags: ["a", "b", "c", "d", "e", "f", 3] }),
    );
    expect(r.tags).toEqual(["a", "b", "c", "d", "e"]);
  });
  it("name 비문자열이면 빈 문자열, tags 비배열이면 빈 배열", () => {
    const r = parseDescribe(JSON.stringify({ name: 1, tags: "no" }));
    expect(r.name).toBe("");
    expect(r.tags).toEqual([]);
  });
  it("JSON이 아니면 throw", () => {
    expect(() => parseDescribe("nope")).toThrow();
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd functions && npx vitest run test/describe.test.ts`
Expected: FAIL (`describe.js` 없음).

- [ ] **Step 3: 구현**

`functions/src/describe.ts`:

```ts
export const DESCRIBE_SCHEMA = {
  type: "object",
  properties: {
    name: { type: "string" },
    tags: { type: "array", items: { type: "string" } },
  },
  required: ["name", "tags"],
  additionalProperties: false,
} as const;

export function buildDescribeSystem(): string {
  return (
    "당신은 사진에 이름을 붙이는 작가입니다. 반드시 한국어로 답합니다. " +
    "사진을 보고 짧고 재밌는 제목(20자 이내)과 검색용 태그 3~5개를 짓습니다. " +
    "제목은 위트 있게, 태그는 사진 속 사물·장소·분위기를 담은 짧은 명사로."
  );
}

export function buildDescribeUser(): string {
  return "이 사진의 재밌는 제목 하나와 검색용 태그 3~5개를 지어 주세요.";
}

export function parseDescribe(text: string): { name: string; tags: string[] } {
  const raw = JSON.parse(text);
  if (raw === null || typeof raw !== "object") {
    throw new Error("describe 결과 JSON 형식 오류");
  }
  const o = raw as Record<string, unknown>;
  const name = typeof o.name === "string" ? o.name : "";
  const tags = Array.isArray(o.tags)
    ? o.tags.filter((t): t is string => typeof t === "string").slice(0, 5)
    : [];
  return { name, tags };
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd functions && npx vitest run test/describe.test.ts`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add functions/src/describe.ts functions/test/describe.test.ts
git commit -m "feat: 서버 describe 순수 로직(스키마·프롬프트·결과 파싱)"
```

---

### Task 3: 서버 콜러블 `describe` (OpenAI)

**Files:**
- Create: `functions/src/describe_callable.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Consumes: `visionJson`(openai.ts), `DESCRIBE_SCHEMA`/`buildDescribeSystem`/`buildDescribeUser`/`parseDescribe`(describe.ts), `ratelimit.ts`, `auth_guard.ts`.
- Produces: `export const describe`(onCall). 입력 `{imageBase64, mediaType, deviceId}`, 출력 `{name, tags}`.

- [ ] **Step 1: `describe_callable.ts` 구현 (`enhance.ts` 패턴 미러)**

`functions/src/describe_callable.ts`:

```ts
// functions/src/describe_callable.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { visionJson } from "./openai.js";
import { requireAuthUid } from "./auth_guard.js";
import { windowStart, overLimit } from "./ratelimit.js";
import {
  DESCRIBE_SCHEMA, buildDescribeSystem, buildDescribeUser, parseDescribe,
} from "./describe.js";

if (getApps().length === 0) initializeApp();

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

const MAX_IMAGE_BYTES = 4 * 1024 * 1024;
const RATE_MAX = 30;
const RATE_WINDOW_MS = 60_000;

export const describe = onCall(
  {
    region: "asia-northeast3",
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (request) => {
    requireAuthUid(request.auth);
    const data = request.data as {
      imageBase64?: string; mediaType?: string; deviceId?: string;
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

    try {
      const text = await visionJson({
        apiKey: OPENAI_API_KEY.value(),
        system: buildDescribeSystem(),
        userText: buildDescribeUser(),
        imageBase64: data.imageBase64,
        schemaName: "photo_description",
        schema: DESCRIBE_SCHEMA as { [key: string]: unknown },
      });
      return parseDescribe(text);
    } catch (err) {
      console.error("describe failed", err);
      throw new HttpsError("internal", "이름 생성에 실패했습니다");
    }
  },
);
```

- [ ] **Step 2: export 추가**

`functions/src/index.ts` 마지막에 추가:

```ts
export { describe } from "./describe_callable.js";
```

- [ ] **Step 3: 빌드·전체 서버 테스트**

Run: `cd functions && npm run build && npx vitest run`
Expected: 타입 오류 없이 빌드, 모든 테스트 PASS.

- [ ] **Step 4: 커밋**

```bash
git add functions/src/describe_callable.ts functions/src/index.ts
git commit -m "feat: 서버 describe 콜러블 — OpenAI 사진 이름·태그(구조화 출력)"
```

---

### Task 4: 클라이언트 describe 어드바이저

**Files:**
- Create: `lib/cloud/describe_advisor.dart`
- Test: `test/cloud/describe_advisor_test.dart`

**Interfaces:**
- Consumes: 기존 `lib/cloud/advice_image.dart`(`encodeDownsizedJpeg`, `fileToBase64`).
- Produces:
  - `class DescribeException implements Exception { final String message; ... }`
  - `class PhotoDescription { final String name; final List<String> tags; const PhotoDescription({...}); }`
  - `PhotoDescription photoDescriptionFromResult(Map<String, dynamic> data)` — 방어적.
  - `class DescribeAdvisor { DescribeAdvisor({FirebaseFunctions? functions}); Future<PhotoDescription> describe({required String jpegPath, required String deviceId}); }`

- [ ] **Step 1: 실패 테스트 작성**

`test/cloud/describe_advisor_test.dart` (순수 파싱만):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/describe_advisor.dart';

void main() {
  test('서버 결과 맵을 PhotoDescription으로 파싱', () {
    final d = photoDescriptionFromResult({'name': '노을 커피', 'tags': ['커피', '노을']});
    expect(d.name, '노을 커피');
    expect(d.tags, ['커피', '노을']);
  });

  test('name 비문자열·tags 비배열이면 방어', () {
    final d = photoDescriptionFromResult({'name': 3, 'tags': 'no'});
    expect(d.name, '');
    expect(d.tags, isEmpty);
  });

  test('tags 안의 비문자열은 제거', () {
    final d = photoDescriptionFromResult({'name': 'x', 'tags': ['a', 5, 'b']});
    expect(d.tags, ['a', 'b']);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/cloud/describe_advisor_test.dart`
Expected: FAIL (`describe_advisor.dart` 없음).

- [ ] **Step 3: 구현 (`lib/cloud/mood_advisor.dart` 패턴 미러)**

`lib/cloud/describe_advisor.dart`:

```dart
// lib/cloud/describe_advisor.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'advice_image.dart';

class DescribeException implements Exception {
  final String message;
  DescribeException(this.message);
  @override
  String toString() => 'DescribeException: $message';
}

class PhotoDescription {
  final String name;
  final List<String> tags;
  const PhotoDescription({required this.name, required this.tags});
}

/// 서버 결과 맵 → PhotoDescription (방어적).
PhotoDescription photoDescriptionFromResult(Map<String, dynamic> data) {
  final name = data['name'];
  final rawTags = data['tags'];
  final tags = rawTags is List
      ? rawTags.whereType<String>().toList()
      : <String>[];
  return PhotoDescription(name: name is String ? name : '', tags: tags);
}

/// 사진을 서버로 보내 이름·태그를 받는다. 판단 없음(전송·파싱만).
class DescribeAdvisor {
  final FirebaseFunctions _functions;
  DescribeAdvisor({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<PhotoDescription> describe({
    required String jpegPath,
    required String deviceId,
  }) async {
    try {
      final downsized = await encodeDownsizedJpeg(jpegPath);
      final base64 = await fileToBase64(downsized);
      final callable = _functions.httpsCallable(
        'describe',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64,
        'mediaType': 'image/jpeg',
        'deviceId': deviceId,
      });
      return photoDescriptionFromResult(Map<String, dynamic>.from(result.data));
    } on FirebaseFunctionsException catch (e) {
      throw DescribeException(e.message ?? '이름 생성 실패');
    } catch (e) {
      throw DescribeException('이름 생성 실패: $e');
    }
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/cloud/describe_advisor_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/cloud/describe_advisor.dart test/cloud/describe_advisor_test.dart
git commit -m "feat: 클라이언트 describe 어드바이저(호출·파싱)"
```

---

### Task 5: EXIF 태거 (image 패키지)

**Files:**
- Create: `lib/edit/exif_tagger.dart`
- Test: `test/edit/exif_tagger_test.dart`

**Interfaces:**
- Consumes: 없음(순수 이미지 처리).
- Produces:
  - `img.Image writeDescription(img.Image src, String description)` — ImageDescription EXIF 기록, 같은 이미지 반환.
  - `Future<File> saveTaggedJpeg({required File src, required String filename, required String description})` — 디코드→방향 반영→EXIF 기록→JPEG 인코드해 `{filename}.jpg` 임시 파일로 저장.

- [ ] **Step 1: 실패 테스트 작성**

`test/edit/exif_tagger_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ttongson_camera/edit/exif_tagger.dart';

void main() {
  test('writeDescription: EXIF ImageDescription을 기록', () {
    final src = img.Image(width: 2, height: 2);
    final out = writeDescription(src, '노을 커피 · 커피, 노을');
    final desc = out.exif.imageIfd['ImageDescription']?.toString();
    expect(desc, '노을 커피 · 커피, 노을');
  });

  test('writeDescription: 인코드·디코드 후에도 설명 유지', () {
    final src = img.Image(width: 4, height: 4);
    final tagged = writeDescription(src, '테스트설명');
    final bytes = img.encodeJpg(tagged);
    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.exif.imageIfd['ImageDescription']?.toString(), '테스트설명');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/edit/exif_tagger_test.dart`
Expected: FAIL (`exif_tagger.dart` 없음).

- [ ] **Step 3: 구현 (`lib/edit/mood_processor.dart` 패턴 참고)**

`lib/edit/exif_tagger.dart`:

```dart
// lib/edit/exif_tagger.dart
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// EXIF ImageDescription에 설명을 기록하고 같은 이미지를 반환.
img.Image writeDescription(img.Image src, String description) {
  src.exif.imageIfd['ImageDescription'] = description;
  return src;
}

/// src를 디코드→방향 반영→EXIF 기록→JPEG로 인코드해 `{filename}.jpg` 임시 파일로 저장.
Future<File> saveTaggedJpeg({
  required File src,
  required String filename,
  required String description,
}) async {
  final bytes = await src.readAsBytes();
  final jpeg = await Isolate.run(() => _process(bytes, description));
  final dir = await getTemporaryDirectory();
  final out = File('${dir.path}/$filename.jpg');
  await out.writeAsBytes(jpeg);
  return out;
}

Uint8List _process(Uint8List bytes, String description) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('이미지 디코딩 실패');
  }
  final baked = img.bakeOrientation(decoded);
  writeDescription(baked, description);
  return img.encodeJpg(baked, quality: 90);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter test test/edit/exif_tagger_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/edit/exif_tagger.dart test/edit/exif_tagger_test.dart
git commit -m "feat: EXIF 태거 — ImageDescription 기록·이름 파일로 저장"
```

---

### Task 6: 결과 화면 자동 생성·저장 반영 + 셔터 저장 제거 (기기 검증)

**Files:**
- Modify: `lib/screens/capture_result_screen.dart`
- Modify: `lib/screens/camera_screen.dart`

**Interfaces:**
- Consumes: `sanitizeFilename`/`formatExifDescription`(Task 1), `DescribeAdvisor`/`PhotoDescription`(Task 4), `saveTaggedJpeg`(Task 5), 기존 `_ensureConsent`·`_deviceId`·`_camera`·`applyMood`.

> UI/플러그인 통합이라 단위 테스트 대신 **기기 수동 검증**.

- [ ] **Step 1: 셔터의 즉시 저장 제거**

`lib/screens/camera_screen.dart` `_capture()`에서 저장 블록을 제거한다. 다음을 찾아:

```dart
      final saved = await _camera.saveToGallery(shotPath);
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 실패 — 사진첩 권한을 확인해 주세요')),
        );
      }
      if (mounted) {
```

다음으로 교체(저장 제거, 결과 화면 push만 유지):

```dart
      if (mounted) {
```

(이제 `shotPath`는 저장 없이 `CaptureResultScreen(original: File(shotPath), auth: _auth)`로 전달된다. 저장은 결과 화면이 담당.)

- [ ] **Step 2: 결과 화면 — 자동 생성 + 이름 필드·태그 칩**

`lib/screens/capture_result_screen.dart` 를 수정한다.

(a) 상단 import에 추가:

```dart
import '../analysis/photo_naming.dart';
import '../cloud/describe_advisor.dart';
import '../edit/exif_tagger.dart';
```

(b) State 필드 추가(`_camera` 아래):

```dart
  final _describe = DescribeAdvisor();
  final _nameController = TextEditingController();
  List<String> _tags = const [];
  bool _naming = false;
```

(c) `initState()` 에서 자동 생성 호출(기존 `_preview = widget.original;` 다음 줄):

```dart
    _generateNameTags();
```

(d) 이름·태그 생성 메서드 추가(`_save` 위):

```dart
  Future<void> _generateNameTags() async {
    if (!await _ensureConsent()) return;
    if (!mounted) return;
    setState(() => _naming = true);
    try {
      final deviceId = await _deviceId.get();
      final desc = await _describe.describe(
        jpegPath: widget.original.path,
        deviceId: deviceId,
      );
      if (!mounted) return;
      setState(() {
        if (_nameController.text.isEmpty) _nameController.text = desc.name;
        _tags = desc.tags;
      });
    } catch (_) {
      // 이름 없이 진행(폴백)
    } finally {
      if (mounted) setState(() => _naming = false);
    }
  }
```

(e) `dispose` 추가(State 클래스에):

```dart
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
```

(f) `build`의 무드 칩 `SizedBox(height: 92, ...)` **위**에 이름 필드 + 태그 칩을 삽입:

```dart
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: 40,
                    decoration: InputDecoration(
                      hintText: 'AI가 이름을 지어줘요',
                      counterText: '',
                      suffixIcon: _naming
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                children: [for (final t in _tags) Chip(label: Text('#$t'))],
              ),
            ),
```

- [ ] **Step 3: 결과 화면 — 저장 반영(원본·보정본에 이름·태그)**

`_save()` 를 아래로 교체(원본 항상 저장, 무드 선택 시 보정본도 저장):

```dart
  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = sanitizeFilename(_nameController.text);
    final desc = formatExifDescription(_nameController.text, _tags);
    try {
      final originalTagged = await saveTaggedJpeg(
        src: widget.original,
        filename: name,
        description: desc,
      );
      final okOriginal = await _camera.saveToGallery(originalTagged.path);
      var okEdited = true;
      if (_selected != null) {
        final editedTagged = await saveTaggedJpeg(
          src: _preview,
          filename: '${name}_보정',
          description: desc,
        );
        okEdited = await _camera.saveToGallery(editedTagged.path);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            (okOriginal && okEdited) ? '저장했어요' : '저장 실패 — 권한을 확인해 주세요',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }
```

> 참고: 기존 `_save`의 `if (_selected == null) { '원본은 이미 저장되어 있어요' }` 분기는 삭제된다(셔터 저장이 없어졌으므로 원본을 여기서 저장).

- [ ] **Step 4: 정적 분석**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && dart analyze lib test`
Expected: `No issues found!` (경고 있으면 수정).

- [ ] **Step 5: 기기 수동 검증**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && flutter run`
확인:
1. 촬영 → 결과 화면 진입 시 (동의 후) 이름이 자동 생성돼 필드에 표시, 태그 칩 표시.
2. 이름 수정 가능. [저장] → 갤러리에 `{이름}.jpg` 저장(무드 선택 시 `{이름}_보정.jpg`도).
3. 갤러리 앱에서 파일명이 이름으로 보임(EXIF 설명에 이름·태그 포함).
4. 셔터만 누르고 결과 화면을 벗어나면 저장 안 됨(저장은 [저장] 버튼에서만).
5. 비행기모드/미동의 → 이름 없이도 [저장]되면 기본 파일명(`photo.jpg`)으로 저장.

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/capture_result_screen.dart lib/screens/camera_screen.dart
git commit -m "feat: 결과 화면 AI 이름·태그 자동 생성·저장 반영, 셔터 즉시저장 제거"
```

---

### Task 7: 완료 게이트 + 개인정보 방침 보강

**Files:**
- Modify: `hosting/index.html` (방침 문구)

- [ ] **Step 1: 전체 검증 게이트**

Run: `export PATH="$PATH:/Users/soonbok/flutter/bin" && tool/verify.sh`
Expected: format·`dart analyze`·`flutter test` 모두 통과.

- [ ] **Step 2: 서버 검증**

Run: `cd functions && npm run build && npx vitest run`
Expected: 빌드·테스트 통과.

- [ ] **Step 3: 개인정보 방침 보강**

`hosting/index.html`의 3항 OpenAI 수탁 행에 "사진 이름·태그 생성"을 포함하도록 문구를 보강한다. 다음을 찾아:

```html
      <tr><td>OpenAI, L.L.C. (OpenAI API)</td><td>이용자가 요청한 AI 구도 추천·사진 보정을 위해 촬영 이미지·분석 지표를 전송·처리</td><td>국외(미국). API 입력은 모델 학습에 사용되지 않음</td></tr>
```

다음으로 교체:

```html
      <tr><td>OpenAI, L.L.C. (OpenAI API)</td><td>이용자가 요청한 AI 구도 추천·사진 보정·이름/태그 생성을 위해 촬영 이미지·분석 지표를 전송·처리</td><td>국외(미국). API 입력은 모델 학습에 사용되지 않음</td></tr>
```

- [ ] **Step 4: 방침 배포(선택, 출시 시)**

Run: `firebase deploy --only hosting --project ttongson-camera`
Expected: Deploy complete. `https://ttongson-camera.web.app/privacy` 반영.

- [ ] **Step 5: 커밋**

```bash
git add hosting/index.html
git commit -m "docs: 개인정보 방침에 사진 이름·태그 생성 추가"
```

- [ ] **Step 6: 배포·검증 안내(출시 시)**

- `describe` 콜러블 배포: `firebase deploy --only functions:describe`(기존 OPENAI_API_KEY 시크릿 재사용).
- 기능 실기기 검증 후에만 스토어 설명에 "AI 사진 이름·태그" 기재.

- [ ] **Step 7: 브랜치 마무리**

`superpowers:finishing-a-development-branch` 스킬로 병합/PR 여부 결정.
