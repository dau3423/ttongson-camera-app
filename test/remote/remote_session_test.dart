import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/remote/protocol/remote_session.dart';

void main() {
  group('LatestFrameBuffer', () {
    test('최신 프레임만 유지하고 밀린 프레임은 드롭 카운트', () {
      final buf = LatestFrameBuffer();
      expect(buf.take(), isNull);
      buf.push([1]);
      buf.push([2]);
      buf.push([3]);
      expect(buf.take(), [3]);
      expect(buf.take(), isNull); // 소비 후 비움
      expect(buf.dropped, 2);
    });
  });

  group('ConnectionHealth', () {
    test('ping 3회 무응답이면 사망, 수신 활동이 있으면 리셋', () {
      final h = ConnectionHealth();
      h.onPingSent();
      h.onPingSent();
      expect(h.isDead, isFalse);
      h.onActivity(); // pong 또는 아무 메시지
      h.onPingSent();
      h.onPingSent();
      h.onPingSent();
      expect(h.isDead, isTrue);
    });
  });

  group('ReconnectPolicy', () {
    test('1초 간격 5회 후 소진', () {
      final p = ReconnectPolicy();
      final delays = <Duration>[];
      for (Duration? d = p.next(); d != null; d = p.next()) {
        delays.add(d);
      }
      expect(delays, List.filled(5, const Duration(seconds: 1)));
      expect(p.exhausted, isTrue);
      p.reset();
      expect(p.exhausted, isFalse);
      expect(p.next(), const Duration(seconds: 1));
    });
  });
}
