import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/edit/mood.dart';

void main() {
  test('무드 6종이 존재하고 라벨/wire가 비어있지 않다', () {
    expect(Mood.values.length, 6);
    for (final m in Mood.values) {
      expect(m.label.isNotEmpty, isTrue);
      expect(m.wire.isNotEmpty, isTrue);
    }
  });

  test('wire 키가 서로 겹치지 않는다', () {
    final wires = Mood.values.map((m) => m.wire).toSet();
    expect(wires.length, Mood.values.length);
  });

  test('bw 프리셋은 grayscale=true', () {
    expect(Mood.bw.preset.grayscale, isTrue);
  });

  test('vivid 프리셋은 채도가 양수, moody는 음수', () {
    expect(Mood.vivid.preset.saturation, greaterThan(0));
    expect(Mood.moody.preset.saturation, lessThan(0));
  });

  test('warm 프리셋은 색온도 양수, cool은 음수', () {
    expect(Mood.warm.preset.temperature, greaterThan(0));
    expect(Mood.cool.preset.temperature, lessThan(0));
  });
}
