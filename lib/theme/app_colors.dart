import 'package:flutter/material.dart';

/// 앱 전역 디자인 토큰(색상). 디자인 핸드오프 기준값을 한곳에서 관리한다.
/// 오버레이·컨트롤은 리터럴 대신 이 값을 참조한다.
class AppColors {
  AppColors._();

  // 브랜드/상태
  static const accent = Color(0xFFFFC107); // 선택 모드·목표·CTA
  static const ready = Color(0xFF69F0AE); // 수평·정렬·성공
  static const warn = Color(0xFFFF5252); // 기울기 경고
  static const danger = Color(0xFFFF3B30); // 파괴적 액션
  static const error = Color(0xFFFF6B6B); // 인라인 입력 에러

  // 표면
  static const surfaceApp = Color(0xFF0B0C0E);
  static const surfaceCard = Color(0xFF1C1E22);

  // 오버레이 스크림(검정 반투명)
  static const scrimPill = Color(0xD9000000); // 단계 pill 배경 0.85
  static const scrimAdvice = Color(0xDE000000); // 조언 카드 배경 0.87
  static const scrimMinimap = Color(0x73000000); // 미니맵 배경 0.45
  static const scrimZoom = Color(0x8C000000); // 줌 pill 배경 0.55

  // 완료 배지 배경 rgba(46,125,50,0.95)
  static const readyBadge = Color(0xF22E7D32);

  // 별(조언 아이콘)
  static const star = Color(0xFFFFD54F);
}
