import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/models/person_box.dart';
import 'package:ttongson_camera/models/shooting_mode.dart';
import 'package:ttongson_camera/analysis/analysis_engine.dart';
import 'package:ttongson_camera/analysis/guide_step.dart';

void main() {
  final engine = AnalysisEngine(null);
  const level = SensorSample(
    accelX: 0,
    accelY: 9.8,
    accelZ: 0,
  ); // roll≈0, pitch≈0
  const tilted = SensorSample(accelX: 9.8, accelY: 9.8, accelZ: 0); // roll≈45

  test('수평이 안 맞으면 level 단계가 최우선', () {
    final m = engine.buildMetrics(person: null, sensor: tilted);
    final s = computeCurrentStep(m);
    // level 단계
    expect(s.kind, GuideStepKind.level);
  });

  test('인물이 프레임 밖으로 잘리면 수평 다음 crop 단계', () {
    // 수평 OK, 얼굴이 위/왼쪽에 닿아 잘림.
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.0, top: 0.0, width: 0.3, height: 0.5),
      face: const PersonBox(left: 0.0, top: 0.0, width: 0.2, height: 0.15),
      sensor: level,
    );
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.crop);
  });

  test('피사체가 작으면 distance 단계', () {
    // 수평 OK, 잘림 없음, 얼굴 작음(줌 힌트 발생), 위치는 교차점.
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.28, top: 0.30, width: 0.1, height: 0.10),
      face: const PersonBox(left: 0.283, top: 0.283, width: 0.1, height: 0.10),
      sensor: level,
    );
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.distance);
  });

  test('위치가 어긋나면 position 단계 + 현재/목표 좌표 포함', () {
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.75, top: 0.55, width: 0.2, height: 0.60),
      face: const PersonBox(left: 0.80, top: 0.55, width: 0.1, height: 0.12),
      sensor: level,
    );
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.position);
    expect(s.target, isNotNull);
    expect(s.target!.currentX, closeTo(0.85, 1e-9)); // face centerX
  });

  test('모든 조건이 좋으면 ready', () {
    // 얼굴이 (1/3,1/3) 교차점, person 헤드룸(top 0.10)·크기(height 0.65) 적정,
    // 잘림 없음, 수평, 눈높이(pitch 0).
    final m = engine.buildMetrics(
      person: const PersonBox(left: 0.28, top: 0.10, width: 0.1, height: 0.65),
      face: const PersonBox(left: 0.283, top: 0.283, width: 0.1, height: 0.10),
      sensor: level,
    );
    final s = computeCurrentStep(m);
    // ready 단계
    expect(s.kind, GuideStepKind.ready);
  });

  test('자연 모드에서 주제 미검출이면 수평만 맞으면 ready', () {
    final m = engine.buildMetrics(
      person: null,
      sensor: level,
      mode: ShootingMode.nature,
    );
    final s = computeCurrentStep(m);
    expect(s.kind, GuideStepKind.ready);
  });
}
