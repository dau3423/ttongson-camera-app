import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/poses/pose_advisor.dart';

void main() {
  test('서버 결과 맵을 PoseSuggestion으로 파싱', () {
    final s = poseSuggestionFromResult({
      'poseId': 'couple_01',
      'reason': '두 명이라 커플',
    });
    expect(s.poseId, 'couple_01');
    expect(s.reason, '두 명이라 커플');
  });

  test('reason 누락 시 빈 문자열, poseId 누락 시 빈 문자열', () {
    final s = poseSuggestionFromResult({'poseId': 'x'});
    expect(s.poseId, 'x');
    expect(s.reason, '');
    final s2 = poseSuggestionFromResult({});
    expect(s2.poseId, '');
  });
}
