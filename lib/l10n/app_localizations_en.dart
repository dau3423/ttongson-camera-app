// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ddongson Camera';

  @override
  String get guideLevelLowerLeft => 'Lower the left side';

  @override
  String get guideLevelLowerRight => 'Lower the right side';

  @override
  String get guideHeadroomRaise => 'Raise the camera slightly';

  @override
  String get guideHeadroomLower => 'Lower the camera slightly';

  @override
  String get guideAngleEyeLevelDown => 'Tilt camera down to eye level';

  @override
  String get guideAngleEyeLevelUp => 'Tilt camera up to eye level';

  @override
  String get guideAngleFrontalDown => 'Tilt camera down to horizontal';

  @override
  String get guideAngleFrontalUp => 'Tilt camera up to horizontal';

  @override
  String get guideZoomCloser => 'Move closer or zoom in';

  @override
  String get guideZoomFarther => 'Move back or zoom out';

  @override
  String get guideMoveRight => 'right';

  @override
  String get guideMoveLeft => 'left';

  @override
  String get guideMoveUp => 'up';

  @override
  String get guideMoveDown => 'down';

  @override
  String get guideMoveSeparator => ' · ';

  @override
  String get guideMovePrompt => 'Move here';

  @override
  String get guideReady => 'Shoot!';

  @override
  String get cropTop => 'top';

  @override
  String get cropBottom => 'bottom';

  @override
  String get cropLeft => 'left';

  @override
  String get cropRight => 'right';

  @override
  String get cropSeparator => '/';

  @override
  String cropCut(String sides) {
    return '$sides is cut off';
  }
}
