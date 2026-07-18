// lib/edit/mood.dart
// 순수 Dart — 무드 정의와 온디바이스 기본 프리셋(AI 실패 시 폴백).
import '../analysis/mood_adjust.dart';

enum Mood { warm, cool, film, moody, vivid, bw }

extension MoodInfo on Mood {
  String get label => switch (this) {
    Mood.warm => '따뜻하게',
    Mood.cool => '시원하게',
    Mood.film => '필름',
    Mood.moody => '무디',
    Mood.vivid => '쨍하게',
    Mood.bw => '흑백',
  };

  String get wire => name; // 'warm','cool','film','moody','vivid','bw'

  /// AI 실패/오프라인 시 사용할 기본 보정값.
  MoodParams get preset => switch (this) {
    Mood.warm => const MoodParams(
      temperature: 0.35,
      brightness: 0.05,
      saturation: 0.1,
    ),
    Mood.cool => const MoodParams(temperature: -0.35, saturation: 0.05),
    Mood.film => const MoodParams(
      contrast: -0.15,
      saturation: -0.1,
      temperature: 0.1,
      tint: 0.08,
    ),
    Mood.moody => const MoodParams(
      saturation: -0.35,
      contrast: 0.1,
      brightness: -0.05,
    ),
    Mood.vivid => const MoodParams(saturation: 0.4, contrast: 0.15),
    Mood.bw => const MoodParams(grayscale: true, contrast: 0.1),
  };
}
