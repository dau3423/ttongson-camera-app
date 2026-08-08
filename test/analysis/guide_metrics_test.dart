import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/guide_metrics.dart';
import 'package:ttongson_camera/analysis/tilt.dart';
import 'package:ttongson_camera/analysis/thirds.dart';
import 'package:ttongson_camera/analysis/headroom.dart';
import 'package:ttongson_camera/analysis/crop.dart';
import 'package:ttongson_camera/analysis/angle_zoom.dart';

void main() {
  test('GuideMetrics는 각 분석 결과를 그대로 보관한다', () {
    final m = GuideMetrics(
      tilt: const TiltInfo(
        rollDegrees: 5,
        isLevel: false,
        hint: TiltHint.lowerLeft,
      ),
      crop: const CropWarning(
        top: true,
        bottom: false,
        left: false,
        right: false,
      ),
      headroom: const HeadroomAdvice(
        ratio: 0.3,
        hint: HeadroomHint.lowerCamera,
      ),
      thirds: const ThirdsAlignment(
        currentX: 0.2,
        currentY: 0.2,
        targetX: 0.333,
        targetY: 0.333,
        distance: 0.15,
        score: 0.6,
        isAligned: false,
        moveRight: true,
        moveLeft: false,
        moveUp: false,
        moveDown: true,
      ),
      angle: const AngleAdvice(pitchDegrees: 20, hint: AngleHint.eyeLevelDown),
      zoom: const ZoomAdvice(subjectRatio: 0.2, hint: ZoomHint.closer),
    );
    expect(m.tilt.hint, TiltHint.lowerLeft);
    expect(m.crop!.any, isTrue);
    expect(m.headroom!.hint, HeadroomHint.lowerCamera);
    expect(m.thirds!.isAligned, isFalse);
    expect(m.angle.hint, AngleHint.eyeLevelDown);
    expect(m.zoom!.hint, ZoomHint.closer);
  });
}
