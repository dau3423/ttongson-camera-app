// Pure Dart — Flutter/plugin/dart:io import forbidden.

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
