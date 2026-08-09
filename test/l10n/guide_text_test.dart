import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/l10n/app_localizations.dart';
import 'package:ttongson_camera/analysis/tilt.dart';
import 'package:ttongson_camera/analysis/crop.dart';
import 'package:ttongson_camera/analysis/angle_zoom.dart';
import 'package:ttongson_camera/analysis/headroom.dart';
import 'package:ttongson_camera/analysis/thirds.dart';
import 'package:ttongson_camera/analysis/guide_metrics.dart';
import 'package:ttongson_camera/l10n/guide_text.dart';

void main() {
  late AppLocalizations ko;
  setUpAll(() async {
    ko = await AppLocalizations.delegate.load(const Locale('ko'));
  });

  test('tilt 힌트 매핑', () {
    expect(tiltHintText(ko, TiltHint.none), isNull);
    expect(tiltHintText(ko, TiltHint.lowerLeft), '왼쪽을 내리세요');
    expect(tiltHintText(ko, TiltHint.lowerRight), '오른쪽을 내리세요');
  });

  test('crop 다중 변 조립', () {
    const c = CropWarning(top: true, bottom: true, left: false, right: false);
    expect(cropText(ko, c), '위/아래이(가) 잘렸어요');
  });

  test('zoom/angle/headroom 매핑', () {
    expect(zoomText(ko, ZoomHint.closer), '조금 다가가거나 확대하세요');
    expect(angleText(ko, AngleHint.eyeLevelDown), '카메라를 눈높이로 내리세요');
    expect(headroomText(ko, HeadroomHint.raiseCamera), '카메라를 살짝 올리세요');
  });

  test('thirds 이동 방향 조립', () {
    const t = ThirdsAlignment(
      currentX: 0.2,
      currentY: 0.2,
      targetX: 0.333,
      targetY: 0.333,
      distance: 0.1,
      score: 0.6,
      isAligned: false,
      moveRight: true,
      moveLeft: false,
      moveUp: false,
      moveDown: true,
    );
    expect(thirdsMoveText(ko, t), '오른쪽으로 · 아래로');
  });

  test('activeHintTexts는 우선순위 순으로 활성 힌트만 담는다', () {
    const m = GuideMetrics(
      tilt: TiltInfo(rollDegrees: 5, isLevel: false, hint: TiltHint.lowerLeft),
      crop: CropWarning(top: true, bottom: false, left: false, right: false),
      headroom: HeadroomAdvice(ratio: 0.3, hint: HeadroomHint.lowerCamera),
      thirds: ThirdsAlignment(
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
        moveDown: false,
      ),
      angle: AngleAdvice(pitchDegrees: 20, hint: AngleHint.eyeLevelDown),
      zoom: ZoomAdvice(subjectRatio: 0.2, hint: ZoomHint.closer),
    );
    expect(activeHintTexts(ko, m), [
      '왼쪽을 내리세요',
      '위이(가) 잘렸어요',
      '카메라를 살짝 내리세요',
      '오른쪽으로',
      '카메라를 눈높이로 내리세요',
      '조금 다가가거나 확대하세요',
    ]);
  });

  test('정렬·적정 상태면 activeHintTexts는 비어 있다', () {
    const m = GuideMetrics(
      tilt: TiltInfo(rollDegrees: 0, isLevel: true, hint: TiltHint.none),
      angle: AngleAdvice(pitchDegrees: 0, hint: AngleHint.none),
    );
    expect(activeHintTexts(ko, m), isEmpty);
  });
}
