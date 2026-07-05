import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/nickname_generator.dart';

void main() {
  test('형식: 형용사+동물+숫자(0~9999)', () {
    final n = generateNickname(random: Random(1));
    // 숫자로 끝난다
    expect(RegExp(r'\d+$').hasMatch(n), isTrue);
    // 목록의 형용사로 시작하고, 목록의 동물을 포함한다
    final adj = nicknameAdjectives.firstWhere((a) => n.startsWith(a));
    final rest = n.substring(adj.length);
    final animal = nicknameAnimals.firstWhere((a) => rest.startsWith(a));
    final digits = rest.substring(animal.length);
    expect(int.parse(digits), inInclusiveRange(0, 9999));
  });

  test('같은 시드면 결정적(동일 결과)', () {
    expect(
      generateNickname(random: Random(42)),
      generateNickname(random: Random(42)),
    );
  });
}
