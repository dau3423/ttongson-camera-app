// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'community/kakao_config.dart';
import 'firebase_options.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      // 디버그: 개발 중에는 debug provider, 배포 시 Play Integrity/DeviceCheck로 교체.
      providerAndroid: AndroidDebugProvider(),
      providerApple: AppleDebugProvider(),
    );
  } catch (e) {
    // Firebase 초기화 실패해도 온디바이스 카메라 기능은 계속 동작.
    debugPrint('Firebase init failed: $e');
  }
  runApp(const TtongsonApp());
}

class TtongsonApp extends StatelessWidget {
  const TtongsonApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '똥손카메라',
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}
