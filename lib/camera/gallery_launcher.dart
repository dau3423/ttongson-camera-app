// lib/camera/gallery_launcher.dart
import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:url_launcher/url_launcher.dart';

/// 기기의 기본 사진첩(갤러리) 앱을 연다. 성공 여부를 반환한다.
///
/// 별도 뷰어/빈 화면이 아니라 사용자가 쓰는 갤러리 앱으로 바로 진입하도록
/// 후보 인텐트를 우선순위대로 시도한다.
Future<bool> openDeviceGallery() async {
  if (Platform.isIOS) {
    // iOS: 사진 앱으로 이동.
    final uri = Uri.parse('photos-redirect://');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  if (Platform.isAndroid) {
    // 우선순위: (1) 기본 갤러리 앱 홈(선택창 없이 바로 이동)
    //          (2) 이미지 보기(갤러리 앱이 처리, 필요 시 기본 앱으로 이동)
    final candidates = <AndroidIntent>[
      const AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.APP_GALLERY',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ),
      const AndroidIntent(
        action: 'android.intent.action.VIEW',
        type: 'image/*',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ),
    ];
    for (final intent in candidates) {
      try {
        await intent.launch();
        return true;
      } catch (_) {
        // 이 인텐트를 처리할 앱이 없으면 다음 후보로.
      }
    }
    return false;
  }
  return false;
}
