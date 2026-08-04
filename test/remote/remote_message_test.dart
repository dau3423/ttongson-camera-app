import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/remote/protocol/remote_message.dart';

void main() {
  test('hello 라운드트립', () {
    const m = HelloMessage(
      token: 'tok',
      protocolVersion: remoteProtocolVersion,
    );
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
      hints: ['왼쪽으로 기울었어요'],
      zoom: 1.0,
      isFront: true,
      mode: 'person',
    );
    final d = RemoteMessage.decode(m.encode()) as StateMessage;
    expect(d.hints, ['왼쪽으로 기울었어요']);
    expect(d.isFront, isTrue);
  });

  test('명령·결과 라운드트립', () {
    final shutter =
        RemoteMessage.decode(
              const ShutterMessage(seq: 7, timerSeconds: 5).encode(),
            )
            as ShutterMessage;
    expect(shutter.seq, 7);
    expect(shutter.timerSeconds, 5);

    final zoom =
        RemoteMessage.decode(const ZoomMessage(seq: 8, zoom: 3.0).encode())
            as ZoomMessage;
    expect(zoom.zoom, 3.0);

    final sw = RemoteMessage.decode(const SwitchCameraMessage(seq: 9).encode());
    expect((sw as SwitchCameraMessage).seq, 9);

    final res =
        RemoteMessage.decode(
              const ResultMessage(seq: 7, ok: false, error: '실패').encode(),
            )
            as ResultMessage;
    expect(res.ok, isFalse);
    expect(res.error, '실패');
    expect(res.thumbBase64, isNull);
  });

  test('ping/pong/reject', () {
    expect(
      RemoteMessage.decode(const PingMessage().encode()),
      isA<PingMessage>(),
    );
    expect(
      RemoteMessage.decode(const PongMessage().encode()),
      isA<PongMessage>(),
    );
    final r = RemoteMessage.decode(
      const RejectMessage(reason: 'bad-token').encode(),
    );
    expect((r as RejectMessage).reason, 'bad-token');
  });

  test('깨진 입력은 null (예외 없음)', () {
    expect(RemoteMessage.decode('not json'), isNull);
    expect(RemoteMessage.decode('{"type":"unknown"}'), isNull);
    expect(RemoteMessage.decode('{"type":"shutter"}'), isNull); // 필드 누락
    expect(RemoteMessage.decode('[1,2]'), isNull);
  });
}
