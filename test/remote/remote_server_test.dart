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
    // Use listen so the stream stays drained and the server close-frame is received.
    final closed = Completer<void>();
    RemoteMessage? firstMsg;
    ws.listen(
      (data) {
        if (data is String) firstMsg ??= RemoteMessage.decode(data);
      },
      onDone: closed.complete,
      onError: closed.completeError,
    );
    ws.add(const HelloMessage(token: 'evil', protocolVersion: 1).encode());
    await closed.future; // 서버가 reject 후 닫음
    expect((firstMsg as RejectMessage).reason, 'bad-token');
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
