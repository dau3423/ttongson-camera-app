import '../models/person_box.dart';
import '../models/shooting_mode.dart';
import 'tilt.dart';
import 'thirds.dart';
import 'headroom.dart';
import 'crop.dart';
import 'angle_zoom.dart';
import 'guide_metrics.dart';
import 'person_detector.dart';

class SensorSample {
  final double accelX;
  final double accelY;
  final double accelZ;
  const SensorSample({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
  });
}

/// 감지된 대상 + 센서 샘플을 모드에 맞는 GuideMetrics로 조립한다(순수 로직).
class AnalysisEngine {
  final PersonDetector? detector;
  AnalysisEngine(this.detector);

  GuideMetrics buildMetrics({
    PersonBox? person,
    PersonBox? face,
    required SensorSample sensor,
    ShootingMode mode = ShootingMode.person,
  }) {
    final tilt = computeTilt(sensor.accelX, sensor.accelY);
    final pitch = computePitch(sensor.accelY, sensor.accelZ);

    // 자연: 수평·격자만. 대상 감지 무시.
    if (mode == ShootingMode.nature) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, hasPerson: false),
      );
    }

    // 대상 미감지: 수평·각도만.
    if (person == null) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, hasPerson: false),
      );
    }

    // 사물: 중앙(3분할)·줌만. 헤드룸/크롭/눈높이각 없음.
    if (mode == ShootingMode.object) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, hasPerson: false),
        person: person,
        thirds: computeThirds(person.centerX, person.centerY),
        zoom: computeZoom(person.height),
      );
    }

    // 인물(기본): 전체 지표.
    final angle = computeAngle(pitch, hasPerson: true);
    final cropBox = face ?? person;
    return GuideMetrics(
      tilt: tilt,
      angle: angle,
      person: person,
      thirds: computeThirds(person.centerX, person.centerY),
      headroom: computeHeadroom(person),
      crop: detectCrop(cropBox),
      zoom: computeZoom(person.height),
    );
  }
}
