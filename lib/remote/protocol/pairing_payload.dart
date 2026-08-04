/// QR에 담기는 페어링 정보. 형식: ttongson-remote:v1:&lt;host&gt;:&lt;port&gt;:&lt;token&gt;
class PairingPayload {
  final String host;
  final int port;
  final String token;

  const PairingPayload({
    required this.host,
    required this.port,
    required this.token,
  });

  static const String _scheme = 'ttongson-remote';
  static const int _version = 1;

  String encode() => '$_scheme:v$_version:$host:$port:$token';

  /// 형식이 어긋나면 null (스캔한 QR이 우리 것이 아닐 수 있음).
  static PairingPayload? decode(String raw) {
    final parts = raw.split(':');
    if (parts.length != 5) return null;
    if (parts[0] != _scheme || parts[1] != 'v$_version') return null;
    final port = int.tryParse(parts[3]);
    if (port == null || port <= 0 || port > 65535) return null;
    if (parts[2].isEmpty || parts[4].isEmpty) return null;
    return PairingPayload(host: parts[2], port: port, token: parts[4]);
  }
}
