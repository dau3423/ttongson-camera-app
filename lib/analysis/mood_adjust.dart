// lib/analysis/mood_adjust.dart
// 순수 Dart — Flutter/plugin/image 패키지 import 금지.

/// AI/프리셋 보정 파라미터. 모든 값 -1.0~1.0(grayscale 제외).
class MoodParams {
  final double brightness; // + 밝게
  final double contrast; // + 대비 강하게
  final double saturation; // + 채도 높게, -1 이면 회색
  final double temperature; // + 웜(앰버), - 쿨(블루)
  final double tint; // + 마젠타, - 그린
  final bool grayscale;

  const MoodParams({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.grayscale = false,
  });

  static const MoodParams identity = MoodParams();

  factory MoodParams.fromJson(Map<String, dynamic> json) {
    double c(dynamic v) => v is num ? v.toDouble().clamp(-1.0, 1.0) : 0.0;
    return MoodParams(
      brightness: c(json['brightness']),
      contrast: c(json['contrast']),
      saturation: c(json['saturation']),
      temperature: c(json['temperature']),
      tint: c(json['tint']),
      grayscale: json['grayscale'] == true,
    );
  }
}

int _clamp255(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());

/// RGB(0~255)에 보정을 적용해 클램프된 RGB를 반환.
/// 순서: 밝기 → 대비 → 색온도/틴트 → 채도 → 흑백.
(int, int, int) adjustRgb(int r, int g, int b, MoodParams p) {
  double rd = r.toDouble(), gd = g.toDouble(), bd = b.toDouble();

  // 밝기: -1~1 → -128~+128 이동
  final br = p.brightness * 128.0;
  rd += br;
  gd += br;
  bd += br;

  // 대비: f=1+contrast, 128 기준 스케일
  final f = 1.0 + p.contrast;
  rd = (rd - 128) * f + 128;
  gd = (gd - 128) * f + 128;
  bd = (bd - 128) * f + 128;

  // 색온도(웜=+R,-B) / 틴트(마젠타=-G)
  rd += p.temperature * 60.0;
  bd -= p.temperature * 60.0;
  gd -= p.tint * 60.0;

  // 채도: luminance 기준 확대/축소
  final lum = 0.299 * rd + 0.587 * gd + 0.114 * bd;
  final s = 1.0 + p.saturation;
  rd = lum + (rd - lum) * s;
  gd = lum + (gd - lum) * s;
  bd = lum + (bd - lum) * s;

  if (p.grayscale) {
    final gl = 0.299 * rd + 0.587 * gd + 0.114 * bd;
    rd = gl;
    gd = gl;
    bd = gl;
  }

  return (_clamp255(rd), _clamp255(gd), _clamp255(bd));
}
