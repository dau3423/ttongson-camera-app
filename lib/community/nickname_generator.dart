// lib/community/nickname_generator.dart
// 순수 Dart — Flutter/plugin import 금지.
import 'dart:math';

const _adjKo = ['귀여운', '용감한', '느긋한', '엉뚱한', '따뜻한', '수줍은', '씩씩한', '나른한'];
const _animalKo = ['너구리', '수달', '고양이', '판다', '여우', '펭귄', '고슴도치', '알파카'];
const _adjEn = [
  'Cute',
  'Brave',
  'Chill',
  'Quirky',
  'Warm',
  'Shy',
  'Bold',
  'Sleepy',
];
const _animalEn = [
  'Raccoon',
  'Otter',
  'Cat',
  'Panda',
  'Fox',
  'Penguin',
  'Hedgehog',
  'Alpaca',
];
const _adjJa = ['かわいい', 'ゆうかんな', 'のんびり', 'ふしぎな', 'あたたかい', 'てれや', 'げんきな', 'ねむい'];
const _animalJa = ['たぬき', 'かわうそ', 'ねこ', 'パンダ', 'きつね', 'ペンギン', 'はりねずみ', 'アルパカ'];
const _adjZh = ['可爱的', '勇敢的', '悠闲的', '古怪的', '温暖的', '害羞的', '活泼的', '慵懒的'];
const _animalZh = ['浣熊', '水獭', '猫', '熊猫', '狐狸', '企鹅', '刺猬', '羊驼'];

/// 형용사+동물+숫자(0~9999) 랜덤 닉네임. [random] 주입 시 결정적(테스트용).
/// [localeCode]에 맞는 단어 목록을 사용하며, 미지원 코드는 ko로 폴백.
String generateNickname({Random? random, String localeCode = 'ko'}) {
  final r = random ?? Random();
  final (adjs, animals) = switch (localeCode) {
    'en' => (_adjEn, _animalEn),
    'ja' => (_adjJa, _animalJa),
    'zh' => (_adjZh, _animalZh),
    _ => (_adjKo, _animalKo),
  };
  final adj = adjs[r.nextInt(adjs.length)];
  final animal = animals[r.nextInt(animals.length)];
  final number = r.nextInt(10000);
  final sep = localeCode == 'en' ? ' ' : '';
  return '$adj$sep$animal$number';
}
