// test/cloud/stillness_detector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/stillness_detector.dart';

void main() {
  test('정지가 stillMs 이상 지속되면 한 번 true', () {
    final d = StillnessDetector(moveThreshold: 0.5, stillMs: 2000);
    // 첫 샘플은 기준선(이전 값 없음) → false
    expect(d.update(9.8, 0), isFalse);
    expect(d.update(9.8, 500), isFalse); // 정지 지속 중이나 2초 미달
    expect(d.update(9.8, 1500), isFalse);
    expect(d.update(9.8, 2000), isTrue); // 2초 도달 → 발화
    expect(d.update(9.8, 2500), isFalse); // 같은 에피소드 재발화 안 함
  });

  test('움직이면 타이머 리셋 후 다시 무장', () {
    final d = StillnessDetector(moveThreshold: 0.5, stillMs: 2000);
    d.update(9.8, 0);
    expect(d.update(9.8, 2000), isTrue); // 첫 발화
    expect(d.update(12.0, 2100), isFalse); // 큰 변화 = 움직임 → 리셋
    expect(d.update(12.0, 4000), isFalse); // 새 정지 구간 2초 미달(기준 2100)
    expect(d.update(12.0, 4100), isTrue); // 2초 도달 → 재발화
  });
}
