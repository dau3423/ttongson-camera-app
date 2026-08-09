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

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonAgree => 'Agree';

  @override
  String get commonRetry => 'Retry';

  @override
  String get cameraSwitchFailed => 'Failed to switch camera';

  @override
  String get galleryOpenFailed => 'Cannot open photo library';

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get compositionConsentTitle => 'Composition Suggestion Notice';

  @override
  String get compositionConsentBody =>
      'When requesting a suggestion, the current frame will be sent to the analysis server. Images are not stored.';

  @override
  String get suggestFailed => 'Could not get a suggestion. Please try again.';

  @override
  String get posesLoadFailed => 'Failed to load poses';

  @override
  String get aiConsentTitle => 'AI Suggestion Notice';

  @override
  String get aiConsentBody =>
      'When requesting a suggestion, the current frame will be sent to the analysis server. Images are not stored.';

  @override
  String cameraRestartFailedDetail(String error) {
    return 'Failed to restart camera: $error';
  }

  @override
  String get wifiNotConnected =>
      'Not connected to Wi-Fi. Please connect to the same Wi-Fi or hotspot.';

  @override
  String get remotePrepFailed =>
      'Failed to prepare remote connection. Please try again later.';

  @override
  String get remoteConnected => 'Remote connected';

  @override
  String get remoteWaiting => 'Waiting for remote';

  @override
  String get captureAiEnhanceConsentTitle => 'AI Enhancement Notice';

  @override
  String get captureAiEnhanceConsentBody =>
      'When enhancing, one photo will be sent to the analysis server. Images are not stored.';

  @override
  String get captureEnhanceFailed => 'This photo cannot be enhanced';

  @override
  String get captureAiEnhanceFailed => 'AI enhancement failed. Keeping preset.';

  @override
  String get captureSaved => 'Saved';

  @override
  String get captureSavePermissionFailed =>
      'Save failed — please check permissions';

  @override
  String get captureMoodTitle => 'Today\'s Mood';

  @override
  String get captureAiEnhanceTooltip =>
      'Make it prettier with AI (tuned for this photo)';

  @override
  String get captureSaveButton => 'Save';

  @override
  String get captureNameHint => 'AI will name this for you';

  @override
  String get captureOriginalLabel => 'Original';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authLoginSubtitle =>
      'Even beginners can shoot like pros · Log in to continue';

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
  String get authInvalidEmail => 'Invalid email format.';

  @override
  String get authLoginFailed => 'Sign in failed.';

  @override
  String get authLoginFailedRetry => 'Sign in failed. Please try again.';

  @override
  String get authWrongCredential => 'Incorrect email or password.';

  @override
  String get authAccountDisabled => 'This account has been disabled.';

  @override
  String get authWithdrawnTitle => 'Withdrawn account';

  @override
  String get authWithdrawnBody =>
      'This account has been withdrawn. Would you like to re-register?';

  @override
  String get authRejoin => 'Re-register';

  @override
  String get authLoginSuccess => 'Welcome!';

  @override
  String get authLoginSuccessSubtitle => 'Ready to start shooting?';

  @override
  String get authLoginSuccessCta => 'Go shoot';

  @override
  String get authSignupTitle => 'Sign up';

  @override
  String get authSignupSubtitle => 'Takes only 30 seconds';

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
  String get authSignupButton => 'Sign up and start';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authSigninLink => 'Sign in';

  @override
  String get authAllFieldsRequired => 'Please fill in all fields.';

  @override
  String get authNicknameInvalid => 'Nickname must be 1–20 characters.';

  @override
  String get authWeakPassword => 'Password must be at least 8 characters.';

  @override
  String get authAgreeRequired => 'Please agree to the terms.';

  @override
  String get authEmailInUse => 'Email already in use. Please sign in.';

  @override
  String get authWeakPasswordServer =>
      'Password too weak. Use at least 8 characters.';

  @override
  String get authSignupFailed => 'Sign up failed. Please try again.';

  @override
  String get authSignupSuccess => 'Registration complete!';

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
  String get feedLoadFailed => 'Failed to load';

  @override
  String get feedEmpty => 'No posts yet. Be the first to share a photo!';

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
  String get feedDeleteBody => 'This cannot be undone.';

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
  String get postDeleteBody => 'This cannot be undone.';

  @override
  String get postDeleteSuccess => 'Deleted';

  @override
  String get postDeleteFailed => 'Delete failed';

  @override
  String get postCommentDeleteTitle => 'Delete this comment?';

  @override
  String get postCommentDeleteBody => 'Deleted comments cannot be recovered.';

  @override
  String get postCommentSendFailed => 'Failed to send comment';

  @override
  String get postCommentHint => 'Leave a comment';

  @override
  String get postCommentLoadFailed => 'Failed to load comments';

  @override
  String get postCommentEmpty => 'Be the first to comment';

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
  String get createPostTitle => 'Upload photo';

  @override
  String get createPostSubmit => 'Post';

  @override
  String get createPostMaxImages => 'You can upload up to 10 photos';

  @override
  String createPostCountLabel(int count, int max) {
    return '$count/$max · Faces are automatically masked. Tap a photo to edit.';
  }

  @override
  String get createPostModeLabel => 'Shooting mode';

  @override
  String get createPostCaptionHint => 'Leave a one-line tip';

  @override
  String get createPostUploadFailed => 'Upload failed';

  @override
  String get accountTitle => 'My Profile';

  @override
  String get accountLoadFailed => 'Failed to load';

  @override
  String get accountNoProfile => 'No profile found';

  @override
  String get accountEditNickname => 'Edit nickname';

  @override
  String get accountChangePhoto => 'Change profile photo';

  @override
  String get accountLoginMethod => 'Login method';

  @override
  String get accountBlockedUsers => 'Blocked users';

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
  String get accountNicknameChangeFailed => 'Failed to change nickname';

  @override
  String get accountLogoutTitle => 'Log out?';

  @override
  String get accountLogoutBody => 'You can log back in to continue.';

  @override
  String get accountLogoutConfirm => 'Log out';

  @override
  String get accountWithdrawTitle =>
      'Are you sure you want to delete your account?';

  @override
  String get accountWithdrawBody => 'You can re-register by logging in again.';

  @override
  String get accountWithdrawConfirm => 'Delete';

  @override
  String get accountWithdrawFailed => 'Failed to delete account';

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
  String get maskEditorApplyFailed => 'Failed to apply mask';

  @override
  String get maskEditorHint => 'Drag to add masked area · Tap to select';

  @override
  String get maskEditorHide => 'Enable mask';

  @override
  String get maskEditorShow => 'Disable mask';

  @override
  String get maskEditorDelete => 'Delete';

  @override
  String get reportTitle => 'Select a reason to report';

  @override
  String get reportReasonSpam => 'Spam/Advertisement';

  @override
  String get reportReasonHate => 'Abusive/Hate speech';

  @override
  String get reportReasonInappropriate => 'Inappropriate photo';

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
  String get remoteHintReady => 'Good';

  @override
  String get remoteCaptureSuccess => 'Click! Saved to the camera phone';

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
      'QR expired. Please show the QR again on the camera phone and scan.';

  @override
  String get remoteBusy => 'Another remote is already connected.';

  @override
  String get remoteVersionMismatch =>
      'Connection refused. Please update the app on both phones.';

  @override
  String get remoteConnectFailed =>
      'Could not connect. Please make sure both phones are on the same Wi-Fi (or hotspot).';

  @override
  String get remoteDisconnected => 'Disconnected.';

  @override
  String get remotePairingTitle => 'Remote shooting';

  @override
  String get remotePairingHostTitle => 'Shoot with this phone';

  @override
  String get remotePairingHostSubtitle =>
      'Place on a tripod, then scan the QR from another phone';

  @override
  String get remotePairingRemoteTitle => 'Use this phone as remote';

  @override
  String get remotePairingRemoteSubtitle =>
      'Scan the QR on the camera phone to connect';

  @override
  String get remotePairingWifiHint =>
      'Both phones must be on the same Wi-Fi (or one phone\'s hotspot).';

  @override
  String get remoteHostQrTitle => 'Waiting for remote';

  @override
  String get remoteHostQrInstruction =>
      'On the remote phone\'s Ddongson Camera,\ntap [Remote shooting → Use this phone as remote]\nand scan this QR.';

  @override
  String get poseOff => 'Off';

  @override
  String get poseAiRecommend => 'AI Recommend';

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
