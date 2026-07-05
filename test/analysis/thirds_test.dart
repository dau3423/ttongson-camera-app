import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/analysis/thirds.dart';

void main() {
  test('교차점 위에 있으면 정렬됨: distance≈0, score≈1, hint 좋아요', () {
    final a = computeThirds(1 / 3, 1 / 3);
    expect(a.distance, lessThan(0.01));
    expect(a.score, closeTo(1.0, 0.01));
    expect(a.hint, '좋아요');
  });

  test('가장 가까운 교차점을 선택한다', () {
    final a = computeThirds(0.66, 0.66);
    expect(a.targetX, closeTo(2 / 3, 0.001));
    expect(a.targetY, closeTo(2 / 3, 0.001));
  });

  test('피사체가 목표점보다 왼쪽/위면 오른쪽·아래로 안내', () {
    // 목표 (1/3,1/3)=(0.333,0.333), 피사체 (0.2,0.2) -> dx>0, dy>0
    final a = computeThirds(0.2, 0.2);
    expect(a.hint, '오른쪽으로 · 아래로');
  });

  test('멀수록 score가 낮다', () {
    final near = computeThirds(0.30, 0.33);
    final far = computeThirds(0.9, 0.9);
    expect(far.score, lessThan(near.score));
  });

  test('입력한 피사체 중심을 currentX/currentY 로 그대로 담는다', () {
    final a = computeThirds(0.2, 0.7);
    expect(a.currentX, closeTo(0.2, 1e-9));
    expect(a.currentY, closeTo(0.7, 1e-9));
  });
}
