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

    // 자연: 수평 + 앞뒤 기울기(항상). 주제가 잡히면 거리·위치도.
    if (mode == ShootingMode.nature) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, guide: AngleGuide.frontal),
        person: person,
        thirds: person == null
            ? null
            : computeThirds(person.centerX, person.centerY),
        zoom: person == null ? null : computeZoom(person.height),
      );
    }

    // 대상 미감지(인물/사물): 수평만.
    if (person == null) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, guide: AngleGuide.none),
      );
    }

    // 사물: 수평·잘림·거리·위치·정면 각도. 헤드룸 없음.
    if (mode == ShootingMode.object) {
      return GuideMetrics(
        tilt: tilt,
        angle: computeAngle(pitch, guide: AngleGuide.frontal),
        person: person,
        thirds: computeThirds(person.centerX, person.centerY),
        crop: detectCrop(person),
        zoom: computeZoom(person.height),
      );
    }

    // 인물(기본): 전체 지표. 3분할·잘림은 얼굴 기준.
    final cropBox = face ?? person;
    final thirdsBox = face ?? person;
    return GuideMetrics(
      tilt: tilt,
      angle: computeAngle(pitch, guide: AngleGuide.eyeLevel),
      person: person,
      thirds: computeThirds(thirdsBox.centerX, thirdsBox.centerY),
      headroom: computeHeadroom(person),
      crop: detectCrop(cropBox),
      zoom: computeZoom(person.height),
    );
  }
}
