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

  /// No description provided for @commonCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get commonCancel;

  /// No description provided for @commonAgree.
  ///
  /// In ko, this message translates to:
  /// **'동의'**
  String get commonAgree;

  /// No description provided for @commonRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get commonRetry;

  /// No description provided for @cameraSwitchFailed.
  ///
  /// In ko, this message translates to:
  /// **'카메라 전환에 실패했어요'**
  String get cameraSwitchFailed;

  /// No description provided for @galleryOpenFailed.
  ///
  /// In ko, this message translates to:
  /// **'사진첩을 열 수 없어요'**
  String get galleryOpenFailed;

  /// No description provided for @saveFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장 실패: {error}'**
  String saveFailed(String error);

  /// No description provided for @compositionConsentTitle.
  ///
  /// In ko, this message translates to:
  /// **'구도 추천 안내'**
  String get compositionConsentTitle;

  /// No description provided for @compositionConsentBody.
  ///
  /// In ko, this message translates to:
  /// **'구도 추천 시 현재 화면 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.'**
  String get compositionConsentBody;

  /// No description provided for @suggestFailed.
  ///
  /// In ko, this message translates to:
  /// **'추천을 못 받았어요. 다시 시도해 주세요.'**
  String get suggestFailed;

  /// No description provided for @posesLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'포즈를 불러오지 못했어요'**
  String get posesLoadFailed;

  /// No description provided for @aiConsentTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 추천 안내'**
  String get aiConsentTitle;

  /// No description provided for @aiConsentBody.
  ///
  /// In ko, this message translates to:
  /// **'추천 시 현재 화면 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.'**
  String get aiConsentBody;

  /// No description provided for @cameraRestartFailedDetail.
  ///
  /// In ko, this message translates to:
  /// **'카메라를 다시 시작하지 못했어요: {error}'**
  String cameraRestartFailedDetail(String error);

  /// No description provided for @wifiNotConnected.
  ///
  /// In ko, this message translates to:
  /// **'Wi-Fi에 연결돼 있지 않아요. 같은 Wi-Fi 또는 핫스팟에 연결해 주세요.'**
  String get wifiNotConnected;

  /// No description provided for @remotePrepFailed.
  ///
  /// In ko, this message translates to:
  /// **'리모컨 연결 준비에 실패했어요. 잠시 후 다시 시도해 주세요.'**
  String get remotePrepFailed;

  /// No description provided for @remoteConnected.
  ///
  /// In ko, this message translates to:
  /// **'리모컨 연결됨'**
  String get remoteConnected;

  /// No description provided for @remoteWaiting.
  ///
  /// In ko, this message translates to:
  /// **'리모컨 대기 중'**
  String get remoteWaiting;

  /// No description provided for @captureAiEnhanceConsentTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 보정 안내'**
  String get captureAiEnhanceConsentTitle;

  /// No description provided for @captureAiEnhanceConsentBody.
  ///
  /// In ko, this message translates to:
  /// **'AI 보정 시 사진 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.'**
  String get captureAiEnhanceConsentBody;

  /// No description provided for @captureEnhanceFailed.
  ///
  /// In ko, this message translates to:
  /// **'이 사진은 보정할 수 없어요'**
  String get captureEnhanceFailed;

  /// No description provided for @captureAiEnhanceFailed.
  ///
  /// In ko, this message translates to:
  /// **'AI 개선을 못 받았어요. 프리셋을 유지합니다.'**
  String get captureAiEnhanceFailed;

  /// No description provided for @captureSaved.
  ///
  /// In ko, this message translates to:
  /// **'저장했어요'**
  String get captureSaved;

  /// No description provided for @captureSavePermissionFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장 실패 — 권한을 확인해 주세요'**
  String get captureSavePermissionFailed;

  /// No description provided for @captureMoodTitle.
  ///
  /// In ko, this message translates to:
  /// **'오늘의 무드'**
  String get captureMoodTitle;

  /// No description provided for @captureAiEnhanceTooltip.
  ///
  /// In ko, this message translates to:
  /// **'AI로 더 예쁘게 (이 사진에 맞게)'**
  String get captureAiEnhanceTooltip;

  /// No description provided for @captureSaveButton.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get captureSaveButton;

  /// No description provided for @captureNameHint.
  ///
  /// In ko, this message translates to:
  /// **'AI가 이름을 지어줘요'**
  String get captureNameHint;

  /// No description provided for @captureOriginalLabel.
  ///
  /// In ko, this message translates to:
  /// **'원본'**
  String get captureOriginalLabel;

  /// No description provided for @authWelcomeBack.
  ///
  /// In ko, this message translates to:
  /// **'다시 오셨네요'**
  String get authWelcomeBack;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'똥손도 프로처럼 · 로그인하고 이어서 찍기'**
  String get authLoginSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get authPasswordLabel;

  /// No description provided for @authLoginButton.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get authLoginButton;

  /// No description provided for @authOrDivider.
  ///
  /// In ko, this message translates to:
  /// **'또는'**
  String get authOrDivider;

  /// No description provided for @authNoAccount.
  ///
  /// In ko, this message translates to:
  /// **'아직 계정이 없으신가요? '**
  String get authNoAccount;

  /// No description provided for @authSignupLink.
  ///
  /// In ko, this message translates to:
  /// **'회원가입'**
  String get authSignupLink;

  /// No description provided for @authEmailEmpty.
  ///
  /// In ko, this message translates to:
  /// **'이메일과 비밀번호를 입력해주세요.'**
  String get authEmailEmpty;

  /// No description provided for @authInvalidEmail.
  ///
  /// In ko, this message translates to:
  /// **'올바른 이메일 형식이 아니에요.'**
  String get authInvalidEmail;

  /// No description provided for @authLoginFailed.
  ///
  /// In ko, this message translates to:
  /// **'로그인에 실패했어요.'**
  String get authLoginFailed;

  /// No description provided for @authLoginFailedRetry.
  ///
  /// In ko, this message translates to:
  /// **'로그인에 실패했어요. 다시 시도해 주세요.'**
  String get authLoginFailedRetry;

  /// No description provided for @authWrongCredential.
  ///
  /// In ko, this message translates to:
  /// **'이메일 또는 비밀번호가 올바르지 않아요.'**
  String get authWrongCredential;

  /// No description provided for @authAccountDisabled.
  ///
  /// In ko, this message translates to:
  /// **'사용할 수 없는 계정이에요.'**
  String get authAccountDisabled;

  /// No description provided for @authWithdrawnTitle.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴한 계정이에요'**
  String get authWithdrawnTitle;

  /// No description provided for @authWithdrawnBody.
  ///
  /// In ko, this message translates to:
  /// **'이 계정은 탈퇴 처리됐어요. 다시 가입할까요?'**
  String get authWithdrawnBody;

  /// No description provided for @authRejoin.
  ///
  /// In ko, this message translates to:
  /// **'재가입'**
  String get authRejoin;

  /// No description provided for @authLoginSuccess.
  ///
  /// In ko, this message translates to:
  /// **'환영합니다!'**
  String get authLoginSuccess;

  /// No description provided for @authLoginSuccessSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'이제 촬영을 시작해볼까요?'**
  String get authLoginSuccessSubtitle;

  /// No description provided for @authLoginSuccessCta.
  ///
  /// In ko, this message translates to:
  /// **'촬영하러 가기'**
  String get authLoginSuccessCta;

  /// No description provided for @authSignupTitle.
  ///
  /// In ko, this message translates to:
  /// **'가입하기'**
  String get authSignupTitle;

  /// No description provided for @authSignupSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'30초면 충분해요'**
  String get authSignupSubtitle;

  /// No description provided for @authNicknameLabel.
  ///
  /// In ko, this message translates to:
  /// **'닉네임'**
  String get authNicknameLabel;

  /// No description provided for @authNicknameHint.
  ///
  /// In ko, this message translates to:
  /// **'똥손탈출러'**
  String get authNicknameHint;

  /// No description provided for @authPasswordHint.
  ///
  /// In ko, this message translates to:
  /// **'8자 이상'**
  String get authPasswordHint;

  /// No description provided for @authAgreeTerms.
  ///
  /// In ko, this message translates to:
  /// **'이용약관 및 개인정보 처리방침에 동의합니다'**
  String get authAgreeTerms;

  /// No description provided for @authSignupButton.
  ///
  /// In ko, this message translates to:
  /// **'가입하고 시작하기'**
  String get authSignupButton;

  /// No description provided for @authHaveAccount.
  ///
  /// In ko, this message translates to:
  /// **'이미 계정이 있으신가요? '**
  String get authHaveAccount;

  /// No description provided for @authSigninLink.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get authSigninLink;

  /// No description provided for @authAllFieldsRequired.
  ///
  /// In ko, this message translates to:
  /// **'모든 항목을 입력해주세요.'**
  String get authAllFieldsRequired;

  /// No description provided for @authNicknameInvalid.
  ///
  /// In ko, this message translates to:
  /// **'닉네임은 1~20자로 입력해주세요.'**
  String get authNicknameInvalid;

  /// No description provided for @authWeakPassword.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호는 8자 이상이어야 해요.'**
  String get authWeakPassword;

  /// No description provided for @authAgreeRequired.
  ///
  /// In ko, this message translates to:
  /// **'약관에 동의해주세요.'**
  String get authAgreeRequired;

  /// No description provided for @authEmailInUse.
  ///
  /// In ko, this message translates to:
  /// **'이미 가입된 이메일이에요. 로그인해 주세요.'**
  String get authEmailInUse;

  /// No description provided for @authWeakPasswordServer.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호가 너무 약해요. 8자 이상으로 해주세요.'**
  String get authWeakPasswordServer;

  /// No description provided for @authSignupFailed.
  ///
  /// In ko, this message translates to:
  /// **'가입에 실패했어요. 다시 시도해 주세요.'**
  String get authSignupFailed;

  /// No description provided for @authSignupSuccess.
  ///
  /// In ko, this message translates to:
  /// **'가입 완료!'**
  String get authSignupSuccess;

  /// No description provided for @feedTitle.
  ///
  /// In ko, this message translates to:
  /// **'촬영 팁'**
  String get feedTitle;

  /// No description provided for @feedTabPopular.
  ///
  /// In ko, this message translates to:
  /// **'인기'**
  String get feedTabPopular;

  /// No description provided for @feedTabRecent.
  ///
  /// In ko, this message translates to:
  /// **'최신'**
  String get feedTabRecent;

  /// No description provided for @feedFilterAll.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get feedFilterAll;

  /// No description provided for @feedMyAccountTooltip.
  ///
  /// In ko, this message translates to:
  /// **'내 계정'**
  String get feedMyAccountTooltip;

  /// No description provided for @feedLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'불러오지 못했어요'**
  String get feedLoadFailed;

  /// No description provided for @feedEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 게시물이 없어요. 첫 사진을 올려보세요!'**
  String get feedEmpty;

  /// No description provided for @feedReportSuccess.
  ///
  /// In ko, this message translates to:
  /// **'신고되었습니다'**
  String get feedReportSuccess;

  /// No description provided for @feedReportFailed.
  ///
  /// In ko, this message translates to:
  /// **'신고에 실패했어요 (이미 신고했을 수 있어요)'**
  String get feedReportFailed;

  /// No description provided for @feedDeleteSuccess.
  ///
  /// In ko, this message translates to:
  /// **'삭제했어요'**
  String get feedDeleteSuccess;

  /// No description provided for @feedDeleteFailed.
  ///
  /// In ko, this message translates to:
  /// **'삭제에 실패했어요'**
  String get feedDeleteFailed;

  /// No description provided for @feedDeleteTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 글을 삭제할까요?'**
  String get feedDeleteTitle;

  /// No description provided for @feedDeleteBody.
  ///
  /// In ko, this message translates to:
  /// **'삭제하면 되돌릴 수 없어요.'**
  String get feedDeleteBody;

  /// No description provided for @feedDeleteConfirm.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get feedDeleteConfirm;

  /// No description provided for @feedBlockTitle.
  ///
  /// In ko, this message translates to:
  /// **'{name} 님을 차단할까요?'**
  String feedBlockTitle(String name);

  /// No description provided for @feedBlockBody.
  ///
  /// In ko, this message translates to:
  /// **'이 사용자의 게시물과 댓글이 보이지 않아요.'**
  String get feedBlockBody;

  /// No description provided for @feedBlockConfirm.
  ///
  /// In ko, this message translates to:
  /// **'차단'**
  String get feedBlockConfirm;

  /// No description provided for @feedBlockSuccess.
  ///
  /// In ko, this message translates to:
  /// **'차단했어요'**
  String get feedBlockSuccess;

  /// No description provided for @feedBlockFailed.
  ///
  /// In ko, this message translates to:
  /// **'차단에 실패했어요'**
  String get feedBlockFailed;

  /// No description provided for @feedMenuReport.
  ///
  /// In ko, this message translates to:
  /// **'신고하기'**
  String get feedMenuReport;

  /// No description provided for @feedMenuBlock.
  ///
  /// In ko, this message translates to:
  /// **'차단하기'**
  String get feedMenuBlock;

  /// No description provided for @feedMenuDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제하기'**
  String get feedMenuDelete;

  /// No description provided for @postDeleteTooltip.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get postDeleteTooltip;

  /// No description provided for @postDeleteTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 글을 삭제할까요?'**
  String get postDeleteTitle;

  /// No description provided for @postDeleteBody.
  ///
  /// In ko, this message translates to:
  /// **'삭제하면 되돌릴 수 없어요.'**
  String get postDeleteBody;

  /// No description provided for @postDeleteSuccess.
  ///
  /// In ko, this message translates to:
  /// **'삭제했어요'**
  String get postDeleteSuccess;

  /// No description provided for @postDeleteFailed.
  ///
  /// In ko, this message translates to:
  /// **'삭제에 실패했어요'**
  String get postDeleteFailed;

  /// No description provided for @postCommentDeleteTitle.
  ///
  /// In ko, this message translates to:
  /// **'댓글을 삭제할까요?'**
  String get postCommentDeleteTitle;

  /// No description provided for @postCommentDeleteBody.
  ///
  /// In ko, this message translates to:
  /// **'삭제한 댓글은 되돌릴 수 없어요.'**
  String get postCommentDeleteBody;

  /// No description provided for @postCommentSendFailed.
  ///
  /// In ko, this message translates to:
  /// **'댓글 전송에 실패했어요'**
  String get postCommentSendFailed;

  /// No description provided for @postCommentHint.
  ///
  /// In ko, this message translates to:
  /// **'댓글을 남겨보세요'**
  String get postCommentHint;

  /// No description provided for @postCommentLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'댓글을 불러오지 못했어요'**
  String get postCommentLoadFailed;

  /// No description provided for @postCommentEmpty.
  ///
  /// In ko, this message translates to:
  /// **'첫 댓글을 남겨보세요'**
  String get postCommentEmpty;

  /// No description provided for @postReportSuccess.
  ///
  /// In ko, this message translates to:
  /// **'신고되었습니다'**
  String get postReportSuccess;

  /// No description provided for @postReportFailed.
  ///
  /// In ko, this message translates to:
  /// **'신고에 실패했어요 (이미 신고했을 수 있어요)'**
  String get postReportFailed;

  /// No description provided for @postBlockTitle.
  ///
  /// In ko, this message translates to:
  /// **'{name} 님을 차단할까요?'**
  String postBlockTitle(String name);

  /// No description provided for @postBlockBody.
  ///
  /// In ko, this message translates to:
  /// **'이 사용자의 게시물과 댓글이 보이지 않아요.'**
  String get postBlockBody;

  /// No description provided for @postBlockSuccess.
  ///
  /// In ko, this message translates to:
  /// **'차단했어요'**
  String get postBlockSuccess;

  /// No description provided for @postBlockFailed.
  ///
  /// In ko, this message translates to:
  /// **'차단에 실패했어요'**
  String get postBlockFailed;

  /// No description provided for @postMenuReport.
  ///
  /// In ko, this message translates to:
  /// **'신고하기'**
  String get postMenuReport;

  /// No description provided for @postMenuBlock.
  ///
  /// In ko, this message translates to:
  /// **'차단하기'**
  String get postMenuBlock;

  /// No description provided for @postAnonymous.
  ///
  /// In ko, this message translates to:
  /// **'익명'**
  String get postAnonymous;

  /// No description provided for @createPostTitle.
  ///
  /// In ko, this message translates to:
  /// **'사진 올리기'**
  String get createPostTitle;

  /// No description provided for @createPostSubmit.
  ///
  /// In ko, this message translates to:
  /// **'올리기'**
  String get createPostSubmit;

  /// No description provided for @createPostMaxImages.
  ///
  /// In ko, this message translates to:
  /// **'사진은 최대 10장까지 올릴 수 있어요'**
  String get createPostMaxImages;

  /// No description provided for @createPostCountLabel.
  ///
  /// In ko, this message translates to:
  /// **'{count}/{max} · 얼굴은 자동으로 가려집니다. 사진을 탭해 수정할 수 있어요.'**
  String createPostCountLabel(int count, int max);

  /// No description provided for @createPostModeLabel.
  ///
  /// In ko, this message translates to:
  /// **'촬영 모드'**
  String get createPostModeLabel;

  /// No description provided for @createPostCaptionHint.
  ///
  /// In ko, this message translates to:
  /// **'한 줄 팁을 남겨보세요'**
  String get createPostCaptionHint;

  /// No description provided for @createPostUploadFailed.
  ///
  /// In ko, this message translates to:
  /// **'업로드에 실패했어요'**
  String get createPostUploadFailed;

  /// No description provided for @accountTitle.
  ///
  /// In ko, this message translates to:
  /// **'내 프로필'**
  String get accountTitle;

  /// No description provided for @accountLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'불러오지 못했어요'**
  String get accountLoadFailed;

  /// No description provided for @accountNoProfile.
  ///
  /// In ko, this message translates to:
  /// **'프로필이 없어요'**
  String get accountNoProfile;

  /// No description provided for @accountEditNickname.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 편집'**
  String get accountEditNickname;

  /// No description provided for @accountChangePhoto.
  ///
  /// In ko, this message translates to:
  /// **'프로필 사진 변경'**
  String get accountChangePhoto;

  /// No description provided for @accountLoginMethod.
  ///
  /// In ko, this message translates to:
  /// **'로그인 방식'**
  String get accountLoginMethod;

  /// No description provided for @accountBlockedUsers.
  ///
  /// In ko, this message translates to:
  /// **'차단한 사용자'**
  String get accountBlockedUsers;

  /// No description provided for @accountTheme.
  ///
  /// In ko, this message translates to:
  /// **'화면 테마'**
  String get accountTheme;

  /// No description provided for @accountLogout.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get accountLogout;

  /// No description provided for @accountWithdraw.
  ///
  /// In ko, this message translates to:
  /// **'회원 탈퇴'**
  String get accountWithdraw;

  /// No description provided for @accountPhotoChangeFailed.
  ///
  /// In ko, this message translates to:
  /// **'사진 변경 실패: {error}'**
  String accountPhotoChangeFailed(String error);

  /// No description provided for @accountNicknameInvalid.
  ///
  /// In ko, this message translates to:
  /// **'닉네임은 1~20자로 입력해 주세요'**
  String get accountNicknameInvalid;

  /// No description provided for @accountNicknameChangeFailed.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 변경에 실패했어요'**
  String get accountNicknameChangeFailed;

  /// No description provided for @accountLogoutTitle.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃 할까요?'**
  String get accountLogoutTitle;

  /// No description provided for @accountLogoutBody.
  ///
  /// In ko, this message translates to:
  /// **'다시 로그인하면 이어서 사용할 수 있어요.'**
  String get accountLogoutBody;

  /// No description provided for @accountLogoutConfirm.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get accountLogoutConfirm;

  /// No description provided for @accountWithdrawTitle.
  ///
  /// In ko, this message translates to:
  /// **'정말 탈퇴하시겠어요?'**
  String get accountWithdrawTitle;

  /// No description provided for @accountWithdrawBody.
  ///
  /// In ko, this message translates to:
  /// **'다시 로그인하면 재가입할 수 있어요.'**
  String get accountWithdrawBody;

  /// No description provided for @accountWithdrawConfirm.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴'**
  String get accountWithdrawConfirm;

  /// No description provided for @accountWithdrawFailed.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴에 실패했어요'**
  String get accountWithdrawFailed;

  /// No description provided for @accountThemeSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정'**
  String get accountThemeSystem;

  /// No description provided for @accountThemeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get accountThemeLight;

  /// No description provided for @accountThemeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get accountThemeDark;

  /// No description provided for @accountThemePickerTitle.
  ///
  /// In ko, this message translates to:
  /// **'화면 테마'**
  String get accountThemePickerTitle;

  /// No description provided for @accountEditNicknameTitle.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 편집'**
  String get accountEditNicknameTitle;

  /// No description provided for @accountSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get accountSave;

  /// No description provided for @accountLoginTypeSuffix.
  ///
  /// In ko, this message translates to:
  /// **' 로그인'**
  String get accountLoginTypeSuffix;

  /// No description provided for @maskEditorTitle.
  ///
  /// In ko, this message translates to:
  /// **'개인정보 가림'**
  String get maskEditorTitle;

  /// No description provided for @maskEditorDone.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get maskEditorDone;

  /// No description provided for @maskEditorApplyFailed.
  ///
  /// In ko, this message translates to:
  /// **'가림 처리에 실패했어요'**
  String get maskEditorApplyFailed;

  /// No description provided for @maskEditorHint.
  ///
  /// In ko, this message translates to:
  /// **'드래그로 가릴 영역 추가 · 탭으로 선택'**
  String get maskEditorHint;

  /// No description provided for @maskEditorHide.
  ///
  /// In ko, this message translates to:
  /// **'가림 켜기'**
  String get maskEditorHide;

  /// No description provided for @maskEditorShow.
  ///
  /// In ko, this message translates to:
  /// **'가림 끄기'**
  String get maskEditorShow;

  /// No description provided for @maskEditorDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get maskEditorDelete;

  /// No description provided for @reportTitle.
  ///
  /// In ko, this message translates to:
  /// **'신고 사유를 선택하세요'**
  String get reportTitle;

  /// No description provided for @reportReasonSpam.
  ///
  /// In ko, this message translates to:
  /// **'스팸/광고'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHate.
  ///
  /// In ko, this message translates to:
  /// **'욕설·혐오 발언'**
  String get reportReasonHate;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In ko, this message translates to:
  /// **'부적절한 사진'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonPrivacy.
  ///
  /// In ko, this message translates to:
  /// **'개인정보 노출'**
  String get reportReasonPrivacy;

  /// No description provided for @reportReasonEtc.
  ///
  /// In ko, this message translates to:
  /// **'기타'**
  String get reportReasonEtc;

  /// No description provided for @remoteControlTitle.
  ///
  /// In ko, this message translates to:
  /// **'리모컨'**
  String get remoteControlTitle;

  /// No description provided for @remoteQrRescan.
  ///
  /// In ko, this message translates to:
  /// **'QR 다시 스캔'**
  String get remoteQrRescan;

  /// No description provided for @remoteScanPrompt.
  ///
  /// In ko, this message translates to:
  /// **'촬영 폰에 표시된 QR 코드를 스캔하세요'**
  String get remoteScanPrompt;

  /// No description provided for @remoteScanHint.
  ///
  /// In ko, this message translates to:
  /// **'촬영 폰: 카메라 화면 상단 리모컨 아이콘 → 이 폰으로 촬영하기'**
  String get remoteScanHint;

  /// No description provided for @remoteHintReady.
  ///
  /// In ko, this message translates to:
  /// **'좋아요'**
  String get remoteHintReady;

  /// No description provided for @remoteCaptureSuccess.
  ///
  /// In ko, this message translates to:
  /// **'찰칵! 촬영 폰에 저장했어요'**
  String get remoteCaptureSuccess;

  /// No description provided for @remoteCommandFailed.
  ///
  /// In ko, this message translates to:
  /// **'명령이 실패했어요'**
  String get remoteCommandFailed;

  /// No description provided for @remoteTimerOff.
  ///
  /// In ko, this message translates to:
  /// **'타이머\n끔'**
  String get remoteTimerOff;

  /// No description provided for @remoteTimerOn.
  ///
  /// In ko, this message translates to:
  /// **'타이머\n{sec}초'**
  String remoteTimerOn(int sec);

  /// No description provided for @remoteQrExpired.
  ///
  /// In ko, this message translates to:
  /// **'QR이 만료됐어요. 촬영 폰에서 QR을 다시 띄워 스캔해 주세요.'**
  String get remoteQrExpired;

  /// No description provided for @remoteBusy.
  ///
  /// In ko, this message translates to:
  /// **'이미 다른 리모컨이 연결돼 있어요.'**
  String get remoteBusy;

  /// No description provided for @remoteVersionMismatch.
  ///
  /// In ko, this message translates to:
  /// **'연결이 거부됐어요. 두 폰의 앱을 최신으로 업데이트해 주세요.'**
  String get remoteVersionMismatch;

  /// No description provided for @remoteConnectFailed.
  ///
  /// In ko, this message translates to:
  /// **'연결하지 못했어요. 두 폰이 같은 Wi-Fi(또는 핫스팟)에 있는지 확인해 주세요.'**
  String get remoteConnectFailed;

  /// No description provided for @remoteDisconnected.
  ///
  /// In ko, this message translates to:
  /// **'연결이 끊겼어요.'**
  String get remoteDisconnected;

  /// No description provided for @remotePairingTitle.
  ///
  /// In ko, this message translates to:
  /// **'리모컨 촬영'**
  String get remotePairingTitle;

  /// No description provided for @remotePairingHostTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 폰으로 촬영하기'**
  String get remotePairingHostTitle;

  /// No description provided for @remotePairingHostSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'삼각대에 두고, 다른 폰에서 QR을 스캔해요'**
  String get remotePairingHostSubtitle;

  /// No description provided for @remotePairingRemoteTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 폰을 리모컨으로'**
  String get remotePairingRemoteTitle;

  /// No description provided for @remotePairingRemoteSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'촬영 폰에 뜬 QR을 스캔해서 연결해요'**
  String get remotePairingRemoteSubtitle;

  /// No description provided for @remotePairingWifiHint.
  ///
  /// In ko, this message translates to:
  /// **'두 폰이 같은 Wi-Fi(또는 한 폰의 핫스팟)에 있어야 해요.'**
  String get remotePairingWifiHint;

  /// No description provided for @remoteHostQrTitle.
  ///
  /// In ko, this message translates to:
  /// **'리모컨 연결 대기'**
  String get remoteHostQrTitle;

  /// No description provided for @remoteHostQrInstruction.
  ///
  /// In ko, this message translates to:
  /// **'리모컨 폰의 똥손카메라에서\n[리모컨 촬영 → 이 폰을 리모컨으로]를 눌러\n이 QR을 스캔하세요.'**
  String get remoteHostQrInstruction;

  /// No description provided for @poseOff.
  ///
  /// In ko, this message translates to:
  /// **'끄기'**
  String get poseOff;

  /// No description provided for @poseAiRecommend.
  ///
  /// In ko, this message translates to:
  /// **'AI 추천'**
  String get poseAiRecommend;

  /// No description provided for @poseCategorySelfie.
  ///
  /// In ko, this message translates to:
  /// **'셀카'**
  String get poseCategorySelfie;

  /// No description provided for @poseCategoryFullBody.
  ///
  /// In ko, this message translates to:
  /// **'전신'**
  String get poseCategoryFullBody;

  /// No description provided for @poseCategoryCouple.
  ///
  /// In ko, this message translates to:
  /// **'커플'**
  String get poseCategoryCouple;

  /// No description provided for @poseCategoryFriends.
  ///
  /// In ko, this message translates to:
  /// **'우정'**
  String get poseCategoryFriends;

  /// No description provided for @posePreparing.
  ///
  /// In ko, this message translates to:
  /// **'포즈 준비 중'**
  String get posePreparing;
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
