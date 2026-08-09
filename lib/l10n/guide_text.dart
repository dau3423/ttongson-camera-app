import 'app_localizations.dart';
import '../analysis/tilt.dart';
import '../analysis/headroom.dart';
import '../analysis/angle_zoom.dart';
import '../analysis/crop.dart';
import '../analysis/thirds.dart';
import '../analysis/guide_metrics.dart';
import '../analysis/guide_step.dart';

String? tiltHintText(AppLocalizations l, TiltHint h) => switch (h) {
  TiltHint.none => null,
  TiltHint.lowerLeft => l.guideLevelLowerLeft,
  TiltHint.lowerRight => l.guideLevelLowerRight,
};

String? headroomText(AppLocalizations l, HeadroomHint h) => switch (h) {
  HeadroomHint.none => null,
  HeadroomHint.raiseCamera => l.guideHeadroomRaise,
  HeadroomHint.lowerCamera => l.guideHeadroomLower,
};

String? angleText(AppLocalizations l, AngleHint h) => switch (h) {
  AngleHint.none => null,
  AngleHint.eyeLevelDown => l.guideAngleEyeLevelDown,
  AngleHint.eyeLevelUp => l.guideAngleEyeLevelUp,
  AngleHint.frontalDown => l.guideAngleFrontalDown,
  AngleHint.frontalUp => l.guideAngleFrontalUp,
};

String? zoomText(AppLocalizations l, ZoomHint h) => switch (h) {
  ZoomHint.none => null,
  ZoomHint.closer => l.guideZoomCloser,
  ZoomHint.farther => l.guideZoomFarther,
};

String cropText(AppLocalizations l, CropWarning c) {
  final sides = <String>[];
  if (c.top) sides.add(l.cropTop);
  if (c.bottom) sides.add(l.cropBottom);
  if (c.left) sides.add(l.cropLeft);
  if (c.right) sides.add(l.cropRight);
  return l.cropCut(sides.join(l.cropSeparator));
}

String thirdsMoveText(AppLocalizations l, ThirdsAlignment t) {
  final parts = <String>[];
  if (t.moveRight) parts.add(l.guideMoveRight);
  if (t.moveLeft) parts.add(l.guideMoveLeft);
  if (t.moveDown) parts.add(l.guideMoveDown);
  if (t.moveUp) parts.add(l.guideMoveUp);
  return parts.join(l.guideMoveSeparator);
}

/// 우선순위 순(tilt→crop→headroom→thirds→angle→zoom) 활성 힌트 문자열 목록.
/// 정렬/적정 상태(none·isAligned)는 제외. 리모컨 전송·다중 힌트 표시에 사용.
List<String> activeHintTexts(AppLocalizations l, GuideMetrics m) {
  final out = <String>[];
  final tilt = tiltHintText(l, m.tilt.hint);
  if (tilt != null) out.add(tilt);
  final crop = m.crop;
  if (crop != null && crop.any) out.add(cropText(l, crop));
  final headroom = m.headroom;
  if (headroom != null) {
    final h = headroomText(l, headroom.hint);
    if (h != null) out.add(h);
  }
  final thirds = m.thirds;
  if (thirds != null && !thirds.isAligned) out.add(thirdsMoveText(l, thirds));
  final angle = angleText(l, m.angle.hint);
  if (angle != null) out.add(angle);
  final zoom = m.zoom;
  if (zoom != null) {
    final z = zoomText(l, zoom.hint);
    if (z != null) out.add(z);
  }
  return out;
}

// pill에는 position("여기로 옮기세요")과 ready("찍으세요!")만 문구가 있다.
// 나머지 단계 문구는 상단 hints 목록이 담당하므로 여기선 빈 문자열.
String stepText(AppLocalizations l, GuideStep s) => switch (s.kind) {
  GuideStepKind.ready => l.guideReady,
  GuideStepKind.position => l.guideMovePrompt,
  _ => '',
};
