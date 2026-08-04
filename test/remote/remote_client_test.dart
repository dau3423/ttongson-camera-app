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
      throwsA(
        isA<RemoteRejectedException>().having(
          (e) => e.reason,
          'reason',
          'bad-token',
        ),
      ),
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
