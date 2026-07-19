// lib/analysis/photo_naming.dart
// 순수 Dart — AI 이름을 파일시스템 안전 파일명으로 변환.

/// 파일시스템 안전 파일명(확장자 제외). 금지문자 제거, 공백→_, 최대 40자, 빈값이면 fallback.
String sanitizeFilename(String name, {String fallback = 'photo'}) {
  // 금지문자(/ \ : * ? " < > | 및 제어문자) 제거
  var s = name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]'), '');
  // 공백 런을 _로
  s = s.trim().replaceAll(RegExp(r'\s+'), '_');
  if (s.isEmpty) return fallback;
  if (s.length > 40) s = s.substring(0, 40);
  return s;
}
