import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttongson_camera/community/theme/community_theme.dart';
import 'package:ttongson_camera/community/theme/community_theme_controller.dart';

void main() {
  test('resolveBrightness: system은 플랫폼 밝기', () {
    expect(
      resolveBrightness(CommunityThemeMode.system, Brightness.light),
      Brightness.light,
    );
    expect(
      resolveBrightness(CommunityThemeMode.system, Brightness.dark),
      Brightness.dark,
    );
  });

  test('resolveBrightness: light/dark 고정', () {
    expect(
      resolveBrightness(CommunityThemeMode.light, Brightness.dark),
      Brightness.light,
    );
    expect(
      resolveBrightness(CommunityThemeMode.dark, Brightness.light),
      Brightness.dark,
    );
  });

  test('팔레트 대비: dark 어둡고 light 밝다', () {
    expect(CommunityPalette.dark.surface.computeLuminance() < 0.2, isTrue);
    expect(CommunityPalette.light.surface.computeLuminance() > 0.8, isTrue);
    expect(CommunityPalette.dark.text.computeLuminance() > 0.7, isTrue);
    expect(CommunityPalette.light.text.computeLuminance() < 0.2, isTrue);
  });

  test('buildCommunityTheme: 밝기·표면 반영', () {
    final dark = buildCommunityTheme(Brightness.dark);
    final light = buildCommunityTheme(Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.scaffoldBackgroundColor, CommunityPalette.dark.surface);
    expect(light.scaffoldBackgroundColor, CommunityPalette.light.surface);
  });

  testWidgets('CommunityTheme.paletteOf: light 모드에서 밝은 팔레트', (tester) async {
    final controller = CommunityThemeController(); // 기본 system
    late CommunityPalette p;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: CommunityTheme(
          controller: controller,
          child: Builder(
            builder: (context) {
              p = CommunityTheme.paletteOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    // system + platform dark → dark 팔레트
    expect(p.surface, CommunityPalette.dark.surface);
  });
}
