// lib/edit/named_saver.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// src 파일을 `{filename}.jpg` 임시 파일로 복사해 반환한다.
/// 갤러리 저장기가 파일명을 파일 basename에서 가져오므로, AI 이름을 파일명으로 남기는 용도.
Future<File> saveAsNamed({
  required File src,
  required String filename,
  Directory? dir,
}) async {
  final d = dir ?? await getTemporaryDirectory();
  final out = File('${d.path}/$filename.jpg');
  return src.copy(out.path);
}
