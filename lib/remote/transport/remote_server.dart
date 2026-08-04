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

  void sendMessage(RemoteMessage m) {
    final client = _client;
    if (client == null) return;
    try {
      client.add(m.encode());
    } on StateError {
      // 소켓이 이미 닫혔으면 무시
    }
  }

  void _flushFrame() {
    final client = _client;
    if (client == null) {
      _frames.take(); // 접속 없으면 버림
      return;
    }
    final frame = _frames.take();
    if (frame != null) {
      try {
        client.add(frame);
      } on StateError {
        // 소켓이 이미 닫혔으면 무시
      }
    }
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
    try {
      client.add(const PingMessage().encode());
    } on StateError {
      // 소켓이 이미 닫혔으면 무시
    }
  }

  Future<void> stop() async {
    _frameTimer?.cancel();
    _pingTimer?.cancel();
    final client = _client;
    _client = null; // 먼저 null화: 진행 중인 tick이 add를 시도하지 않도록
    try {
      await client?.close();
      if (client != null) onClientChanged?.call(false);
    } finally {
      await _http?.close(force: true);
      _http = null;
    }
  }
}
