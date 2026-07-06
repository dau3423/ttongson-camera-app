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

  testWidgets('느린 드래그(플릭 아님)로도 전환된다 — 좌로 끌면 다음 모드', (tester) async {
    ShootingMode? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ModeSelector(
              current: ShootingMode.person,
              onChanged: (m) => picked = m,
            ),
          ),
        ),
      ),
    );
    // 손가락을 천천히 왼쪽으로 끌다가(릴리스 속도 낮음) 뗀다.
    final center = tester.getCenter(find.byType(ModeSelector));
    final g = await tester.startGesture(center);
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(
      picked,
      ShootingMode.nature,
      reason: '느린 좌드래그(총 -160px)도 person→nature 로 전환되어야 한다',
    );
  });

  testWidgets('우로 끌면 이전 모드', (tester) async {
    ShootingMode? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ModeSelector(
              current: ShootingMode.person,
              onChanged: (m) => picked = m,
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(ModeSelector));
    final g = await tester.startGesture(center);
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(
      picked,
      ShootingMode.object,
      reason: '느린 우드래그도 person→object(순환 이전)로 전환되어야 한다',
    );
  });
}
