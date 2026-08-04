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
    final ws = await WebSocket.connect(
      'ws://${payload.host}:${payload.port}',
    ).timeout(timeout);
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
    ws.add(
      HelloMessage(
        token: payload.token,
        protocolVersion: remoteProtocolVersion,
      ).encode(),
    );
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
