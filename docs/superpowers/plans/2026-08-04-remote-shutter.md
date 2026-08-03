# 리모컨 촬영 (2대 연결) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 같은 Wi-Fi의 폰 2대를 연결해 한 대(호스트)로 촬영하고 다른 한 대(리모컨)에서 실시간 프리뷰를 보며 셔터·줌·전환·타이머를 제어한다.

**Architecture:** 호스트가 앱 내 `dart:io` WebSocket 서버를 열고 리모컨이 QR(ip·port·토큰)로 접속. 프리뷰는 ML 분석용 카메라 프레임을 재사용해 ~480p JPEG 10~12fps 전송, 명령은 JSON 메시지. 프로토콜·상태머신·인코더는 순수 Dart로 TDD, 소켓은 루프백 통합 테스트, 화면은 실기기 수동 검증.

**Tech Stack:** Flutter/Dart, `dart:io` WebSocket, `image`(기존), `qr_flutter`(신규), `mobile_scanner`(신규)

**Spec:** `docs/superpowers/specs/2026-08-04-remote-shutter-design.md`

## Global Constraints

- Flutter SDK: `/Users/soonbok/flutter/bin` (flutter/dart 모두 PATH에 존재)
- `lib/remote/protocol/`은 **순수 Dart** — Flutter/plugin/`dart:io` import 금지. TDD 대상.
- `flutter analyze` 금지 → **`dart analyze lib test`** 사용 (한글 디렉토리명 크래시 회피)
- 정렬 판정 문자열은 `'좋아요'` 규약 유지 (리모컨 배지도 동일 문구)
- 커밋: Conventional Commits (`feat:`/`test:`/`chore:`)
- 완료 게이트: `tool/verify.sh` 통과
- 프로토콜 버전 `1`, 프리뷰 긴 변 `480px`·JPEG 품질 `60`·전송 간격 `80ms`, ping 간격 `3초`·무응답 `3회`면 사망 판정, 재접속 `1초 × 5회`
- 사진은 호스트 갤러리에만 저장. 리모컨에는 긴 변 `320px` 썸네일만 전송.

---

### Task 1: 페어링 페이로드 (QR 문자열)

**Files:**
- Create: `lib/remote/protocol/pairing_payload.dart`
- Test: `test/remote/pairing_payload_test.dart`

**Interfaces:**
- Produces: `class PairingPayload { final String host; final int port; final String token; String encode(); static PairingPayload? decode(String raw); }`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/remote/pairing_payload_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/remote/protocol/pairing_payload.dart';

void main() {
  test('encode → decode 라운드트립', () {
    const p = PairingPayload(host: '192.168.0.7', port: 40321, token: 'a1b2c3d4e5f60718');
    final decoded = PairingPayload.decode(p.encode());
    expect(decoded, isNotNull);
    expect(decoded!.host, '192.168.0.7');
    expect(decoded.port, 40321);
    expect(decoded.token, 'a1b2c3d4e5f60718');
  });

  test('encode 형식은 ttongson-remote:v1:<host>:<port>:<token>', () {
    const p = PairingPayload(host: '10.0.0.2', port: 8080, token: 'tok');
    expect(p.encode(), 'ttongson-remote:v1:10.0.0.2:8080:tok');
  });

  test('스킴/버전이 다르거나 조각이 모자라면 null', () {
    expect(PairingPayload.decode('https://example.com'), isNull);
    expect(PairingPayload.decode('ttongson-remote:v2:1.2.3.4:80:tok'), isNull);
    expect(PairingPayload.decode('ttongson-remote:v1:1.2.3.4:80'), isNull);
    expect(PairingPayload.decode('ttongson-remote:v1:1.2.3.4:notaport:tok'), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/remote/pairing_payload_test.dart`
Expected: FAIL — `pairing_payload.dart` 없음 (컴파일 에러)

- [ ] **Step 3: 최소 구현**

```dart
// lib/remote/protocol/pairing_payload.dart
// 순수 Dart — Flutter/plugin/dart:io import 금지.

/// QR에 담기는 페어링 정보. 형식: ttongson-remote:v1:<host>:<port>:<token>
class PairingPayload {
  final String host;
  final int port;
  final String token;

  const PairingPayload({
    required this.host,
    required this.port,
    required this.token,
  });

  static const String _scheme = 'ttongson-remote';
  static const int _version = 1;

  String encode() => '$_scheme:v$_version:$host:$port:$token';

  /// 형식이 어긋나면 null (스캔한 QR이 우리 것이 아닐 수 있음).
  static PairingPayload? decode(String raw) {
    final parts = raw.split(':');
    if (parts.length != 5) return null;
    if (parts[0] != _scheme || parts[1] != 'v$_version') return null;
    final port = int.tryParse(parts[3]);
    if (port == null || port <= 0 || port > 65535) return null;
    if (parts[2].isEmpty || parts[4].isEmpty) return null;
    return PairingPayload(host: parts[2], port: port, token: parts[4]);
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/remote/pairing_payload_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/remote/protocol/pairing_payload.dart test/remote/pairing_payload_test.dart
git commit -m "feat: 리모컨 페어링 QR 페이로드 인코딩/디코딩"
```

---

### Task 2: 프로토콜 메시지 직렬화

**Files:**
- Create: `lib/remote/protocol/remote_message.dart`
- Test: `test/remote/remote_message_test.dart`

**Interfaces:**
- Produces (이후 모든 태스크가 사용):
  - `const int remoteProtocolVersion = 1;`
  - `sealed class RemoteMessage { String encode(); static RemoteMessage? decode(String raw); }`
  - `HelloMessage(token, protocolVersion)`
  - `WelcomeMessage(previewAspectRatio, minZoom, maxZoom, zoom, isFront, mode, protocolVersion)` — mode는 `ShootingMode.wire` 문자열
  - `RejectMessage(reason)` — reason ∈ `'bad-token' | 'busy' | 'version'`
  - `StateMessage(hints: List<String>, zoom, isFront, mode)`
  - `ShutterMessage(seq, timerSeconds)` — timerSeconds ∈ 0/3/5/10
  - `ZoomMessage(seq, zoom)` / `SwitchCameraMessage(seq)`
  - `ResultMessage(seq, ok, {error, thumbBase64})`
  - `PingMessage()` / `PongMessage()`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/remote/remote_message_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/remote/protocol/remote_message.dart';

void main() {
  test('hello 라운드트립', () {
    const m = HelloMessage(token: 'tok', protocolVersion: remoteProtocolVersion);
    final d = RemoteMessage.decode(m.encode());
    expect(d, isA<HelloMessage>());
    expect((d as HelloMessage).token, 'tok');
    expect(d.protocolVersion, 1);
  });

  test('welcome 라운드트립 (double 보존)', () {
    const m = WelcomeMessage(
      previewAspectRatio: 0.5625,
      minZoom: 1.0,
      maxZoom: 8.0,
      zoom: 2.5,
      isFront: false,
      mode: 'person',
      protocolVersion: remoteProtocolVersion,
    );
    final d = RemoteMessage.decode(m.encode()) as WelcomeMessage;
    expect(d.previewAspectRatio, closeTo(0.5625, 1e-9));
    expect(d.maxZoom, 8.0);
    expect(d.mode, 'person');
  });

  test('state 라운드트립 (hints 리스트)', () {
    const m = StateMessage(
        hints: ['왼쪽으로 기울었어요'], zoom: 1.0, isFront: true, mode: 'person');
    final d = RemoteMessage.decode(m.encode()) as StateMessage;
    expect(d.hints, ['왼쪽으로 기울었어요']);
    expect(d.isFront, isTrue);
  });

  test('명령·결과 라운드트립', () {
    final shutter = RemoteMessage.decode(
        const ShutterMessage(seq: 7, timerSeconds: 5).encode()) as ShutterMessage;
    expect(shutter.seq, 7);
    expect(shutter.timerSeconds, 5);

    final zoom =
        RemoteMessage.decode(const ZoomMessage(seq: 8, zoom: 3.0).encode())
            as ZoomMessage;
    expect(zoom.zoom, 3.0);

    final sw = RemoteMessage.decode(const SwitchCameraMessage(seq: 9).encode());
    expect((sw as SwitchCameraMessage).seq, 9);

    final res = RemoteMessage.decode(
            const ResultMessage(seq: 7, ok: false, error: '실패').encode())
        as ResultMessage;
    expect(res.ok, isFalse);
    expect(res.error, '실패');
    expect(res.thumbBase64, isNull);
  });

  test('ping/pong/reject', () {
    expect(RemoteMessage.decode(const PingMessage().encode()), isA<PingMessage>());
    expect(RemoteMessage.decode(const PongMessage().encode()), isA<PongMessage>());
    final r = RemoteMessage.decode(const RejectMessage(reason: 'bad-token').encode());
    expect((r as RejectMessage).reason, 'bad-token');
  });

  test('깨진 입력은 null (예외 없음)', () {
    expect(RemoteMessage.decode('not json'), isNull);
    expect(RemoteMessage.decode('{"type":"unknown"}'), isNull);
    expect(RemoteMessage.decode('{"type":"shutter"}'), isNull); // 필드 누락
    expect(RemoteMessage.decode('[1,2]'), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/remote/remote_message_test.dart`
Expected: FAIL — 컴파일 에러

- [ ] **Step 3: 최소 구현**

```dart
// lib/remote/protocol/remote_message.dart
// 순수 Dart — Flutter/plugin/dart:io import 금지.
import 'dart:convert';

/// 프로토콜 버전. hello/welcome에 실어 불일치 시 reject한다.
const int remoteProtocolVersion = 1;

sealed class RemoteMessage {
  const RemoteMessage();

  String get type;
  Map<String, dynamic> fields();

  String encode() => jsonEncode({'type': type, ...fields()});

  /// 깨진/모르는 메시지는 null 반환(호출측이 무시). 예외를 던지지 않는다.
  static RemoteMessage? decode(String raw) {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (parsed is! Map<String, dynamic>) return null;
    try {
      switch (parsed['type']) {
        case 'hello':
          return HelloMessage(
            token: parsed['token'] as String,
            protocolVersion: parsed['protocolVersion'] as int,
          );
        case 'welcome':
          return WelcomeMessage(
            previewAspectRatio: (parsed['previewAspectRatio'] as num).toDouble(),
            minZoom: (parsed['minZoom'] as num).toDouble(),
            maxZoom: (parsed['maxZoom'] as num).toDouble(),
            zoom: (parsed['zoom'] as num).toDouble(),
            isFront: parsed['isFront'] as bool,
            mode: parsed['mode'] as String,
            protocolVersion: parsed['protocolVersion'] as int,
          );
        case 'reject':
          return RejectMessage(reason: parsed['reason'] as String);
        case 'state':
          return StateMessage(
            hints: (parsed['hints'] as List).cast<String>(),
            zoom: (parsed['zoom'] as num).toDouble(),
            isFront: parsed['isFront'] as bool,
            mode: parsed['mode'] as String,
          );
        case 'shutter':
          return ShutterMessage(
            seq: parsed['seq'] as int,
            timerSeconds: parsed['timerSeconds'] as int,
          );
        case 'zoom':
          return ZoomMessage(
            seq: parsed['seq'] as int,
            zoom: (parsed['zoom'] as num).toDouble(),
          );
        case 'switchCamera':
          return SwitchCameraMessage(seq: parsed['seq'] as int);
        case 'result':
          return ResultMessage(
            seq: parsed['seq'] as int,
            ok: parsed['ok'] as bool,
            error: parsed['error'] as String?,
            thumbBase64: parsed['thumbBase64'] as String?,
          );
        case 'ping':
          return const PingMessage();
        case 'pong':
          return const PongMessage();
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}

class HelloMessage extends RemoteMessage {
  final String token;
  final int protocolVersion;
  const HelloMessage({required this.token, required this.protocolVersion});
  @override
  String get type => 'hello';
  @override
  Map<String, dynamic> fields() =>
      {'token': token, 'protocolVersion': protocolVersion};
}

class WelcomeMessage extends RemoteMessage {
  /// 세로 화면 기준 width/height (예: 9/16 = 0.5625). 리모컨 레터박스용.
  final double previewAspectRatio;
  final double minZoom;
  final double maxZoom;
  final double zoom;
  final bool isFront;
  final String mode; // ShootingMode.wire
  final int protocolVersion;
  const WelcomeMessage({
    required this.previewAspectRatio,
    required this.minZoom,
    required this.maxZoom,
    required this.zoom,
    required this.isFront,
    required this.mode,
    required this.protocolVersion,
  });
  @override
  String get type => 'welcome';
  @override
  Map<String, dynamic> fields() => {
        'previewAspectRatio': previewAspectRatio,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'zoom': zoom,
        'isFront': isFront,
        'mode': mode,
        'protocolVersion': protocolVersion,
      };
}

class RejectMessage extends RemoteMessage {
  /// 'bad-token' | 'busy' | 'version'
  final String reason;
  const RejectMessage({required this.reason});
  @override
  String get type => 'reject';
  @override
  Map<String, dynamic> fields() => {'reason': reason};
}

class StateMessage extends RemoteMessage {
  final List<String> hints; // GuideMetrics.activeHints (비면 '좋아요' 상태)
  final double zoom;
  final bool isFront;
  final String mode;
  const StateMessage({
    required this.hints,
    required this.zoom,
    required this.isFront,
    required this.mode,
  });
  @override
  String get type => 'state';
  @override
  Map<String, dynamic> fields() =>
      {'hints': hints, 'zoom': zoom, 'isFront': isFront, 'mode': mode};
}

class ShutterMessage extends RemoteMessage {
  final int seq;
  final int timerSeconds; // 0/3/5/10
  const ShutterMessage({required this.seq, required this.timerSeconds});
  @override
  String get type => 'shutter';
  @override
  Map<String, dynamic> fields() => {'seq': seq, 'timerSeconds': timerSeconds};
}

class ZoomMessage extends RemoteMessage {
  final int seq;
  final double zoom;
  const ZoomMessage({required this.seq, required this.zoom});
  @override
  String get type => 'zoom';
  @override
  Map<String, dynamic> fields() => {'seq': seq, 'zoom': zoom};
}

class SwitchCameraMessage extends RemoteMessage {
  final int seq;
  const SwitchCameraMessage({required this.seq});
  @override
  String get type => 'switchCamera';
  @override
  Map<String, dynamic> fields() => {'seq': seq};
}

class ResultMessage extends RemoteMessage {
  final int seq;
  final bool ok;
  final String? error;
  final String? thumbBase64; // 촬영 성공 시 320px 썸네일
  const ResultMessage({
    required this.seq,
    required this.ok,
    this.error,
    this.thumbBase64,
  });
  @override
  String get type => 'result';
  @override
  Map<String, dynamic> fields() => {
        'seq': seq,
        'ok': ok,
        if (error != null) 'error': error,
        if (thumbBase64 != null) 'thumbBase64': thumbBase64,
      };
}

class PingMessage extends RemoteMessage {
  const PingMessage();
  @override
  String get type => 'ping';
  @override
  Map<String, dynamic> fields() => const {};
}

class PongMessage extends RemoteMessage {
  const PongMessage();
  @override
  String get type => 'pong';
  @override
  Map<String, dynamic> fields() => const {};
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/remote/remote_message_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/remote/protocol/remote_message.dart test/remote/remote_message_test.dart
git commit -m "feat: 리모컨 프로토콜 메시지 모델과 JSON 직렬화"
```

---

### Task 3: 세션 보조 로직 (배압 버퍼·생존 판정·재접속 정책)

**Files:**
- Create: `lib/remote/protocol/remote_session.dart`
- Test: `test/remote/remote_session_test.dart`

**Interfaces:**
- Produces:
  - `class LatestFrameBuffer { void push(List<int> frame); List<int>? take(); int get dropped; }`
  - `class ConnectionHealth { ConnectionHealth({int maxMissed = 3}); void onPingSent(); void onActivity(); bool get isDead; }`
  - `class ReconnectPolicy { ReconnectPolicy({int maxAttempts = 5, Duration delay = const Duration(seconds: 1)}); Duration? next(); void reset(); bool get exhausted; }`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/remote/remote_session_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/remote/protocol/remote_session.dart';

void main() {
  group('LatestFrameBuffer', () {
    test('최신 프레임만 유지하고 밀린 프레임은 드롭 카운트', () {
      final buf = LatestFrameBuffer();
      expect(buf.take(), isNull);
      buf.push([1]);
      buf.push([2]);
      buf.push([3]);
      expect(buf.take(), [3]);
      expect(buf.take(), isNull); // 소비 후 비움
      expect(buf.dropped, 2);
    });
  });

  group('ConnectionHealth', () {
    test('ping 3회 무응답이면 사망, 수신 활동이 있으면 리셋', () {
      final h = ConnectionHealth();
      h.onPingSent();
      h.onPingSent();
      expect(h.isDead, isFalse);
      h.onActivity(); // pong 또는 아무 메시지
      h.onPingSent();
      h.onPingSent();
      h.onPingSent();
      expect(h.isDead, isTrue);
    });
  });

  group('ReconnectPolicy', () {
    test('1초 간격 5회 후 소진', () {
      final p = ReconnectPolicy();
      final delays = <Duration>[];
      for (Duration? d = p.next(); d != null; d = p.next()) {
        delays.add(d);
      }
      expect(delays, List.filled(5, const Duration(seconds: 1)));
      expect(p.exhausted, isTrue);
      p.reset();
      expect(p.exhausted, isFalse);
      expect(p.next(), const Duration(seconds: 1));
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/remote/remote_session_test.dart`
Expected: FAIL — 컴파일 에러

- [ ] **Step 3: 최소 구현**

```dart
// lib/remote/protocol/remote_session.dart
// 순수 Dart — Flutter/plugin/dart:io import 금지.

/// 전송이 밀리면 오래된 프리뷰 프레임을 버리고 최신 것만 보내기 위한 1칸 버퍼.
class LatestFrameBuffer {
  List<int>? _pending;
  int _dropped = 0;

  int get dropped => _dropped;

  void push(List<int> frame) {
    if (_pending != null) _dropped++;
    _pending = frame;
  }

  /// 대기 중인 최신 프레임을 꺼내고 버퍼를 비운다. 없으면 null.
  List<int>? take() {
    final f = _pending;
    _pending = null;
    return f;
  }
}

/// ping 무응답 카운트로 상대 생존을 판정한다.
/// onPingSent()가 maxMissed회 누적되는 동안 onActivity()가 없으면 사망.
class ConnectionHealth {
  ConnectionHealth({this.maxMissed = 3});

  final int maxMissed;
  int _missed = 0;

  void onPingSent() => _missed++;
  void onActivity() => _missed = 0;
  bool get isDead => _missed >= maxMissed;
}

/// 리모컨의 자동 재접속 정책: delay 간격으로 maxAttempts회.
class ReconnectPolicy {
  ReconnectPolicy({
    this.maxAttempts = 5,
    this.delay = const Duration(seconds: 1),
  });

  final int maxAttempts;
  final Duration delay;
  int _attempt = 0;

  bool get exhausted => _attempt >= maxAttempts;

  /// 다음 시도까지 대기 시간. 소진되면 null.
  Duration? next() {
    if (exhausted) return null;
    _attempt++;
    return delay;
  }

  void reset() => _attempt = 0;
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/remote/remote_session_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/remote/protocol/remote_session.dart test/remote/remote_session_test.dart
git commit -m "feat: 리모컨 세션 보조 로직(배압 버퍼·생존 판정·재접속 정책)"
```

---

### Task 4: 프리뷰 프레임 인코더 (YUV/BGRA → 축소 JPEG)

**Files:**
- Create: `lib/remote/frame_encoder.dart`
- Test: `test/remote/frame_encoder_test.dart`

**Interfaces:**
- Consumes: `fitWithin(int, int, int)` — `lib/cloud/advice_image.dart` (순수 함수)
- Produces:
  - `img.Image imageFromBgra8888({required int width, required int height, required Uint8List bytes, required int bytesPerRow})`
  - `img.Image imageFromNv21({required int width, required int height, required Uint8List nv21})`
  - `Uint8List encodePreviewJpeg(img.Image src, {int maxLongEdge = 480, int quality = 60, int rotationDegrees = 0, bool mirror = false})`

참고: `frame_encoder.dart`는 `protocol/` 밖이므로 `package:image` 사용 가능(순수 Dart 패키지). Flutter/camera plugin은 import하지 않는다 — CameraImage 어댑터는 Task 7의 `host_controller.dart` 소관.

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/remote/frame_encoder_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ttongson_camera/remote/frame_encoder.dart';

void main() {
  test('BGRA: 2x1 픽셀 값과 stride 처리', () {
    // 1행 stride 12바이트(8바이트 픽셀 + 4바이트 패딩). B,G,R,A 순.
    final bytes = Uint8List.fromList([
      255, 0, 0, 255, // 파랑
      0, 255, 0, 255, // 초록
      0, 0, 0, 0, // 패딩
    ]);
    final im = imageFromBgra8888(width: 2, height: 1, bytes: bytes, bytesPerRow: 12);
    expect(im.width, 2);
    final p0 = im.getPixel(0, 0);
    expect([p0.r, p0.g, p0.b], [0, 0, 255]);
    final p1 = im.getPixel(1, 0);
    expect([p1.r, p1.g, p1.b], [0, 255, 0]);
  });

  test('NV21: 회색(Y=128,U=V=128)은 RGB(128,128,128)', () {
    // 2x2: Y 4바이트 + VU 2바이트
    final nv21 = Uint8List.fromList([128, 128, 128, 128, 128, 128]);
    final im = imageFromNv21(width: 2, height: 2, nv21: nv21);
    final p = im.getPixel(1, 1);
    expect([p.r, p.g, p.b], [128, 128, 128]);
  });

  test('encodePreviewJpeg: 긴 변 480 축소 + 유효한 JPEG', () {
    final src = img.Image(width: 1920, height: 1080);
    final jpeg = encodePreviewJpeg(src);
    final decoded = img.decodeJpg(jpeg);
    expect(decoded, isNotNull);
    expect(decoded!.width, 480);
    expect(decoded.height, 270);
  });

  test('encodePreviewJpeg: 회전 90도면 가로세로 교환', () {
    final src = img.Image(width: 1920, height: 1080);
    final jpeg = encodePreviewJpeg(src, rotationDegrees: 90);
    final decoded = img.decodeJpg(jpeg)!;
    expect(decoded.width, 270);
    expect(decoded.height, 480);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/remote/frame_encoder_test.dart`
Expected: FAIL — 컴파일 에러

- [ ] **Step 3: 최소 구현**

```dart
// lib/remote/frame_encoder.dart
// 카메라 프레임(BGRA8888/NV21)을 리모컨 프리뷰용 축소 JPEG로 변환한다.
// 순수 Dart(package:image) — Flutter/camera plugin import 금지.
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../cloud/advice_image.dart' show fitWithin;

/// iOS BGRA8888 프레임 → 이미지. bytesPerRow의 행 패딩을 건너뛴다.
img.Image imageFromBgra8888({
  required int width,
  required int height,
  required Uint8List bytes,
  required int bytesPerRow,
}) {
  final out = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    final row = y * bytesPerRow;
    for (var x = 0; x < width; x++) {
      final i = row + x * 4;
      out.setPixelRgb(x, y, bytes[i + 2], bytes[i + 1], bytes[i]);
    }
  }
  return out;
}

/// Android NV21 프레임 → 이미지. full-range BT.601 근사.
img.Image imageFromNv21({
  required int width,
  required int height,
  required Uint8List nv21,
}) {
  final out = img.Image(width: width, height: height);
  final ySize = width * height;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final yy = nv21[y * width + x];
      final vuIndex = ySize + (y >> 1) * width + (x & ~1);
      final v = nv21[vuIndex] - 128;
      final u = nv21[vuIndex + 1] - 128;
      final r = (yy + 1.402 * v).round().clamp(0, 255);
      final g = (yy - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
      final b = (yy + 1.772 * u).round().clamp(0, 255);
      out.setPixelRgb(x, y, r, g, b);
    }
  }
  return out;
}

/// 회전 → 반전 → 축소 → JPEG 인코딩.
Uint8List encodePreviewJpeg(
  img.Image src, {
  int maxLongEdge = 480,
  int quality = 60,
  int rotationDegrees = 0,
  bool mirror = false,
}) {
  var im = src;
  if (rotationDegrees != 0) {
    im = img.copyRotate(im, angle: rotationDegrees);
  }
  if (mirror) {
    im = img.flipHorizontal(im);
  }
  final target = fitWithin(im.width, im.height, maxLongEdge);
  if (target.width != im.width || target.height != im.height) {
    im = img.copyResize(im, width: target.width, height: target.height);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/remote/frame_encoder_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/remote/frame_encoder.dart test/remote/frame_encoder_test.dart
git commit -m "feat: 리모컨 프리뷰 프레임 인코더(BGRA/NV21→축소 JPEG)"
```

---

### Task 5: 호스트 WebSocket 서버

**Files:**
- Create: `lib/remote/transport/remote_server.dart`
- Create: `lib/remote/transport/local_network.dart`
- Test: `test/remote/remote_server_test.dart`

**Interfaces:**
- Consumes: Task 2 메시지들, Task 3 `LatestFrameBuffer`·`ConnectionHealth`
- Produces:
  - `class RemoteServer { RemoteServer({required String token, required WelcomeMessage Function() welcomeBuilder}); Future<int> start(); int get port; bool get hasClient; void Function(RemoteMessage)? onCommand; void Function(bool connected)? onClientChanged; void sendFrame(List<int> jpeg); void sendMessage(RemoteMessage m); Future<void> stop(); }`
  - `Future<String?> localIpv4()` / `String generateToken()` (local_network.dart)

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/remote/remote_server_test.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/remote/protocol/remote_message.dart';
import 'package:ttongson_camera/remote/transport/local_network.dart';
import 'package:ttongson_camera/remote/transport/remote_server.dart';

WelcomeMessage _welcome() => const WelcomeMessage(
      previewAspectRatio: 0.5625,
      minZoom: 1.0,
      maxZoom: 4.0,
      zoom: 1.0,
      isFront: false,
      mode: 'person',
      protocolVersion: remoteProtocolVersion,
    );

Future<WebSocket> _connect(int port) =>
    WebSocket.connect('ws://127.0.0.1:$port');

void main() {
  late RemoteServer server;

  tearDown(() async => server.stop());

  test('올바른 토큰의 hello에 welcome으로 응답한다', () async {
    server = RemoteServer(token: 'good', welcomeBuilder: _welcome);
    final port = await server.start();
    final ws = await _connect(port);
    ws.add(const HelloMessage(token: 'good', protocolVersion: 1).encode());
    final first = RemoteMessage.decode(await ws.first as String);
    expect(first, isA<WelcomeMessage>());
    expect(server.hasClient, isTrue);
    await ws.close();
  });

  test('틀린 토큰은 reject(bad-token) 후 연결 종료', () async {
    server = RemoteServer(token: 'good', welcomeBuilder: _welcome);
    final port = await server.start();
    final ws = await _connect(port);
    ws.add(const HelloMessage(token: 'evil', protocolVersion: 1).encode());
    final first = RemoteMessage.decode(await ws.first as String);
    expect((first as RejectMessage).reason, 'bad-token');
    await ws.done; // 서버가 닫음
    expect(server.hasClient, isFalse);
  });

  test('두 번째 클라이언트는 reject(busy)', () async {
    server = RemoteServer(token: 'good', welcomeBuilder: _welcome);
    final port = await server.start();
    final first = await _connect(port);
    first.add(const HelloMessage(token: 'good', protocolVersion: 1).encode());
    await first.first; // welcome 소비
    final second = await _connect(port);
    second.add(const HelloMessage(token: 'good', protocolVersion: 1).encode());
    final msg = RemoteMessage.decode(await second.first as String);
    expect((msg as RejectMessage).reason, 'busy');
    await first.close();
  });

  test('명령은 onCommand로 전달되고 sendMessage/sendFrame이 도착한다', () async {
    server = RemoteServer(token: 'good', welcomeBuilder: _welcome);
    final port = await server.start();
    final received = Completer<RemoteMessage>();
    server.onCommand = (m) => received.complete(m);

    final ws = await _connect(port);
    final inbox = StreamQueue(ws);
    ws.add(const HelloMessage(token: 'good', protocolVersion: 1).encode());
    await inbox.next; // welcome

    ws.add(const ShutterMessage(seq: 1, timerSeconds: 0).encode());
    expect(await received.future, isA<ShutterMessage>());

    server.sendMessage(const ResultMessage(seq: 1, ok: true));
    final res = RemoteMessage.decode(await inbox.next as String);
    expect((res as ResultMessage).ok, isTrue);

    server.sendFrame([1, 2, 3]);
    final frame = await inbox.next;
    expect(frame, isA<List<int>>());
    expect(frame, [1, 2, 3]);
    await ws.close();
  });

  test('generateToken은 32자 hex, 호출마다 다름', () {
    final a = generateToken();
    final b = generateToken();
    expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(a == b, isFalse);
  });
}

/// 테스트 편의: 스트림을 순서대로 꺼내는 최소 큐.
class StreamQueue {
  final StreamIterator<dynamic> _it;
  StreamQueue(Stream<dynamic> s) : _it = StreamIterator(s);
  Future<dynamic> get next async {
    if (!await _it.moveNext()) throw StateError('stream closed');
    return _it.current;
  }
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/remote/remote_server_test.dart`
Expected: FAIL — 컴파일 에러

- [ ] **Step 3: 구현**

```dart
// lib/remote/transport/local_network.dart
import 'dart:io';
import 'dart:math';

/// QR에 넣을 이 기기의 IPv4 주소. Wi-Fi/핫스팟 인터페이스의 첫 비루프백 주소.
Future<String?> localIpv4() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  for (final ni in interfaces) {
    for (final addr in ni.addresses) {
      if (!addr.isLoopback) return addr.address;
    }
  }
  return null;
}

/// 일회용 페어링 토큰(16바이트 hex).
String generateToken() {
  final rnd = Random.secure();
  return List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
```

```dart
// lib/remote/transport/remote_server.dart
// 촬영 폰(호스트)의 WebSocket 서버. 클라이언트 1대만 허용. 판단 없음: 중계만.
import 'dart:async';
import 'dart:io';

import '../protocol/remote_message.dart';
import '../protocol/remote_session.dart';

class RemoteServer {
  RemoteServer({
    required this.token,
    required this.welcomeBuilder,
    this.frameInterval = const Duration(milliseconds: 80),
    this.pingInterval = const Duration(seconds: 3),
  });

  final String token;
  final WelcomeMessage Function() welcomeBuilder;
  final Duration frameInterval;
  final Duration pingInterval;

  /// 인증된 클라이언트의 명령(shutter/zoom/switchCamera) 수신 콜백.
  void Function(RemoteMessage message)? onCommand;

  /// 클라이언트 접속/이탈 알림.
  void Function(bool connected)? onClientChanged;

  HttpServer? _http;
  WebSocket? _client;
  Timer? _frameTimer;
  Timer? _pingTimer;
  final LatestFrameBuffer _frames = LatestFrameBuffer();
  final ConnectionHealth _health = ConnectionHealth();

  int get port => _http?.port ?? 0;
  bool get hasClient => _client != null;

  Future<int> start() async {
    final http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _http = http;
    http.listen(_onRequest);
    _frameTimer = Timer.periodic(frameInterval, (_) => _flushFrame());
    _pingTimer = Timer.periodic(pingInterval, (_) => _pingTick());
    return http.port;
  }

  Future<void> _onRequest(HttpRequest req) async {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response.statusCode = HttpStatus.badRequest;
      await req.response.close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(req);
    var authenticated = false;
    ws.listen(
      (data) {
        if (data is! String) return;
        final msg = RemoteMessage.decode(data);
        if (msg == null) return;
        if (!authenticated) {
          authenticated = _handleHello(ws, msg);
          return;
        }
        if (!identical(ws, _client)) return;
        _health.onActivity();
        switch (msg) {
          case PongMessage():
            break;
          case ShutterMessage() || ZoomMessage() || SwitchCameraMessage():
            onCommand?.call(msg);
          default:
            break;
        }
      },
      onDone: () => _onSocketClosed(ws),
      onError: (_) => _onSocketClosed(ws),
    );
  }

  /// 첫 메시지는 hello여야 한다. 성공 시 true(인증됨).
  bool _handleHello(WebSocket ws, RemoteMessage msg) {
    if (msg is! HelloMessage) {
      ws.close();
      return false;
    }
    if (_client != null) {
      ws.add(const RejectMessage(reason: 'busy').encode());
      ws.close();
      return false;
    }
    if (msg.protocolVersion != remoteProtocolVersion) {
      ws.add(const RejectMessage(reason: 'version').encode());
      ws.close();
      return false;
    }
    if (msg.token != token) {
      ws.add(const RejectMessage(reason: 'bad-token').encode());
      ws.close();
      return false;
    }
    _client = ws;
    _health.onActivity();
    ws.add(welcomeBuilder().encode());
    onClientChanged?.call(true);
    return true;
  }

  void _onSocketClosed(WebSocket ws) {
    if (identical(ws, _client)) {
      _client = null;
      onClientChanged?.call(false);
    }
  }

  /// 최신 프레임을 큐잉한다(전송은 frameInterval 틱마다 최신 것만).
  void sendFrame(List<int> jpeg) => _frames.push(jpeg);

  void sendMessage(RemoteMessage m) => _client?.add(m.encode());

  void _flushFrame() {
    final client = _client;
    if (client == null) {
      _frames.take(); // 접속 없으면 버림
      return;
    }
    final frame = _frames.take();
    if (frame != null) client.add(frame);
  }

  void _pingTick() {
    final client = _client;
    if (client == null) return;
    if (_health.isDead) {
      client.close();
      _onSocketClosed(client);
      return;
    }
    _health.onPingSent();
    client.add(const PingMessage().encode());
  }

  Future<void> stop() async {
    _frameTimer?.cancel();
    _pingTimer?.cancel();
    await _client?.close();
    _client = null;
    await _http?.close(force: true);
    _http = null;
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/remote/remote_server_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/remote/transport/remote_server.dart lib/remote/transport/local_network.dart test/remote/remote_server_test.dart
git commit -m "feat: 리모컨 호스트 WebSocket 서버(토큰 인증·1대 제한·프레임 배압)"
```

---

### Task 6: 리모컨 클라이언트

**Files:**
- Create: `lib/remote/transport/remote_client.dart`
- Test: `test/remote/remote_client_test.dart`

**Interfaces:**
- Consumes: Task 2 메시지, Task 5 `RemoteServer`(테스트 상대)
- Produces:
  - `class RemoteRejectedException implements Exception { final String reason; }`
  - `class RemoteClient { Future<WelcomeMessage> connect(PairingPayload payload, {Duration timeout = const Duration(seconds: 5)}); Stream<RemoteMessage> get messages; Stream<List<int>> get frames; void send(RemoteMessage m); bool get isConnected; Future<void> close(); void Function()? onDisconnected; }`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/remote/remote_client_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/remote/protocol/pairing_payload.dart';
import 'package:ttongson_camera/remote/protocol/remote_message.dart';
import 'package:ttongson_camera/remote/transport/remote_client.dart';
import 'package:ttongson_camera/remote/transport/remote_server.dart';

WelcomeMessage _welcome() => const WelcomeMessage(
      previewAspectRatio: 0.5625,
      minZoom: 1.0,
      maxZoom: 4.0,
      zoom: 1.0,
      isFront: false,
      mode: 'person',
      protocolVersion: remoteProtocolVersion,
    );

PairingPayload _payload(int port, [String token = 'good']) =>
    PairingPayload(host: '127.0.0.1', port: port, token: token);

void main() {
  late RemoteServer server;
  late RemoteClient client;

  setUp(() {
    server = RemoteServer(token: 'good', welcomeBuilder: _welcome);
    client = RemoteClient();
  });

  tearDown(() async {
    await client.close();
    await server.stop();
  });

  test('connect는 welcome을 반환한다', () async {
    final port = await server.start();
    final welcome = await client.connect(_payload(port));
    expect(welcome.maxZoom, 4.0);
    expect(client.isConnected, isTrue);
  });

  test('토큰 불일치는 RemoteRejectedException(bad-token)', () async {
    final port = await server.start();
    await expectLater(
      client.connect(_payload(port, 'evil')),
      throwsA(isA<RemoteRejectedException>()
          .having((e) => e.reason, 'reason', 'bad-token')),
    );
  });

  test('명령 왕복: shutter → 서버 onCommand → result 수신, 프레임 수신', () async {
    final port = await server.start();
    server.onCommand = (m) {
      if (m is ShutterMessage) {
        server.sendMessage(ResultMessage(seq: m.seq, ok: true));
      }
    };
    await client.connect(_payload(port));

    final result = client.messages.firstWhere((m) => m is ResultMessage);
    client.send(const ShutterMessage(seq: 1, timerSeconds: 0));
    expect(((await result) as ResultMessage).ok, isTrue);

    final frame = client.frames.first;
    server.sendFrame([9, 8, 7]);
    expect(await frame, [9, 8, 7]);
  });

  test('서버가 닫히면 onDisconnected 호출', () async {
    final port = await server.start();
    await client.connect(_payload(port));
    final disconnected = Completer<void>();
    client.onDisconnected = () => disconnected.complete();
    await server.stop();
    await disconnected.future.timeout(const Duration(seconds: 5));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/remote/remote_client_test.dart`
Expected: FAIL — 컴파일 에러

- [ ] **Step 3: 구현**

```dart
// lib/remote/transport/remote_client.dart
// 리모컨 폰의 WebSocket 클라이언트. 판단 없음: 접속·중계만.
import 'dart:async';
import 'dart:io';

import '../protocol/pairing_payload.dart';
import '../protocol/remote_message.dart';

class RemoteRejectedException implements Exception {
  final String reason; // 'bad-token' | 'busy' | 'version'
  RemoteRejectedException(this.reason);
  @override
  String toString() => 'RemoteRejectedException: $reason';
}

class RemoteClient {
  WebSocket? _ws;
  final _messages = StreamController<RemoteMessage>.broadcast();
  final _frames = StreamController<List<int>>.broadcast();

  /// welcome 이후의 서버 메시지(state/result 등. ping은 내부에서 pong 처리).
  Stream<RemoteMessage> get messages => _messages.stream;

  /// JPEG 프리뷰 프레임.
  Stream<List<int>> get frames => _frames.stream;

  bool get isConnected => _ws != null;

  void Function()? onDisconnected;

  /// 접속·인증 후 welcome을 반환. 거부되면 RemoteRejectedException,
  /// 네트워크 문제면 SocketException/TimeoutException.
  Future<WelcomeMessage> connect(
    PairingPayload payload, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final ws = await WebSocket.connect('ws://${payload.host}:${payload.port}')
        .timeout(timeout);
    _ws = ws;
    final welcome = Completer<WelcomeMessage>();
    ws.listen(
      (data) {
        if (data is! String) {
          if (welcome.isCompleted) _frames.add((data as List).cast<int>());
          return;
        }
        final msg = RemoteMessage.decode(data);
        if (msg == null) return;
        if (!welcome.isCompleted) {
          switch (msg) {
            case WelcomeMessage():
              welcome.complete(msg);
            case RejectMessage():
              welcome.completeError(RemoteRejectedException(msg.reason));
            default:
              break;
          }
          return;
        }
        if (msg is PingMessage) {
          ws.add(const PongMessage().encode());
          return;
        }
        _messages.add(msg);
      },
      onDone: _handleClosed,
      onError: (_) => _handleClosed(),
    );
    ws.add(HelloMessage(
      token: payload.token,
      protocolVersion: remoteProtocolVersion,
    ).encode());
    try {
      return await welcome.future.timeout(timeout);
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void _handleClosed() {
    if (_ws == null) return;
    _ws = null;
    onDisconnected?.call();
  }

  void send(RemoteMessage m) => _ws?.add(m.encode());

  Future<void> close() async {
    final ws = _ws;
    _ws = null;
    await ws?.close();
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/remote/remote_client_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 전체 remote 테스트 회귀 확인 후 커밋**

Run: `flutter test test/remote/`
Expected: 전부 PASS

```bash
git add lib/remote/transport/remote_client.dart test/remote/remote_client_test.dart
git commit -m "feat: 리모컨 클라이언트(접속·인증·명령/프레임 스트림)"
```

---

### Task 7: 호스트 컨트롤러 (카메라 화면 ↔ 서버 다리)

**Files:**
- Create: `lib/remote/host_controller.dart`
- Test: `test/remote/host_controller_test.dart`

**Interfaces:**
- Consumes: Task 2/4/5 전부, `CameraImage`(camera plugin), `encodeDownsizedJpeg`(cloud/advice_image.dart)
- Produces:
  - `class HostController { HostController({required RemoteServer server, required Future<String?> Function(int timerSeconds) onShutter, required Future<double> Function(double zoom) onZoom, required Future<bool> Function() onSwitchCamera}); void pushCameraImage(CameraImage image, {required int rotationDegrees, required bool mirror}); void pushState(StateMessage state); Future<void> dispose(); }`
  - 촬영 성공 시 `ResultMessage`에 320px 썸네일 base64를 실어 보낸다.

- [ ] **Step 1: 실패하는 테스트 작성** (명령 디스패치는 루프백으로 검증. CameraImage 경로는 기기 수동 검증)

```dart
// test/remote/host_controller_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ttongson_camera/remote/host_controller.dart';
import 'package:ttongson_camera/remote/protocol/pairing_payload.dart';
import 'package:ttongson_camera/remote/protocol/remote_message.dart';
import 'package:ttongson_camera/remote/transport/remote_client.dart';
import 'package:ttongson_camera/remote/transport/remote_server.dart';

WelcomeMessage _welcome() => const WelcomeMessage(
      previewAspectRatio: 0.5625,
      minZoom: 1.0,
      maxZoom: 4.0,
      zoom: 1.0,
      isFront: false,
      mode: 'person',
      protocolVersion: remoteProtocolVersion,
    );

void main() {
  late RemoteServer server;
  late RemoteClient client;
  late Directory tmp;

  setUp(() async {
    server = RemoteServer(token: 't', welcomeBuilder: _welcome);
    client = RemoteClient();
    tmp = await Directory.systemTemp.createTemp('host_ctrl');
  });

  tearDown(() async {
    await client.close();
    await server.stop();
    await tmp.delete(recursive: true);
  });

  test('shutter 명령이 onShutter로 오고 result에 썸네일이 실린다', () async {
    // 촬영 결과인 척할 100x50 JPEG 파일 준비
    final shot = File('${tmp.path}/shot.jpg');
    await shot.writeAsBytes(img.encodeJpg(img.Image(width: 100, height: 50)));

    var receivedTimer = -1;
    final controller = HostController(
      server: server,
      onShutter: (timerSeconds) async {
        receivedTimer = timerSeconds;
        return shot.path;
      },
      onZoom: (z) async => z,
      onSwitchCamera: () async => true,
    );
    addTearDown(controller.dispose);

    final port = await server.start();
    await client
        .connect(PairingPayload(host: '127.0.0.1', port: port, token: 't'));

    final resultFuture = client.messages.firstWhere((m) => m is ResultMessage);
    client.send(const ShutterMessage(seq: 3, timerSeconds: 5));
    final result = await resultFuture as ResultMessage;

    expect(receivedTimer, 5);
    expect(result.seq, 3);
    expect(result.ok, isTrue);
    final thumb = img.decodeJpg(base64Decode(result.thumbBase64!))!;
    expect(thumb.width <= 320 && thumb.height <= 320, isTrue);
  });

  test('onShutter가 null(실패)이면 result.ok=false', () async {
    final controller = HostController(
      server: server,
      onShutter: (_) async => null,
      onZoom: (z) async => z,
      onSwitchCamera: () async => true,
    );
    addTearDown(controller.dispose);

    final port = await server.start();
    await client
        .connect(PairingPayload(host: '127.0.0.1', port: port, token: 't'));
    final resultFuture = client.messages.firstWhere((m) => m is ResultMessage);
    client.send(const ShutterMessage(seq: 1, timerSeconds: 0));
    expect((await resultFuture as ResultMessage).ok, isFalse);
  });

  test('zoom·switchCamera 명령도 result로 응답', () async {
    final controller = HostController(
      server: server,
      onShutter: (_) async => null,
      onZoom: (z) async => z.clamp(1.0, 4.0),
      onSwitchCamera: () async => true,
    );
    addTearDown(controller.dispose);

    final port = await server.start();
    await client
        .connect(PairingPayload(host: '127.0.0.1', port: port, token: 't'));

    final r1 = client.messages.firstWhere((m) => m is ResultMessage);
    client.send(const ZoomMessage(seq: 10, zoom: 9.0));
    expect((await r1 as ResultMessage).seq, 10);

    final r2 = client.messages.firstWhere(
        (m) => m is ResultMessage && m.seq == 11);
    client.send(const SwitchCameraMessage(seq: 11));
    expect((await r2 as ResultMessage).ok, isTrue);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/remote/host_controller_test.dart`
Expected: FAIL — 컴파일 에러

- [ ] **Step 3: 구현**

```dart
// lib/remote/host_controller.dart
// 카메라 화면과 RemoteServer를 잇는다. 판단 없음: 인코딩·전달만.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../cloud/advice_image.dart';
import 'frame_encoder.dart';
import 'protocol/remote_message.dart';
import 'transport/remote_server.dart';

class HostController {
  HostController({
    required this.server,
    required this.onShutter,
    required this.onZoom,
    required this.onSwitchCamera,
  }) {
    server.onCommand = _handleCommand;
  }

  final RemoteServer server;

  /// 타이머 카운트다운 → 촬영 → 갤러리 저장까지 마친 뒤 사진 파일 경로 반환.
  /// 실패 시 null.
  final Future<String?> Function(int timerSeconds) onShutter;

  /// 줌 적용 후 실제 배율 반환.
  final Future<double> Function(double zoom) onZoom;

  /// 전/후면 전환. 성공 여부 반환.
  final Future<bool> Function() onSwitchCamera;

  bool _encoding = false;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 프리뷰 프레임 전송. 인코딩 중이거나 80ms 이내 재호출이면 스킵(스로틀).
  void pushCameraImage(
    CameraImage image, {
    required int rotationDegrees,
    required bool mirror,
  }) {
    if (!server.hasClient || _encoding) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameAt).inMilliseconds < 80) return;
    _lastFrameAt = now;
    _encoding = true;

    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    final width = image.width;
    final height = image.height;
    final bytes = Uint8List.fromList(image.planes[0].bytes);
    final bytesPerRow = image.planes[0].bytesPerRow;

    Isolate.run<Uint8List>(() {
      final im = isBgra
          ? imageFromBgra8888(
              width: width,
              height: height,
              bytes: bytes,
              bytesPerRow: bytesPerRow,
            )
          : imageFromNv21(width: width, height: height, nv21: bytes);
      return encodePreviewJpeg(
        im,
        rotationDegrees: rotationDegrees,
        mirror: mirror,
      );
    }).then((jpeg) {
      server.sendFrame(jpeg);
    }).whenComplete(() {
      _encoding = false;
    });
  }

  void pushState(StateMessage state) => server.sendMessage(state);

  Future<void> _handleCommand(RemoteMessage m) async {
    switch (m) {
      case ShutterMessage():
        String? path;
        try {
          path = await onShutter(m.timerSeconds);
        } catch (_) {
          path = null;
        }
        if (path == null) {
          server.sendMessage(
              ResultMessage(seq: m.seq, ok: false, error: '촬영 실패'));
          return;
        }
        server.sendMessage(ResultMessage(
          seq: m.seq,
          ok: true,
          thumbBase64: await _thumbBase64(path),
        ));
      case ZoomMessage():
        try {
          await onZoom(m.zoom);
          server.sendMessage(ResultMessage(seq: m.seq, ok: true));
        } catch (_) {
          server.sendMessage(
              ResultMessage(seq: m.seq, ok: false, error: '줌 실패'));
        }
      case SwitchCameraMessage():
        try {
          final ok = await onSwitchCamera();
          server.sendMessage(ResultMessage(seq: m.seq, ok: ok));
        } catch (_) {
          server.sendMessage(
              ResultMessage(seq: m.seq, ok: false, error: '전환 실패'));
        }
      default:
        break;
    }
  }

  Future<String?> _thumbBase64(String path) async {
    try {
      final thumbPath =
          await encodeDownsizedJpeg(path, maxLongEdge: 320, quality: 60);
      return base64Encode(await File(thumbPath).readAsBytes());
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    server.onCommand = null;
    await server.stop();
  }
}
```

주의: `_handleCommand`를 `server.onCommand`(타입 `void Function(RemoteMessage)?`)에 넣기 위해 async 함수를 그대로 할당한다(반환 Future 무시, fire-and-forget).

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/remote/host_controller_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/remote/host_controller.dart test/remote/host_controller_test.dart
git commit -m "feat: 리모컨 호스트 컨트롤러(명령 디스패치·썸네일 응답·프레임 스로틀)"
```

---

### Task 8: 의존성·iOS 권한·페어링 화면

**Files:**
- Modify: `pubspec.yaml` (dependencies에 2줄 추가)
- Modify: `ios/Runner/Info.plist`
- Create: `lib/screens/remote_pairing_screen.dart`

**Interfaces:**
- Produces:
  - `enum RemoteRole { host, remote }`
  - `class RemotePairingScreen extends StatelessWidget` — `Navigator.pop(context, RemoteRole.host|remote)` 반환
  - `class RemoteHostQrScreen extends StatelessWidget` — `RemoteHostQrScreen({required this.payload})`, QR 표시. 접속되면 호출측이 pop.

- [ ] **Step 1: 의존성 추가**

`pubspec.yaml`의 `dependencies:` 블록 끝(`android_intent_plus: ^5.3.0` 아래)에 추가:

```yaml
  qr_flutter: ^4.1.0
  mobile_scanner: ^7.0.1
```

Run: `flutter pub get`
Expected: 성공 (버전 충돌 시 `flutter pub add qr_flutter mobile_scanner`로 해결 버전 확인)

- [ ] **Step 2: iOS 로컬 네트워크 권한 문구**

`ios/Runner/Info.plist`의 `NSPhotoLibraryAddUsageDescription` 항목 아래에 추가:

```xml
		<key>NSLocalNetworkUsageDescription</key>
		<string>같은 Wi-Fi의 다른 기기와 리모컨 촬영으로 연결하기 위해 사용합니다.</string>
```

- [ ] **Step 3: 페어링 화면 구현**

```dart
// lib/screens/remote_pairing_screen.dart
// 역할 선택 + 호스트 QR 표시. 판단 없음: 표시·선택만.
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../remote/protocol/pairing_payload.dart';

enum RemoteRole { host, remote }

/// 역할 선택. pop 값: RemoteRole 또는 null(뒤로가기).
class RemotePairingScreen extends StatelessWidget {
  const RemotePairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리모컨 촬영')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _roleCard(
              context,
              icon: Icons.photo_camera,
              title: '이 폰으로 촬영하기',
              subtitle: '삼각대에 두고, 다른 폰에서 QR을 스캔해요',
              role: RemoteRole.host,
            ),
            const SizedBox(height: 16),
            _roleCard(
              context,
              icon: Icons.settings_remote,
              title: '이 폰을 리모컨으로',
              subtitle: '촬영 폰에 뜬 QR을 스캔해서 연결해요',
              role: RemoteRole.remote,
            ),
            const SizedBox(height: 24),
            Text(
              '두 폰이 같은 Wi-Fi(또는 한 폰의 핫스팟)에 있어야 해요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required RemoteRole role,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 36),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: () => Navigator.pop(context, role),
      ),
    );
  }
}

/// 호스트의 QR 대기 화면. 클라이언트가 접속하면 호출측이 pop한다.
class RemoteHostQrScreen extends StatelessWidget {
  const RemoteHostQrScreen({super.key, required this.payload});

  final PairingPayload payload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리모컨 연결 대기')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(data: payload.encode(), size: 240),
            ),
            const SizedBox(height: 24),
            const Text('리모컨 폰의 똥손카메라에서\n[리모컨 촬영 → 이 폰을 리모컨으로]를 눌러\n이 QR을 스캔하세요.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 정적 검사**

Run: `dart analyze lib test`
Expected: No issues found

- [ ] **Step 5: 커밋**

```bash
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist lib/screens/remote_pairing_screen.dart
git commit -m "feat: 리모컨 페어링 화면(역할 선택·QR 표시) + qr/scanner 의존성"
```

---

### Task 9: 리모컨 화면 (스캔 + 프리뷰 + 컨트롤)

**Files:**
- Create: `lib/screens/remote_control_screen.dart`

**Interfaces:**
- Consumes: Task 1/2/3/6 (`PairingPayload`, 메시지, `ReconnectPolicy`, `RemoteClient`)
- Produces: `class RemoteControlScreen extends StatefulWidget` — 인자 없음. 내부에서 스캔→연결→컨트롤 단계 전환.

- [ ] **Step 1: 구현**

```dart
// lib/screens/remote_control_screen.dart
// 리모컨: QR 스캔 → 연결 → 프리뷰·컨트롤. 판단 없음: 표시·명령 전송만.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../remote/protocol/pairing_payload.dart';
import '../remote/protocol/remote_message.dart';
import '../remote/protocol/remote_session.dart';
import '../remote/transport/remote_client.dart';

enum _Phase { scanning, connecting, connected, failed }

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  final RemoteClient _client = RemoteClient();
  final ReconnectPolicy _reconnect = ReconnectPolicy();

  _Phase _phase = _Phase.scanning;
  PairingPayload? _payload;
  WelcomeMessage? _welcome;
  Uint8List? _frame;
  List<String> _hints = const [];
  double _zoom = 1.0;
  int _timerSeconds = 0;
  int _seq = 0;
  StreamSubscription<RemoteMessage>? _msgSub;
  StreamSubscription<List<int>>? _frameSub;
  Timer? _zoomDebounce;

  @override
  void dispose() {
    _zoomDebounce?.cancel();
    _msgSub?.cancel();
    _frameSub?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _onScanned(BarcodeCapture capture) async {
    if (_phase != _Phase.scanning) return;
    for (final code in capture.barcodes) {
      final payload = PairingPayload.decode(code.rawValue ?? '');
      if (payload != null) {
        _payload = payload;
        await _connect(payload);
        return;
      }
    }
  }

  Future<void> _connect(PairingPayload payload) async {
    setState(() => _phase = _Phase.connecting);
    try {
      final welcome = await _client.connect(payload);
      _reconnect.reset();
      _msgSub = _client.messages.listen(_onMessage);
      _frameSub = _client.frames.listen(
          (f) => setState(() => _frame = Uint8List.fromList(f)));
      _client.onDisconnected = _onDisconnected;
      setState(() {
        _welcome = welcome;
        _zoom = welcome.zoom;
        _phase = _Phase.connected;
      });
    } on RemoteRejectedException catch (e) {
      _fail(switch (e.reason) {
        'bad-token' => 'QR이 만료됐어요. 촬영 폰에서 QR을 다시 띄워 스캔해 주세요.',
        'busy' => '이미 다른 리모컨이 연결돼 있어요.',
        _ => '앱 버전이 서로 달라요. 두 폰 모두 최신으로 업데이트해 주세요.',
      });
    } catch (_) {
      _fail('연결하지 못했어요. 두 폰이 같은 Wi-Fi(또는 핫스팟)에 있는지 확인해 주세요.');
    }
  }

  void _onDisconnected() {
    if (!mounted) return;
    final delay = _reconnect.next();
    final payload = _payload;
    if (delay == null || payload == null) {
      _fail('연결이 끊겼어요.');
      return;
    }
    setState(() => _phase = _Phase.connecting);
    Timer(delay, () {
      if (mounted) _connect(payload);
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _phase = _Phase.failed);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _onMessage(RemoteMessage m) {
    switch (m) {
      case StateMessage():
        setState(() {
          _hints = m.hints;
          _zoom = m.zoom;
        });
      case ResultMessage():
        if (m.thumbBase64 != null) {
          final thumb = base64Decode(m.thumbBase64!);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 2),
            content: Row(children: [
              Image.memory(thumb, height: 56),
              const SizedBox(width: 12),
              const Text('찰칵! 촬영 폰에 저장했어요'),
            ]),
          ));
        } else if (!m.ok) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(m.error ?? '명령이 실패했어요')));
        }
      default:
        break;
    }
  }

  void _sendShutter() =>
      _client.send(ShutterMessage(seq: ++_seq, timerSeconds: _timerSeconds));

  void _sendSwitchCamera() =>
      _client.send(SwitchCameraMessage(seq: ++_seq));

  void _onZoomChanged(double v) {
    setState(() => _zoom = v);
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(const Duration(milliseconds: 100), () {
      _client.send(ZoomMessage(seq: ++_seq, zoom: v));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('리모컨')),
      body: switch (_phase) {
        _Phase.scanning => MobileScanner(onDetect: _onScanned),
        _Phase.connecting =>
          const Center(child: CircularProgressIndicator()),
        _Phase.failed => Center(
            child: ElevatedButton(
              onPressed: () => setState(() => _phase = _Phase.scanning),
              child: const Text('QR 다시 스캔'),
            ),
          ),
        _Phase.connected => _controls(),
      },
    );
  }

  Widget _controls() {
    final welcome = _welcome!;
    return Column(children: [
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: welcome.previewAspectRatio,
            child: Stack(fit: StackFit.expand, children: [
              if (_frame != null)
                Image.memory(_frame!, gaplessPlayback: true, fit: BoxFit.cover)
              else
                const Center(child: CircularProgressIndicator()),
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _hints.isEmpty ? '좋아요' : _hints.first,
                      style: TextStyle(
                        color: _hints.isEmpty
                            ? Colors.greenAccent
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          const Icon(Icons.zoom_out, color: Colors.white54),
          Expanded(
            child: Slider(
              min: welcome.minZoom,
              max: welcome.maxZoom,
              value: _zoom.clamp(welcome.minZoom, welcome.maxZoom),
              onChanged: _onZoomChanged,
            ),
          ),
          const Icon(Icons.zoom_in, color: Colors.white54),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 32, top: 8),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _timerButton(),
          GestureDetector(
            onTap: _sendShutter,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: Colors.white24,
              ),
            ),
          ),
          IconButton(
            iconSize: 32,
            color: Colors.white,
            icon: const Icon(Icons.cameraswitch),
            onPressed: _sendSwitchCamera,
          ),
        ]),
      ),
    ]);
  }

  Widget _timerButton() {
    const options = [0, 3, 5, 10];
    return TextButton(
      onPressed: () {
        final next =
            options[(options.indexOf(_timerSeconds) + 1) % options.length];
        setState(() => _timerSeconds = next);
      },
      child: Text(
        _timerSeconds == 0 ? '타이머\n끔' : '타이머\n$_timerSeconds초',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
```

- [ ] **Step 2: 정적 검사**

Run: `dart analyze lib test`
Expected: No issues found

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/remote_control_screen.dart
git commit -m "feat: 리모컨 화면(QR 스캔·실시간 프리뷰·셔터/줌/전환/타이머)"
```

---

### Task 10: CameraScreen 통합 (호스트 모드)

**Files:**
- Modify: `lib/screens/camera_screen.dart`

**Interfaces:**
- Consumes: Task 5/7/8/9 전부, `CameraService`(`capturePhoto`, `saveToGallery`, `setZoom`, `switchCamera`, `sensorOrientation`, `isFront`, `minZoom`/`maxZoom`/`currentZoom`, `controller.value.aspectRatio`), `applyPortraitBlur`(기존)
- Produces: 카메라 화면 상단에 리모컨 아이콘, 호스트 배너, 원격 촬영 카운트다운 오버레이

- [ ] **Step 1: import·상태 추가**

`camera_screen.dart` 상단 import 블록에 추가:

```dart
import '../remote/host_controller.dart';
import '../remote/protocol/remote_message.dart';
import '../remote/transport/local_network.dart';
import '../remote/transport/remote_server.dart';
import 'remote_control_screen.dart';
import 'remote_pairing_screen.dart';
```

`_CameraScreenState` 필드에 추가 (`ShootingMode _mode = ...` 근처):

```dart
  HostController? _remoteHost;
  bool _remoteConnected = false;
  int? _remoteCountdown; // 원격 타이머 카운트다운 표시(null이면 숨김)
  DateTime _lastStateSentAt = DateTime.fromMillisecondsSinceEpoch(0);
```

- [ ] **Step 2: 진입점·호스트 시작/종료 메서드 추가** (`_openCommunity` 메서드 아래에 추가)

```dart
  Future<void> _openRemotePairing() async {
    final role = await Navigator.push<RemoteRole>(
      context,
      MaterialPageRoute(builder: (_) => const RemotePairingScreen()),
    );
    if (!mounted || role == null) return;
    if (role == RemoteRole.remote) {
      await _pauseCamera();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RemoteControlScreen()),
      );
      if (mounted) await _resumeCamera();
      return;
    }
    await _startHost();
  }

  Future<void> _startHost() async {
    final ip = await localIpv4();
    if (ip == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Wi-Fi에 연결돼 있지 않아요. 같은 Wi-Fi 또는 핫스팟에 연결해 주세요.')));
      }
      return;
    }
    final token = generateToken();
    final server = RemoteServer(
      token: token,
      welcomeBuilder: () => WelcomeMessage(
        previewAspectRatio: 1 / _camera.controller.value.aspectRatio,
        minZoom: _camera.minZoom,
        maxZoom: _camera.maxZoom,
        zoom: _camera.currentZoom,
        isFront: _camera.isFront,
        mode: _mode.wire,
        protocolVersion: remoteProtocolVersion,
      ),
    );
    _remoteHost = HostController(
      server: server,
      onShutter: _remoteCapture,
      onZoom: (z) async {
        final applied = await _camera.setZoom(z);
        if (mounted) setState(() => _zoom = applied);
        return applied;
      },
      onSwitchCamera: () async {
        await _switchCamera();
        return true;
      },
    );
    server.onClientChanged = (connected) {
      if (!mounted) return;
      setState(() => _remoteConnected = connected);
      if (connected && Navigator.canPop(context)) {
        Navigator.pop(context); // QR 대기 화면 닫기
      }
    };
    final port = await server.start();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RemoteHostQrScreen(
          payload: PairingPayload(host: ip, port: port, token: token),
        ),
      ),
    );
    // QR 화면에서 뒤로가기로 나왔고 연결도 안 됐으면 서버 정리
    if (!_remoteConnected) await _stopHost();
  }

  Future<void> _stopHost() async {
    final host = _remoteHost;
    _remoteHost = null;
    if (mounted) setState(() => _remoteConnected = false);
    await host?.dispose();
  }

  /// 원격 셔터: 카운트다운 → 촬영(+인물 블러) → 갤러리 저장 → 파일 경로 반환.
  /// 호스트 화면 전환 없음(피사체가 보는 화면 유지).
  Future<String?> _remoteCapture(int timerSeconds) async {
    for (var i = timerSeconds; i > 0; i--) {
      if (!mounted) return null;
      setState(() => _remoteCountdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) setState(() => _remoteCountdown = null);
    _triggerCaptureFeedback();
    try {
      final String shotPath;
      if (_portrait && _mode == ShootingMode.person) {
        final path = await _camera.capturePhoto();
        final blurred = await applyPortraitBlur(
          File(path),
          nowMicros: DateTime.now().microsecondsSinceEpoch,
        );
        shotPath = blurred.path;
      } else {
        shotPath = await _camera.capturePhoto();
      }
      final saved = await _camera.saveToGallery(shotPath);
      return saved ? shotPath : null;
    } catch (_) {
      return null;
    } finally {
      if (mounted) _camera.startStream(_onFrame);
    }
  }
```

주의: `PairingPayload` import가 필요하면 `import '../remote/protocol/pairing_payload.dart';`도 추가. `_zoom` 필드명은 기존 코드의 줌 상태 필드명에 맞출 것(`_onScaleUpdate`에서 `setState(() => _zoom = applied)` 패턴 확인 후 동일하게).

- [ ] **Step 3: 프레임·상태 전송 훅** (`_onFrame` 끝부분, metrics를 setState한 직후에 추가)

```dart
    // 리모컨 연결 시: 프리뷰 프레임 + 가이드 상태 전송
    final host = _remoteHost;
    if (host != null && _remoteConnected) {
      host.pushCameraImage(
        image,
        rotationDegrees: Platform.isAndroid ? _camera.sensorOrientation : 0,
        mirror: _camera.isFront,
      );
      final now = DateTime.now();
      if (now.difference(_lastStateSentAt).inMilliseconds >= 500) {
        _lastStateSentAt = now;
        host.pushState(StateMessage(
          hints: _metrics.activeHints,
          zoom: _camera.currentZoom,
          isFront: _camera.isFront,
          mode: _mode.wire,
        ));
      }
    }
```

(`Platform`은 이 파일에서 이미 import된 `dart:io` 사용 여부 확인, 없으면 `import 'dart:io';` 추가)

- [ ] **Step 4: UI — 상단 아이콘·배너·카운트다운 오버레이**

상단 아이콘 Row(`_topIcon(Icons.people, _openCommunity)`가 있는 곳)를 다음과 같이 수정:

```dart
                          children: [
                            _topIcon(Icons.people, _openCommunity),
                            _topIcon(Icons.settings_remote, _openRemotePairing),
                            if (_camera.canSwitch)
                              _topIcon(Icons.cameraswitch, _switchCamera)
                            else
                              const SizedBox(width: 44),
                          ],
```

같은 Column에서 `_readyBadge()/_stepPill` 아래에 호스트 배너 추가:

```dart
                      if (_remoteConnected)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.settings_remote,
                                size: 16, color: Colors.greenAccent),
                            const SizedBox(width: 6),
                            const Text('리모컨 연결됨',
                                style: TextStyle(color: Colors.white)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _stopHost,
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.white70),
                            ),
                          ]),
                        ),
```

Stack 최상위(플래시 오버레이 근처)에 카운트다운 오버레이 추가:

```dart
            if (_remoteCountdown != null)
              Center(
                child: Text(
                  '$_remoteCountdown',
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 24, color: Colors.black)],
                  ),
                ),
              ),
```

`dispose()`에 `_remoteHost?.dispose();` 추가. 앱 백그라운드 전환 처리(`didChangeAppLifecycleState` 또는 `_pauseCamera`)에 `_stopHost()` 호출 추가 — 스펙 6장 "호스트 백그라운드 전환 시 세션 종료".

- [ ] **Step 5: 검증·커밋**

Run: `dart analyze lib test && flutter test`
Expected: 이슈 0건, 전체 테스트 PASS

```bash
git add lib/screens/camera_screen.dart
git commit -m "feat: 카메라 화면 호스트 모드 통합(리모컨 진입·배너·원격 셔터·카운트다운)"
```

---

### Task 11: 최종 검증 (verify.sh + 실기기 2대)

**Files:**
- 없음 (검증만)

- [ ] **Step 1: 완료 게이트**

Run: `tool/verify.sh`
Expected: format·analyze·test 모두 통과

- [ ] **Step 2: 실기기 2대 수동 체크리스트** (iOS 1대 + Android 1대 권장 — 교차 연결 검증)

1. 호스트 폰: 리모컨 아이콘 → "이 폰으로 촬영하기" → QR 표시됨
2. 리모컨 폰: "이 폰을 리모컨으로" → QR 스캔 → 1~2초 내 프리뷰 표시 (iOS 첫 실행 시 로컬 네트워크 권한 팝업 허용)
3. 프리뷰가 실시간(지연 0.5초 미만 체감)으로 움직이는지, 전면 카메라에서 좌우가 자연스러운지
4. 리모컨 셔터 → 호스트 무음 촬영 → 리모컨에 썸네일 토스트 → 호스트 갤러리에 저장 확인
5. 타이머 5초 → 호스트 화면에 큰 카운트다운 → 촬영
6. 줌 슬라이더 → 호스트 프리뷰 줌 변화 확인
7. 전/후면 전환 버튼 동작 확인
8. 가이드 배지: 폰을 기울이면 리모컨 배지에 힌트, 수평이면 '좋아요'
9. 끊김 복구: 리모컨 폰 Wi-Fi를 잠깐 껐다 켬 → 5초 내 자동 재접속 또는 재스캔 안내
10. 호스트 배너 X 버튼 → 리모컨에 연결 끊김 안내
11. 호스트 앱을 백그라운드로 → 리모컨에 끊김 안내

- [ ] **Step 3: 발견된 문제 수정 후 최종 커밋**

```bash
git add -A
git commit -m "chore: 리모컨 촬영 실기기 검증 반영"
```

---

## Self-Review 결과

- **Spec coverage**: 스펙 2장(모듈)→Task 1-7, 4장(UX)→Task 8-10, 5장(프로토콜)→Task 2, 6장(에러: 토큰/busy→Task 5, 재접속→Task 3·9, timeout 안내→Task 9, 백그라운드→Task 10 Step 4, 배압→Task 3·5), 7장(테스트)→각 태스크+Task 11. 누락 없음.
- **Placeholder scan**: TBD/TODO 없음. 모든 코드 스텝에 실제 코드 포함.
- **Type consistency**: `WelcomeMessage` 7필드, `onShutter: Future<String?> Function(int)`, `sendFrame(List<int>)`, `RemoteRole` — Task 간 시그니처 일치 확인.
