// lib/community/nickname_generator.dart
// 순수 Dart — Flutter/plugin import 금지.
import 'dart:math';

const nicknameAdjectives = [
  '귀여운',
  '용감한',
  '느긋한',
  '엉뚱한',
  '따뜻한',
  '수줍은',
  '씩씩한',
  '나른한',
];
const nicknameAnimals = ['너구리', '수달', '고양이', '판다', '여우', '펭귄', '고슴도치', '알파카'];

/// 형용사+동물+숫자(0~9999) 랜덤 닉네임. [random] 주입 시 결정적(테스트용).
String generateNickname({Random? random}) {
  final r = random ?? Random();
  final adj = nicknameAdjectives[r.nextInt(nicknameAdjectives.length)];
  final animal = nicknameAnimals[r.nextInt(nicknameAnimals.length)];
  final number = r.nextInt(10000);
  return '$adj$animal$number';
}
