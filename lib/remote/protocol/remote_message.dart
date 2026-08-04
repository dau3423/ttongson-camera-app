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
            previewAspectRatio: (parsed['previewAspectRatio'] as num)
                .toDouble(),
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
  Map<String, dynamic> fields() => {
    'token': token,
    'protocolVersion': protocolVersion,
  };
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
  Map<String, dynamic> fields() => {
    'hints': hints,
    'zoom': zoom,
    'isFront': isFront,
    'mode': mode,
  };
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
