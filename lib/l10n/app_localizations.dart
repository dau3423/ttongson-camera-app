import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'똥손카메라'**
  String get appTitle;

  /// No description provided for @guideLevelLowerLeft.
  ///
  /// In ko, this message translates to:
  /// **'왼쪽을 내리세요'**
  String get guideLevelLowerLeft;

  /// No description provided for @guideLevelLowerRight.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽을 내리세요'**
  String get guideLevelLowerRight;

  /// No description provided for @guideHeadroomRaise.
  ///
  /// In ko, this message translates to:
  /// **'카메라를 살짝 올리세요'**
  String get guideHeadroomRaise;

  /// No description provided for @guideHeadroomLower.
  ///
  /// In ko, this message translates to:
  /// **'카메라를 살짝 내리세요'**
  String get guideHeadroomLower;

  /// No description provided for @guideAngleEyeLevelDown.
  ///
  /// In ko, this message translates to:
  /// **'카메라를 눈높이로 내리세요'**
  String get guideAngleEyeLevelDown;

  /// No description provided for @guideAngleEyeLevelUp.
  ///
  /// In ko, this message translates to:
  /// **'카메라를 눈높이로 올리세요'**
  String get guideAngleEyeLevelUp;

  /// No description provided for @guideAngleFrontalDown.
  ///
  /// In ko, this message translates to:
  /// **'카메라를 수평으로 내리세요'**
  String get guideAngleFrontalDown;

  /// No description provided for @guideAngleFrontalUp.
  ///
  /// In ko, this message translates to:
  /// **'카메라를 수평으로 올리세요'**
  String get guideAngleFrontalUp;

  /// No description provided for @guideZoomCloser.
  ///
  /// In ko, this message translates to:
  /// **'조금 다가가거나 확대하세요'**
  String get guideZoomCloser;

  /// No description provided for @guideZoomFarther.
  ///
  /// In ko, this message translates to:
  /// **'조금 물러나거나 축소하세요'**
  String get guideZoomFarther;

  /// No description provided for @guideMoveRight.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽으로'**
  String get guideMoveRight;

  /// No description provided for @guideMoveLeft.
  ///
  /// In ko, this message translates to:
  /// **'왼쪽으로'**
  String get guideMoveLeft;

  /// No description provided for @guideMoveUp.
  ///
  /// In ko, this message translates to:
  /// **'위로'**
  String get guideMoveUp;

  /// No description provided for @guideMoveDown.
  ///
  /// In ko, this message translates to:
  /// **'아래로'**
  String get guideMoveDown;

  /// No description provided for @guideMoveSeparator.
  ///
  /// In ko, this message translates to:
  /// **' · '**
  String get guideMoveSeparator;

  /// No description provided for @guideMovePrompt.
  ///
  /// In ko, this message translates to:
  /// **'여기로 옮기세요'**
  String get guideMovePrompt;

  /// No description provided for @guideReady.
  ///
  /// In ko, this message translates to:
  /// **'찍으세요!'**
  String get guideReady;

  /// No description provided for @cropTop.
  ///
  /// In ko, this message translates to:
  /// **'위'**
  String get cropTop;

  /// No description provided for @cropBottom.
  ///
  /// In ko, this message translates to:
  /// **'아래'**
  String get cropBottom;

  /// No description provided for @cropLeft.
  ///
  /// In ko, this message translates to:
  /// **'왼쪽'**
  String get cropLeft;

  /// No description provided for @cropRight.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽'**
  String get cropRight;

  /// No description provided for @cropSeparator.
  ///
  /// In ko, this message translates to:
  /// **'/'**
  String get cropSeparator;

  /// No description provided for @cropCut.
  ///
  /// In ko, this message translates to:
  /// **'{sides}이(가) 잘렸어요'**
  String cropCut(String sides);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
