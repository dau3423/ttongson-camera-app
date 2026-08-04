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
    await client.connect(
      PairingPayload(host: '127.0.0.1', port: port, token: 't'),
    );

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
    await client.connect(
      PairingPayload(host: '127.0.0.1', port: port, token: 't'),
    );
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
    await client.connect(
      PairingPayload(host: '127.0.0.1', port: port, token: 't'),
    );

    final r1 = client.messages.firstWhere((m) => m is ResultMessage);
    client.send(const ZoomMessage(seq: 10, zoom: 9.0));
    expect((await r1 as ResultMessage).seq, 10);

    final r2 = client.messages.firstWhere(
      (m) => m is ResultMessage && m.seq == 11,
    );
    client.send(const SwitchCameraMessage(seq: 11));
    expect((await r2 as ResultMessage).ok, isTrue);
  });
}
