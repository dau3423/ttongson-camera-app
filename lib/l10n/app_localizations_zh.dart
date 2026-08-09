// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '手残相机';

  @override
  String get guideLevelLowerLeft => '请降低左侧';

  @override
  String get guideLevelLowerRight => '请降低右侧';

  @override
  String get guideHeadroomRaise => '请稍微抬高相机';

  @override
  String get guideHeadroomLower => '请稍微放低相机';

  @override
  String get guideAngleEyeLevelDown => '请将相机向下调至眼平高度';

  @override
  String get guideAngleEyeLevelUp => '请将相机向上调至眼平高度';

  @override
  String get guideAngleFrontalDown => '请将相机向下调至水平';

  @override
  String get guideAngleFrontalUp => '请将相机向上调至水平';

  @override
  String get guideZoomCloser => '请靠近一点或放大';

  @override
  String get guideZoomFarther => '请退后一点或缩小';

  @override
  String get guideMoveRight => '向右';

  @override
  String get guideMoveLeft => '向左';

  @override
  String get guideMoveUp => '向上';

  @override
  String get guideMoveDown => '向下';

  @override
  String get guideMoveSeparator => ' · ';

  @override
  String get guideMovePrompt => '移到这里';

  @override
  String get guideReady => '拍吧！';

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
    return '$sides被截掉了';
  }
}
