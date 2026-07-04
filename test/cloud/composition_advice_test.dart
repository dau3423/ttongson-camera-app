import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/cloud/composition_advice.dart';

void main() {
  test('정상 JSON을 파싱한다', () {
    final a = CompositionAdvice.fromJson({
      'headline': '인물을 오른쪽 3분할선으로',
      'directions': [
        {'axis': 'move', 'instruction': '오른쪽으로 한 걸음'},
        {'axis': 'angle', 'instruction': '살짝 낮게'},
      ],
      'rationale': '여백이 넓어 답답합니다',
    });
    expect(a.headline, '인물을 오른쪽 3분할선으로');
    expect(a.directions.length, 2);
    expect(a.directions.first.axis, AdviceAxis.move);
    expect(a.directions[1].axis, AdviceAxis.angle);
    expect(a.rationale, contains('여백'));
  });

  test('알 수 없는 axis는 건너뛴다', () {
    final a = CompositionAdvice.fromJson({
      'headline': 'x',
      'directions': [
        {'axis': 'spin', 'instruction': 'y'},
        {'axis': 'zoom', 'instruction': '조금 당기세요'},
      ],
      'rationale': 'z',
    });
    expect(a.directions.length, 1);
    expect(a.directions.first.axis, AdviceAxis.zoom);
  });

  test('directions 누락 시 빈 목록', () {
    final a = CompositionAdvice.fromJson({'headline': 'x', 'rationale': 'z'});
    expect(a.directions, isEmpty);
    expect(a.headline, 'x');
  });
}
