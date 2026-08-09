// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '똥손카메라';

  @override
  String get guideLevelLowerLeft => '왼쪽을 내리세요';

  @override
  String get guideLevelLowerRight => '오른쪽을 내리세요';

  @override
  String get guideHeadroomRaise => '카메라를 살짝 올리세요';

  @override
  String get guideHeadroomLower => '카메라를 살짝 내리세요';

  @override
  String get guideAngleEyeLevelDown => '카메라를 눈높이로 내리세요';

  @override
  String get guideAngleEyeLevelUp => '카메라를 눈높이로 올리세요';

  @override
  String get guideAngleFrontalDown => '카메라를 수평으로 내리세요';

  @override
  String get guideAngleFrontalUp => '카메라를 수평으로 올리세요';

  @override
  String get guideZoomCloser => '조금 다가가거나 확대하세요';

  @override
  String get guideZoomFarther => '조금 물러나거나 축소하세요';

  @override
  String get guideMoveRight => '오른쪽으로';

  @override
  String get guideMoveLeft => '왼쪽으로';

  @override
  String get guideMoveUp => '위로';

  @override
  String get guideMoveDown => '아래로';

  @override
  String get guideMoveSeparator => ' · ';

  @override
  String get guideMovePrompt => '여기로 옮기세요';

  @override
  String get guideReady => '찍으세요!';

  @override
  String get cropTop => '위';

  @override
  String get cropBottom => '아래';

  @override
  String get cropLeft => '왼쪽';

  @override
  String get cropRight => '오른쪽';

  @override
  String get cropSeparator => '/';

  @override
  String cropCut(String sides) {
    return '$sides이(가) 잘렸어요';
  }
}
