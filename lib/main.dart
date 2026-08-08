// lib/main.dart
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:ttongson_camera/l10n/app_localizations.dart';
import 'community/kakao_config.dart';
import 'community/theme/community_theme.dart';
import 'community/theme/community_theme_controller.dart';
import 'firebase_options.dart';
import 'screens/camera_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // App Check 콘솔 허용 목록에 등록된 고정 debug 토큰. 디버그 빌드에서만 사용되며,
    // 재설치 시 토큰이 재생성돼 추천 기능이 깨지는 문제를 막는다.
    const debugToken = '00651760-c042-4cca-91e7-56fcddfd60ed';
    await FirebaseAppCheck.instance.activate(
      // 릴리즈: Play Integrity/DeviceCheck (콘솔에 등록돼 있어야 함).
      providerAndroid: kReleaseMode
          ? AndroidPlayIntegrityProvider()
          : AndroidDebugProvider(debugToken: debugToken),
      providerApple: kReleaseMode
          ? AppleDeviceCheckProvider()
          : AppleDebugProvider(debugToken: debugToken),
    );
  } catch (e) {
    // Firebase 초기화 실패해도 온디바이스 카메라 기능은 계속 동작.
    debugPrint('Firebase init failed: $e');
  }
  final themeController = CommunityThemeController();
  await themeController.load();
  runApp(TtongsonApp(themeController: themeController));
}

class TtongsonApp extends StatelessWidget {
  final CommunityThemeController themeController;
  const TtongsonApp({super.key, required this.themeController});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('ko');
        for (final s in supported) {
          if (s.languageCode == locale.languageCode) return s;
        }
        return const Locale('ko');
      },
      navigatorObservers: [routeObserver],
      builder: (context, child) => CommunityTheme(
        controller: themeController,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const CameraScreen(),
    );
  }
}
