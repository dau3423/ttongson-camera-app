import '../models/person_box.dart';
import 'tilt.dart';
import 'thirds.dart';
import 'headroom.dart';
import 'crop.dart';
import 'angle_zoom.dart';

/// 한 프레임에 대한 모든 실시간 가이드 지표의 집계.
class GuideMetrics {
  final TiltInfo tilt;
  final PersonBox? person;
  final ThirdsAlignment? thirds;
  final HeadroomAdvice? headroom;
  final CropWarning? crop;
  final AngleAdvice angle;
  final ZoomAdvice? zoom;

  const GuideMetrics({
    required this.tilt,
    required this.angle,
    this.person,
    this.thirds,
    this.headroom,
    this.crop,
    this.zoom,
  });
}
