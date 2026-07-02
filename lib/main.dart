// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';

void main() {
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
