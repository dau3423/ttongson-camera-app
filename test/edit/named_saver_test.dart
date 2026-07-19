import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/edit/named_saver.dart';

void main() {
  test('src를 {filename}.jpg로 복사하고 내용을 보존', () async {
    final tmp = await Directory.systemTemp.createTemp('named_saver');
    final src = File('${tmp.path}/orig.jpg')..writeAsBytesSync([1, 2, 3]);
    final out = await saveAsNamed(src: src, filename: '노을커피', dir: tmp);
    expect(out.path.endsWith('/노을커피.jpg'), isTrue);
    expect(out.readAsBytesSync(), [1, 2, 3]);
  });
}
