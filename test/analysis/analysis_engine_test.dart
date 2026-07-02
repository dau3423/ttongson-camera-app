import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/analysis/analysis_engine.dart';

void main() {
  final engine = AnalysisEngine(null);

  test('인물 없으면 person/thirds/headroom/crop/zoom 은 null, tilt/angle 존재', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0),
    );
    expect(m.person, isNull);
    expect(m.thirds, isNull);
    expect(m.headroom, isNull);
    expect(m.crop, isNull);
    expect(m.zoom, isNull);
    expect(m.tilt.isLevel, isTrue);
    expect(m.angle.hint, ''); // hasPerson=false
  });

  test('인물 있으면 모든 지표 계산', () {
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.3, top: 0.1, width: 0.4, height: 0.6),
      sensor: const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0),
    );
    expect(m.person, isNotNull);
    expect(m.thirds, isNotNull);
    expect(m.headroom, isNotNull);
    expect(m.crop, isNotNull);
    expect(m.zoom, isNotNull);
  });

  test('기울어진 센서면 tilt.hint 생성', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: const SensorSample(accelX: 9.8, accelY: 9.8, accelZ: 0),
    );
    expect(m.tilt.hint, '왼쪽을 내리세요');
  });
}
