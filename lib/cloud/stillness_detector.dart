// lib/cloud/stillness_detector.dart
/// 가속도계 크기 샘플로 "정지 지속"을 감지한다.
/// 연속 정지가 stillMs 이상이면 에피소드당 한 번 true. 순수 로직(플러그인 무관).
class StillnessDetector {
  final double moveThreshold;
  final int stillMs;

  double? _lastMagnitude;
  int _stillSinceMs = 0;
  bool _fired = false;

  StillnessDetector({this.moveThreshold = 0.5, this.stillMs = 2000});

  /// 새 샘플. 정지가 stillMs 이상 지속되는 순간 처음 한 번만 true.
  bool update(double magnitude, int nowMs) {
    final prev = _lastMagnitude;
    _lastMagnitude = magnitude;
    if (prev == null) {
      _stillSinceMs = nowMs;
      return false;
    }
    final moved = (magnitude - prev).abs() > moveThreshold;
    if (moved) {
      _stillSinceMs = nowMs;
      _fired = false;
      return false;
    }
    if (!_fired && nowMs - _stillSinceMs >= stillMs) {
      _fired = true;
      return true;
    }
    return false;
  }

  void reset() {
    _lastMagnitude = null;
    _fired = false;
    _stillSinceMs = 0;
  }
}
