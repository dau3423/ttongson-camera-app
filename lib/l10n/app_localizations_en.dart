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
  String get guideHeadroomRaise => 'Raise the camera a bit';

  @override
  String get guideHeadroomLower => 'Lower the camera a bit';

  @override
  String get guideAngleEyeLevelDown => 'Tilt the camera down to eye level';

  @override
  String get guideAngleEyeLevelUp => 'Tilt the camera up to eye level';

  @override
  String get guideAngleFrontalDown => 'Tilt the camera down to level';

  @override
  String get guideAngleFrontalUp => 'Tilt the camera up to level';

  @override
  String get guideZoomCloser => 'Move closer or zoom in';

  @override
  String get guideZoomFarther => 'Step back or zoom out';

  @override
  String get guideMoveRight => 'Right';

  @override
  String get guideMoveLeft => 'Left';

  @override
  String get guideMoveUp => 'Up';

  @override
  String get guideMoveDown => 'Down';

  @override
  String get guideMoveSeparator => ' · ';

  @override
  String get guideMovePrompt => 'Move this way';

  @override
  String get guideReady => 'Shoot!';

  @override
  String get cropTop => 'Top';

  @override
  String get cropBottom => 'Bottom';

  @override
  String get cropLeft => 'Left';

  @override
  String get cropRight => 'Right';

  @override
  String get cropSeparator => '/';

  @override
  String cropCut(String sides) {
    return '$sides is cut off';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonAgree => 'Agree';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDelete => 'Delete';

  @override
  String get cameraSwitchFailed => 'Couldn\'t switch camera';

  @override
  String get galleryOpenFailed => 'Can\'t open photo library';

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get compositionConsentTitle => 'Composition Suggestion';

  @override
  String get compositionConsentBody =>
      'One frame will be sent to our analysis server to suggest a composition. Images are not stored.';

  @override
  String get suggestFailed => 'Couldn\'t get a suggestion. Please try again.';

  @override
  String get posesLoadFailed => 'Couldn\'t load poses';

  @override
  String get aiConsentTitle => 'AI Suggestion';

  @override
  String get aiConsentBody =>
      'One frame will be sent to our analysis server to generate a suggestion. Images are not stored.';

  @override
  String cameraRestartFailedDetail(String error) {
    return 'Couldn\'t restart camera: $error';
  }

  @override
  String get wifiNotConnected =>
      'Not connected to Wi-Fi. Connect to the same Wi-Fi or hotspot.';

  @override
  String get remotePrepFailed =>
      'Couldn\'t prepare remote connection. Please try again later.';

  @override
  String get remoteConnected => 'Remote connected';

  @override
  String get remoteWaiting => 'Waiting for remote';

  @override
  String get captureAiEnhanceConsentTitle => 'AI Enhancement';

  @override
  String get captureAiEnhanceConsentBody =>
      'One photo will be sent to our analysis server for AI enhancement. Images are not stored.';

  @override
  String get captureEnhanceFailed => 'This photo can\'t be enhanced';

  @override
  String get captureAiEnhanceFailed =>
      'AI enhancement failed. Keeping the preset.';

  @override
  String get captureSaved => 'Saved!';

  @override
  String get captureSavePermissionFailed =>
      'Save failed — check your permissions';

  @override
  String get captureMoodTitle => 'Today\'s Mood';

  @override
  String get captureAiEnhanceTooltip => 'AI polish, tuned for this photo';

  @override
  String get captureSaveButton => 'Save';

  @override
  String get captureNameHint => 'AI will name this';

  @override
  String get captureOriginalLabel => 'Original';

  @override
  String get authWelcomeBack => 'Welcome back!';

  @override
  String get authLoginSubtitle =>
      'Even beginners shoot like pros · Sign in to keep going';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authLoginButton => 'Sign in';

  @override
  String get authOrDivider => 'or';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authSignupLink => 'Sign up';

  @override
  String get authEmailEmpty => 'Please enter your email and password.';

  @override
  String get authInvalidEmail => 'That doesn\'t look like a valid email.';

  @override
  String get authLoginFailed => 'Sign in failed.';

  @override
  String get authLoginFailedRetry => 'Sign in failed. Please try again.';

  @override
  String get authWrongCredential => 'Incorrect email or password.';

  @override
  String get authAccountDisabled => 'This account has been disabled.';

  @override
  String get authWithdrawnTitle => 'Account deleted';

  @override
  String get authWithdrawnBody =>
      'This account has been deleted. Would you like to sign up again?';

  @override
  String get authRejoin => 'Sign up again';

  @override
  String get authLoginSuccess => 'Welcome!';

  @override
  String get authLoginSuccessSubtitle => 'Ready to start shooting?';

  @override
  String get authLoginSuccessCta => 'Let\'s shoot';

  @override
  String get authSignupTitle => 'Sign up';

  @override
  String get authSignupSubtitle => 'Takes about 30 seconds';

  @override
  String get authNicknameLabel => 'Nickname';

  @override
  String get authNicknameHint => 'CameraNewbie';

  @override
  String get authPasswordHint => '8+ characters';

  @override
  String get authAgreeTerms =>
      'I agree to the Terms of Service and Privacy Policy';

  @override
  String get authSignupButton => 'Sign up and get started';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authSigninLink => 'Sign in';

  @override
  String get authKakao => 'Kakao';

  @override
  String get authAllFieldsRequired => 'Please fill in all fields.';

  @override
  String get authNicknameInvalid => 'Nickname must be 1–20 characters.';

  @override
  String get authWeakPassword => 'Password must be at least 8 characters.';

  @override
  String get authAgreeRequired => 'Please agree to the terms.';

  @override
  String get authEmailInUse => 'Email already in use. Please sign in instead.';

  @override
  String get authWeakPasswordServer =>
      'Password too weak. Please use at least 8 characters.';

  @override
  String get authSignupFailed => 'Sign up failed. Please try again.';

  @override
  String get authSignupSuccess => 'You\'re in!';

  @override
  String get feedTitle => 'Photo Tips';

  @override
  String get feedTabPopular => 'Popular';

  @override
  String get feedTabRecent => 'Recent';

  @override
  String get feedFilterAll => 'All';

  @override
  String get feedMyAccountTooltip => 'My account';

  @override
  String get feedLoadFailed => 'Couldn\'t load';

  @override
  String get feedEmpty => 'No posts yet. Share the first photo!';

  @override
  String get feedReportSuccess => 'Reported';

  @override
  String get feedReportFailed =>
      'Report failed (you may have already reported this)';

  @override
  String get feedDeleteSuccess => 'Deleted';

  @override
  String get feedDeleteFailed => 'Delete failed';

  @override
  String get feedDeleteTitle => 'Delete this post?';

  @override
  String get feedDeleteBody => 'This can\'t be undone.';

  @override
  String get feedDeleteConfirm => 'Delete';

  @override
  String feedBlockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get feedBlockBody =>
      'You won\'t see posts or comments from this user.';

  @override
  String get feedBlockConfirm => 'Block';

  @override
  String get feedBlockSuccess => 'Blocked';

  @override
  String get feedBlockFailed => 'Block failed';

  @override
  String get feedMenuReport => 'Report';

  @override
  String get feedMenuBlock => 'Block';

  @override
  String get feedMenuDelete => 'Delete';

  @override
  String get postDeleteTooltip => 'Delete';

  @override
  String get postDeleteTitle => 'Delete this post?';

  @override
  String get postDeleteBody => 'This can\'t be undone.';

  @override
  String get postDeleteSuccess => 'Deleted';

  @override
  String get postDeleteFailed => 'Delete failed';

  @override
  String get postCommentDeleteTitle => 'Delete this comment?';

  @override
  String get postCommentDeleteBody => 'Deleted comments can\'t be recovered.';

  @override
  String get postCommentSendFailed => 'Couldn\'t send comment';

  @override
  String get postCommentHint => 'Leave a comment';

  @override
  String get postCommentLoadFailed => 'Couldn\'t load comments';

  @override
  String get postCommentEmpty => 'Be the first to comment!';

  @override
  String get postReportSuccess => 'Reported';

  @override
  String get postReportFailed =>
      'Report failed (you may have already reported this)';

  @override
  String postBlockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get postBlockBody =>
      'You won\'t see posts or comments from this user.';

  @override
  String get postBlockSuccess => 'Blocked';

  @override
  String get postBlockFailed => 'Block failed';

  @override
  String get postMenuReport => 'Report';

  @override
  String get postMenuBlock => 'Block';

  @override
  String get postAnonymous => 'Anonymous';

  @override
  String get createPostTitle => 'Share a photo';

  @override
  String get createPostSubmit => 'Post';

  @override
  String get createPostMaxImages => 'You can add up to 10 photos';

  @override
  String createPostCountLabel(int count, int max) {
    return '$count/$max · Faces are auto-masked. Tap a photo to edit.';
  }

  @override
  String get createPostModeLabel => 'Shooting mode';

  @override
  String get createPostCaptionHint => 'Share a quick tip';

  @override
  String get createPostUploadFailed => 'Upload failed';

  @override
  String get accountTitle => 'My Profile';

  @override
  String get accountLoadFailed => 'Couldn\'t load';

  @override
  String get accountNoProfile => 'No profile found';

  @override
  String get accountEditNickname => 'Edit nickname';

  @override
  String get accountChangePhoto => 'Change profile photo';

  @override
  String get accountLoginMethod => 'Sign-in method';

  @override
  String get accountBlockedUsers => 'Blocked users';

  @override
  String get blockedUsersEmpty => 'No blocked users';

  @override
  String get blockedUsersUnblock => 'Unblock';

  @override
  String get accountTheme => 'Display theme';

  @override
  String get accountLogout => 'Log out';

  @override
  String get accountWithdraw => 'Delete account';

  @override
  String accountPhotoChangeFailed(String error) {
    return 'Photo change failed: $error';
  }

  @override
  String get accountNicknameInvalid => 'Nickname must be 1–20 characters';

  @override
  String get accountNicknameChangeFailed => 'Couldn\'t change nickname';

  @override
  String get accountLogoutTitle => 'Log out?';

  @override
  String get accountLogoutBody => 'You can sign back in anytime to continue.';

  @override
  String get accountLogoutConfirm => 'Log out';

  @override
  String get accountWithdrawTitle => 'Delete your account?';

  @override
  String get accountWithdrawBody =>
      'You can sign up again later if you change your mind.';

  @override
  String get accountWithdrawConfirm => 'Delete';

  @override
  String get accountWithdrawFailed => 'Couldn\'t delete account';

  @override
  String get accountThemeSystem => 'System';

  @override
  String get accountThemeLight => 'Light';

  @override
  String get accountThemeDark => 'Dark';

  @override
  String get accountThemePickerTitle => 'Display theme';

  @override
  String get accountEditNicknameTitle => 'Edit nickname';

  @override
  String get accountSave => 'Save';

  @override
  String get accountLoginTypeSuffix => ' login';

  @override
  String get maskEditorTitle => 'Privacy mask';

  @override
  String get maskEditorDone => 'Done';

  @override
  String get maskEditorApplyFailed => 'Couldn\'t apply mask';

  @override
  String get maskEditorHint => 'Drag to add a masked area · Tap to select';

  @override
  String get maskEditorHide => 'Enable mask';

  @override
  String get maskEditorShow => 'Disable mask';

  @override
  String get maskEditorDelete => 'Delete';

  @override
  String get reportTitle => 'Why are you reporting this?';

  @override
  String get reportReasonSpam => 'Spam or ads';

  @override
  String get reportReasonHate => 'Hate speech or abuse';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonPrivacy => 'Privacy violation';

  @override
  String get reportReasonEtc => 'Other';

  @override
  String get remoteControlTitle => 'Remote';

  @override
  String get remoteQrRescan => 'Scan QR again';

  @override
  String get remoteScanPrompt => 'Scan the QR code shown on the camera phone';

  @override
  String get remoteScanHint =>
      'Camera phone: tap the remote icon at the top of the camera screen → Shoot with this phone';

  @override
  String get remoteHintReady => 'Looking good!';

  @override
  String get remoteCaptureSuccess => 'Snap! Saved to the camera phone';

  @override
  String get remoteCommandFailed => 'Command failed';

  @override
  String get remoteTimerOff => 'Timer\nOff';

  @override
  String remoteTimerOn(int sec) {
    return 'Timer\n${sec}s';
  }

  @override
  String get remoteQrExpired =>
      'QR expired. Please show the QR again on the camera phone and scan it.';

  @override
  String get remoteBusy => 'Another remote is already connected.';

  @override
  String get remoteVersionMismatch =>
      'Connection refused. Please update the app on both phones to the latest version.';

  @override
  String get remoteConnectFailed =>
      'Couldn\'t connect. Make sure both phones are on the same Wi-Fi (or hotspot).';

  @override
  String get remoteDisconnected => 'Disconnected.';

  @override
  String get remotePairingTitle => 'Remote shooting';

  @override
  String get remotePairingHostTitle => 'Shoot with this phone';

  @override
  String get remotePairingHostSubtitle =>
      'Set it on a tripod, then scan the QR from another phone';

  @override
  String get remotePairingRemoteTitle => 'Use this phone as remote';

  @override
  String get remotePairingRemoteSubtitle =>
      'Scan the QR on the camera phone to connect';

  @override
  String get remotePairingWifiHint =>
      'Both phones need to be on the same Wi-Fi (or one phone\'s hotspot).';

  @override
  String get remoteHostQrTitle => 'Waiting for remote';

  @override
  String get remoteHostQrInstruction =>
      'On the remote phone\'s Ddongson Camera,\ntap [Remote shooting → Use this phone as remote]\nand scan this QR.';

  @override
  String get poseOff => 'Off';

  @override
  String get poseAiRecommend => 'AI Pick';

  @override
  String get poseCategorySelfie => 'Selfie';

  @override
  String get poseCategoryFullBody => 'Full body';

  @override
  String get poseCategoryCouple => 'Couple';

  @override
  String get poseCategoryFriends => 'Friends';

  @override
  String get posePreparing => 'Poses coming soon';
}
