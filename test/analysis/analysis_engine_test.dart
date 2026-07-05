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

  test('face 박스가 있으면 잘림 감지는 person이 아닌 face 박스 기준', () {
    // person: bottom = 0.1 + 0.9 = 1.0 → 잘림 예상(person 기준)
    // face:   bottom = 0.1 + 0.15 = 0.25 → 잘림 없음(face 기준)
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.3, top: 0.1, width: 0.4, height: 0.9),
      face: const PersonBox(left: 0.4, top: 0.1, width: 0.2, height: 0.15),
      sensor: const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0),
    );
    expect(m.crop!.any, isFalse, reason: '잘림 감지는 face 박스 기준이므로 경계에 닿지 않아야 함');
  });

  test('인물 모드 3분할은 얼굴 중심 기준 — 얼굴이 교차점에 오면 좋아요', () {
    // 얼굴 중심이 (1/3, 1/3) 교차점. 몸통(person) 중심은 아래로 치우쳐 있어도
    // 3분할 정렬은 얼굴 기준이라 '좋아요'가 나와야 한다.
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.28, top: 0.3, width: 0.1, height: 0.5),
      face: const PersonBox(left: 0.283, top: 0.283, width: 0.1, height: 0.1),
      sensor: const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0),
    );
    expect(m.thirds!.hint, '좋아요');
  });

  test('face null 이면 person 박스로 폴백해 잘림 감지', () {
    // person: bottom = 0.1 + 0.9 = 1.0 → 아래 잘림
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.3, top: 0.1, width: 0.4, height: 0.9),
      sensor: const SensorSample(accelX: 0, accelY: 9.8, accelZ: 0),
    );
    expect(m.crop!.bottom, isTrue, reason: 'face 없을 때 person 폴백 → 아래 잘림 감지');
  });
}
