import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/remote/protocol/pairing_payload.dart';

void main() {
  test('encode → decode 라운드트립', () {
    const p = PairingPayload(
      host: '192.168.0.7',
      port: 40321,
      token: 'a1b2c3d4e5f60718',
    );
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
    expect(
      PairingPayload.decode('ttongson-remote:v1:1.2.3.4:notaport:tok'),
      isNull,
    );
  });
}
