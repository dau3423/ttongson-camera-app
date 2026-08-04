// lib/main.dart
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
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
    await FirebaseAppCheck.instance.activate(
      // 릴리즈: Play Integrity/DeviceCheck (콘솔에 등록돼 있어야 함).
      // 디버그: debug provider — 기기별 debug 토큰을 콘솔 허용 목록에 등록해야 함.
      providerAndroid: kReleaseMode
          ? AndroidPlayIntegrityProvider()
          : AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? AppleDeviceCheckProvider()
          : AppleDebugProvider(),
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
      title: '똥손카메라',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // 카메라 화면이 최상위인지 감지해 스트림을 일시중단/재개(발열 감소)한다.
      navigatorObservers: [routeObserver],
      builder: (context, child) => CommunityTheme(
        controller: themeController,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const CameraScreen(),
    );
  }
}
