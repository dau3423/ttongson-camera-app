import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/analysis_engine.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/models/shooting_mode.dart';

const _sensor = SensorSample(accelX: 0, accelY: 9.8, accelZ: 0);
const _box = PersonBox(left: 0.3, top: 0.3, width: 0.2, height: 0.3);

void main() {
  final engine = AnalysisEngine(null);

  test('자연 모드: 주제가 잡히면 person/thirds/zoom 채우고 headroom/crop 은 생략', () {
    final m = engine.buildMetrics(
      person: _box,
      face: _box,
      sensor: _sensor,
      mode: ShootingMode.nature,
    );
    expect(m.person, isNotNull);
    expect(m.thirds, isNotNull);
    expect(m.zoom, isNotNull);
    expect(m.headroom, isNull);
    expect(m.crop, isNull);
  });

  test('자연 모드: 주제 미검출이면 thirds/zoom 은 null', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: _sensor,
      mode: ShootingMode.nature,
    );
    expect(m.thirds, isNull);
    expect(m.zoom, isNull);
  });

  test('자연 모드: 앞뒤로 기울면 정면(수평) 각도 안내', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: const SensorSample(
        accelX: 0,
        accelY: 9.8,
        accelZ: 9.8,
      ), // pitch≈45
      mode: ShootingMode.nature,
    );
    expect(m.angle.hint, '카메라를 수평으로 내리세요');
  });

  test('사물 모드: person/thirds/zoom/crop 채우고 headroom 은 생략', () {
    final m = engine.buildMetrics(
      person: _box,
      face: _box,
      sensor: _sensor,
      mode: ShootingMode.object,
    );
    expect(m.person, isNotNull);
    expect(m.thirds, isNotNull);
    expect(m.zoom, isNotNull);
    expect(m.crop, isNotNull);
    expect(m.headroom, isNull);
  });

  test('인물 모드(기본): headroom/crop/thirds/zoom 모두 채움', () {
    final m = engine.buildMetrics(person: _box, face: _box, sensor: _sensor);
    expect(m.person, isNotNull);
    expect(m.headroom, isNotNull);
    expect(m.crop, isNotNull);
    expect(m.thirds, isNotNull);
    expect(m.zoom, isNotNull);
  });

  test('사물 모드에서 감지 없으면 person 은 null', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: _sensor,
      mode: ShootingMode.object,
    );
    expect(m.person, isNull);
  });
}
