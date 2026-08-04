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
  return List.generate(
    16,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
