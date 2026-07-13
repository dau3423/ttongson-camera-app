import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/theme/app_theme.dart';

void main() {
  testWidgets('다크 테마의 기본 본문 폰트는 Pretendard (촬영·커뮤니티 텍스트 상속)', (tester) async {
    late TextStyle bodyDefault;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              bodyDefault = DefaultTextStyle.of(context).style;
              return const Text('x');
            },
          ),
        ),
      ),
    );
    expect(bodyDefault.fontFamily, 'Pretendard');
  });

  testWidgets('fontFamily 없는 TextStyle은 병합 시 Pretendard를 유지', (tester) async {
    late TextStyle merged;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              const partial = TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              );
              merged = DefaultTextStyle.of(context).style.merge(partial);
              return const Text('x');
            },
          ),
        ),
      ),
    );
    expect(merged.fontFamily, 'Pretendard');
    expect(merged.fontSize, 16);
  });
}
