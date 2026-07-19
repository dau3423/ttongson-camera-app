import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/photo_naming.dart';

void main() {
  group('sanitizeFilename', () {
    test('금지문자 제거', () {
      expect(sanitizeFilename('노을/커피:잔*?'), '노을커피잔');
    });
    test('공백은 밑줄로, 앞뒤 정리', () {
      expect(sanitizeFilename('  노을 삼킨 커피잔 '), '노을_삼킨_커피잔');
    });
    test('빈 값/공백뿐이면 fallback', () {
      expect(sanitizeFilename('   '), 'photo');
      expect(sanitizeFilename('///'), 'photo');
      expect(sanitizeFilename('', fallback: 'shot'), 'shot');
    });
    test('40자로 제한', () {
      final long = 'ㄱ' * 60;
      expect(sanitizeFilename(long).length, 40);
    });
  });
}
