// lib/analysis/photo_naming.dart
// 순수 Dart — 파일명 안전화와 EXIF 설명 문자열 조립.

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

/// EXIF ImageDescription용 문자열. 이름과 태그를 사람이 읽기 좋게 합친다.
String formatExifDescription(String name, List<String> tags) {
  final n = name.trim();
  final t = tags.where((e) => e.trim().isNotEmpty).join(', ');
  if (n.isEmpty) return t;
  if (t.isEmpty) return n;
  return '$n · $t';
}
