// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'へたっぴカメラ';

  @override
  String get guideLevelLowerLeft => '左側を下げてください';

  @override
  String get guideLevelLowerRight => '右側を下げてください';

  @override
  String get guideHeadroomRaise => 'カメラを少し上げてください';

  @override
  String get guideHeadroomLower => 'カメラを少し下げてください';

  @override
  String get guideAngleEyeLevelDown => 'カメラを目線の高さまで下げてください';

  @override
  String get guideAngleEyeLevelUp => 'カメラを目線の高さまで上げてください';

  @override
  String get guideAngleFrontalDown => 'カメラを水平に下げてください';

  @override
  String get guideAngleFrontalUp => 'カメラを水平に上げてください';

  @override
  String get guideZoomCloser => '少し近づくかズームインしてください';

  @override
  String get guideZoomFarther => '少し離れるかズームアウトしてください';

  @override
  String get guideMoveRight => '右へ';

  @override
  String get guideMoveLeft => '左へ';

  @override
  String get guideMoveUp => '上へ';

  @override
  String get guideMoveDown => '下へ';

  @override
  String get guideMoveSeparator => ' · ';

  @override
  String get guideMovePrompt => 'ここに移動してください';

  @override
  String get guideReady => '撮ろう！';

  @override
  String get cropTop => '上';

  @override
  String get cropBottom => '下';

  @override
  String get cropLeft => '左';

  @override
  String get cropRight => '右';

  @override
  String get cropSeparator => '/';

  @override
  String cropCut(String sides) {
    return '$sidesが切れています';
  }
}
