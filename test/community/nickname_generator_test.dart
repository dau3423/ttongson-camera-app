import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/nickname_generator.dart';

void main() {
  test('같은 시드면 결정적(동일 결과)', () {
    expect(
      generateNickname(random: Random(42)),
      generateNickname(random: Random(42)),
    );
  });

  test('ko는 한국어 형용사+동물', () {
    final n = generateNickname(random: Random(1), localeCode: 'ko');
    expect(RegExp(r'[가-힣]').hasMatch(n), isTrue);
    expect(RegExp(r'\d+$').hasMatch(n), isTrue);
  });

  test('en은 영어 단어', () {
    final n = generateNickname(random: Random(1), localeCode: 'en');
    expect(RegExp(r'[A-Za-z]').hasMatch(n), isTrue);
    expect(RegExp(r'[가-힣]').hasMatch(n), isFalse);
    expect(RegExp(r'\d+$').hasMatch(n), isTrue);
  });

  test('ja는 일본어 단어', () {
    final n = generateNickname(random: Random(1), localeCode: 'ja');
    // hiragana/katakana range
    expect(RegExp(r'[぀-ヿ]').hasMatch(n), isTrue);
    expect(RegExp(r'[가-힣]').hasMatch(n), isFalse);
  });

  test('zh는 한자 단어', () {
    final n = generateNickname(random: Random(1), localeCode: 'zh');
    expect(RegExp(r'[一-鿿]').hasMatch(n), isTrue);
    expect(RegExp(r'[가-힣]').hasMatch(n), isFalse);
  });

  test('미지원 로케일은 ko 폴백', () {
    final n = generateNickname(random: Random(1), localeCode: 'xx');
    expect(RegExp(r'[가-힣]').hasMatch(n), isTrue);
  });

  test('기본 localeCode는 ko', () {
    final n = generateNickname(random: Random(1));
    expect(RegExp(r'[가-힣]').hasMatch(n), isTrue);
  });
}
