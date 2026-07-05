import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/overlay/mode_selector.dart';
import 'package:ttongson_camera/models/shooting_mode.dart';

void main() {
  testWidgets('세 모드 라벨을 모두 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeSelector(current: ShootingMode.person, onChanged: (_) {}),
        ),
      ),
    );
    expect(find.text('인물'), findsOneWidget);
    expect(find.text('자연'), findsOneWidget);
    expect(find.text('사물'), findsOneWidget);
  });

  testWidgets('선택된 모드는 항상 가운데 슬롯에 표시', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ModeSelector(
              current: ShootingMode.nature,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    final selectorCenter = tester.getCenter(find.byType(ModeSelector)).dx;
    final selectedCenter = tester.getCenter(find.text('자연')).dx;
    expect((selectedCenter - selectorCenter).abs(), lessThan(1.0));
  });

  testWidgets('다른 라벨 탭 시 onChanged 로 해당 모드 전달', (tester) async {
    ShootingMode? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeSelector(
            current: ShootingMode.person,
            onChanged: (m) => picked = m,
          ),
        ),
      ),
    );
    await tester.tap(find.text('사물'));
    expect(picked, ShootingMode.object);
  });
}
