import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/guide_metrics.dart';
import 'package:ttongson_camera/analysis/tilt.dart';
import 'package:ttongson_camera/analysis/thirds.dart';
import 'package:ttongson_camera/analysis/headroom.dart';
import 'package:ttongson_camera/analysis/crop.dart';
import 'package:ttongson_camera/analysis/angle_zoom.dart';

void main() {
  group('GuideMetrics.activeHints', () {
    test('우선순위 순서: tilt → crop → headroom → thirds → angle → zoom', () {
      final metrics = GuideMetrics(
        tilt: const TiltInfo(rollDegrees: 5, isLevel: false, hint: '왼쪽을 내리세요'),
        crop: const CropWarning(
          top: true,
          bottom: false,
          left: false,
          right: false,
        ),
        headroom: const HeadroomAdvice(ratio: 0.3, hint: '카메라를 살짝 내리세요'),
        thirds: const ThirdsAlignment(
          currentX: 0.667,
          currentY: 0.333,
          targetX: 0.667,
          targetY: 0.333,
          distance: 0.15,
          score: 0.625,
          hint: '오른쪽으로',
        ),
        angle: const AngleAdvice(pitchDegrees: 20, hint: '카메라를 눈높이로 내리세요'),
        zoom: const ZoomAdvice(subjectRatio: 0.2, hint: '조금 다가가거나 확대하세요'),
      );

      expect(metrics.activeHints, [
        '왼쪽을 내리세요',
        '위이(가) 잘렸어요',
        '카메라를 살짝 내리세요',
        '오른쪽으로',
        '카메라를 눈높이로 내리세요',
        '조금 다가가거나 확대하세요',
      ]);
    });

    test('빈 hint는 activeHints에 포함되지 않음', () {
      final metrics = GuideMetrics(
        tilt: const TiltInfo(rollDegrees: 0, isLevel: true, hint: ''),
        angle: const AngleAdvice(pitchDegrees: 0, hint: ''),
        crop: const CropWarning(
          top: false,
          bottom: false,
          left: false,
          right: false,
        ),
        headroom: const HeadroomAdvice(ratio: 0.1, hint: ''),
        thirds: const ThirdsAlignment(
          currentX: 0.333,
          currentY: 0.333,
          targetX: 0.333,
          targetY: 0.333,
          distance: 0.01,
          score: 0.975,
          hint: '좋아요',
        ),
        zoom: const ZoomAdvice(subjectRatio: 0.6, hint: ''),
      );

      expect(metrics.activeHints, isEmpty);
    });

    test('thirds.hint가 "좋아요"이면 activeHints에서 제외', () {
      final metrics = GuideMetrics(
        tilt: const TiltInfo(rollDegrees: 0, isLevel: true, hint: ''),
        angle: const AngleAdvice(pitchDegrees: 0, hint: ''),
        thirds: const ThirdsAlignment(
          currentX: 0.333,
          currentY: 0.333,
          targetX: 0.333,
          targetY: 0.333,
          distance: 0.01,
          score: 0.975,
          hint: '좋아요',
        ),
      );

      expect(metrics.activeHints, isNot(contains('좋아요')));
      expect(metrics.activeHints, isEmpty);
    });

    test('thirds.hint가 "좋아요"가 아니면 activeHints에 포함', () {
      final metrics = GuideMetrics(
        tilt: const TiltInfo(rollDegrees: 0, isLevel: true, hint: ''),
        angle: const AngleAdvice(pitchDegrees: 0, hint: ''),
        thirds: const ThirdsAlignment(
          currentX: 0.667,
          currentY: 0.333,
          targetX: 0.667,
          targetY: 0.333,
          distance: 0.2,
          score: 0.5,
          hint: '오른쪽으로',
        ),
      );

      expect(metrics.activeHints, contains('오른쪽으로'));
    });

    test('선택적 필드가 null이면 해당 hint 없음', () {
      final metrics = GuideMetrics(
        tilt: const TiltInfo(rollDegrees: 0, isLevel: true, hint: ''),
        angle: const AngleAdvice(pitchDegrees: 0, hint: ''),
      );

      expect(metrics.activeHints, isEmpty);
    });
  });
}
