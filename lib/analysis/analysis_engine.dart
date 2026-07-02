import '../models/person_box.dart';
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

/// 감지된 인물 + 센서 샘플을 GuideMetrics로 조립한다(순수 로직).
class AnalysisEngine {
  final PersonDetector? detector;
  AnalysisEngine(this.detector);

  GuideMetrics buildMetrics({
    PersonBox? person,
    PersonBox? face,
    required SensorSample sensor,
  }) {
    final tilt = computeTilt(sensor.accelX, sensor.accelY);
    final pitch = computePitch(sensor.accelY, sensor.accelZ);
    final angle = computeAngle(pitch, hasPerson: person != null);

    if (person == null) {
      return GuideMetrics(tilt: tilt, angle: angle);
    }
    // 잘림 감지는 실제 관측된 얼굴 박스 사용(face); 없으면 person으로 폴백.
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
