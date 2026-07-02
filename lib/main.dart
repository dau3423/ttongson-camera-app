// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
