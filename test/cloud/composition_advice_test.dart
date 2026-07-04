import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/composition_advice.dart';

void main() {
  test('정상 JSON을 파싱한다(targetBox 포함)', () {
    final a = CompositionAdvice.fromJson({
      'headline': '인물을 오른쪽 3분할선으로',
      'targetBox': {'x': 0.55, 'y': 0.3, 'width': 0.3, 'height': 0.6},
      'rationale': '여백이 넓어 답답합니다',
    });
    expect(a.headline, '인물을 오른쪽 3분할선으로');
    expect(a.targetBox, isNotNull);
    expect(a.targetBox!.x, 0.55);
    expect(a.targetBox!.centerX, closeTo(0.7, 0.0001));
    expect(a.rationale, contains('여백'));
  });

  test('targetBox 누락 시 null, 나머지는 파싱', () {
    final a = CompositionAdvice.fromJson({'headline': 'x', 'rationale': 'z'});
    expect(a.targetBox, isNull);
    expect(a.headline, 'x');
    expect(a.rationale, 'z');
  });

  test('targetBox 필드가 숫자가 아니면 null', () {
    final a = CompositionAdvice.fromJson({
      'headline': 'x',
      'targetBox': {'x': 'a', 'y': 0.3, 'width': 0.3, 'height': 0.6},
      'rationale': 'z',
    });
    expect(a.targetBox, isNull);
  });

  test('범위를 벗어난 값은 0~1로 clamp', () {
    final a = CompositionAdvice.fromJson({
      'headline': 'x',
      'targetBox': {'x': 1.2, 'y': -0.1, 'width': 0.3, 'height': 0.6},
      'rationale': 'z',
    });
    expect(a.targetBox!.x, 1.0);
    expect(a.targetBox!.y, 0.0);
  });
}
