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

  @override
  String get commonCancel => '취소';

  @override
  String get commonAgree => '동의';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get cameraSwitchFailed => '카메라 전환에 실패했어요';

  @override
  String get galleryOpenFailed => '사진첩을 열 수 없어요';

  @override
  String saveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get compositionConsentTitle => '구도 추천 안내';

  @override
  String get compositionConsentBody =>
      '구도 추천 시 현재 화면 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.';

  @override
  String get suggestFailed => '추천을 못 받았어요. 다시 시도해 주세요.';

  @override
  String get posesLoadFailed => '포즈를 불러오지 못했어요';

  @override
  String get aiConsentTitle => 'AI 추천 안내';

  @override
  String get aiConsentBody => '추천 시 현재 화면 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.';

  @override
  String cameraRestartFailedDetail(String error) {
    return '카메라를 다시 시작하지 못했어요: $error';
  }

  @override
  String get wifiNotConnected => 'Wi-Fi에 연결돼 있지 않아요. 같은 Wi-Fi 또는 핫스팟에 연결해 주세요.';

  @override
  String get remotePrepFailed => '리모컨 연결 준비에 실패했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get remoteConnected => '리모컨 연결됨';

  @override
  String get remoteWaiting => '리모컨 대기 중';

  @override
  String get captureAiEnhanceConsentTitle => 'AI 보정 안내';

  @override
  String get captureAiEnhanceConsentBody =>
      'AI 보정 시 사진 1장을 분석 서버로 전송합니다. 이미지는 저장하지 않습니다.';

  @override
  String get captureEnhanceFailed => '이 사진은 보정할 수 없어요';

  @override
  String get captureAiEnhanceFailed => 'AI 개선을 못 받았어요. 프리셋을 유지합니다.';

  @override
  String get captureSaved => '저장했어요';

  @override
  String get captureSavePermissionFailed => '저장 실패 — 권한을 확인해 주세요';

  @override
  String get captureMoodTitle => '오늘의 무드';

  @override
  String get captureAiEnhanceTooltip => 'AI로 더 예쁘게 (이 사진에 맞게)';

  @override
  String get captureSaveButton => '저장';

  @override
  String get captureNameHint => 'AI가 이름을 지어줘요';

  @override
  String get captureOriginalLabel => '원본';

  @override
  String get authWelcomeBack => '다시 오셨네요';

  @override
  String get authLoginSubtitle => '똥손도 프로처럼 · 로그인하고 이어서 찍기';

  @override
  String get authEmailLabel => '이메일';

  @override
  String get authPasswordLabel => '비밀번호';

  @override
  String get authLoginButton => '로그인';

  @override
  String get authOrDivider => '또는';

  @override
  String get authNoAccount => '아직 계정이 없으신가요? ';

  @override
  String get authSignupLink => '회원가입';

  @override
  String get authEmailEmpty => '이메일과 비밀번호를 입력해주세요.';

  @override
  String get authInvalidEmail => '올바른 이메일 형식이 아니에요.';

  @override
  String get authLoginFailed => '로그인에 실패했어요.';

  @override
  String get authLoginFailedRetry => '로그인에 실패했어요. 다시 시도해 주세요.';

  @override
  String get authWrongCredential => '이메일 또는 비밀번호가 올바르지 않아요.';

  @override
  String get authAccountDisabled => '사용할 수 없는 계정이에요.';

  @override
  String get authWithdrawnTitle => '탈퇴한 계정이에요';

  @override
  String get authWithdrawnBody => '이 계정은 탈퇴 처리됐어요. 다시 가입할까요?';

  @override
  String get authRejoin => '재가입';

  @override
  String get authLoginSuccess => '환영합니다!';

  @override
  String get authLoginSuccessSubtitle => '이제 촬영을 시작해볼까요?';

  @override
  String get authLoginSuccessCta => '촬영하러 가기';

  @override
  String get authSignupTitle => '가입하기';

  @override
  String get authSignupSubtitle => '30초면 충분해요';

  @override
  String get authNicknameLabel => '닉네임';

  @override
  String get authNicknameHint => '똥손탈출러';

  @override
  String get authPasswordHint => '8자 이상';

  @override
  String get authAgreeTerms => '이용약관 및 개인정보 처리방침에 동의합니다';

  @override
  String get authSignupButton => '가입하고 시작하기';

  @override
  String get authHaveAccount => '이미 계정이 있으신가요? ';

  @override
  String get authSigninLink => '로그인';

  @override
  String get authAllFieldsRequired => '모든 항목을 입력해주세요.';

  @override
  String get authNicknameInvalid => '닉네임은 1~20자로 입력해주세요.';

  @override
  String get authWeakPassword => '비밀번호는 8자 이상이어야 해요.';

  @override
  String get authAgreeRequired => '약관에 동의해주세요.';

  @override
  String get authEmailInUse => '이미 가입된 이메일이에요. 로그인해 주세요.';

  @override
  String get authWeakPasswordServer => '비밀번호가 너무 약해요. 8자 이상으로 해주세요.';

  @override
  String get authSignupFailed => '가입에 실패했어요. 다시 시도해 주세요.';

  @override
  String get authSignupSuccess => '가입 완료!';

  @override
  String get feedTitle => '촬영 팁';

  @override
  String get feedTabPopular => '인기';

  @override
  String get feedTabRecent => '최신';

  @override
  String get feedFilterAll => '전체';

  @override
  String get feedMyAccountTooltip => '내 계정';

  @override
  String get feedLoadFailed => '불러오지 못했어요';

  @override
  String get feedEmpty => '아직 게시물이 없어요. 첫 사진을 올려보세요!';

  @override
  String get feedReportSuccess => '신고되었습니다';

  @override
  String get feedReportFailed => '신고에 실패했어요 (이미 신고했을 수 있어요)';

  @override
  String get feedDeleteSuccess => '삭제했어요';

  @override
  String get feedDeleteFailed => '삭제에 실패했어요';

  @override
  String get feedDeleteTitle => '이 글을 삭제할까요?';

  @override
  String get feedDeleteBody => '삭제하면 되돌릴 수 없어요.';

  @override
  String get feedDeleteConfirm => '삭제';

  @override
  String feedBlockTitle(String name) {
    return '$name 님을 차단할까요?';
  }

  @override
  String get feedBlockBody => '이 사용자의 게시물과 댓글이 보이지 않아요.';

  @override
  String get feedBlockConfirm => '차단';

  @override
  String get feedBlockSuccess => '차단했어요';

  @override
  String get feedBlockFailed => '차단에 실패했어요';

  @override
  String get feedMenuReport => '신고하기';

  @override
  String get feedMenuBlock => '차단하기';

  @override
  String get feedMenuDelete => '삭제하기';

  @override
  String get postDeleteTooltip => '삭제';

  @override
  String get postDeleteTitle => '이 글을 삭제할까요?';

  @override
  String get postDeleteBody => '삭제하면 되돌릴 수 없어요.';

  @override
  String get postDeleteSuccess => '삭제했어요';

  @override
  String get postDeleteFailed => '삭제에 실패했어요';

  @override
  String get postCommentDeleteTitle => '댓글을 삭제할까요?';

  @override
  String get postCommentDeleteBody => '삭제한 댓글은 되돌릴 수 없어요.';

  @override
  String get postCommentSendFailed => '댓글 전송에 실패했어요';

  @override
  String get postCommentHint => '댓글을 남겨보세요';

  @override
  String get postCommentLoadFailed => '댓글을 불러오지 못했어요';

  @override
  String get postCommentEmpty => '첫 댓글을 남겨보세요';

  @override
  String get postReportSuccess => '신고되었습니다';

  @override
  String get postReportFailed => '신고에 실패했어요 (이미 신고했을 수 있어요)';

  @override
  String postBlockTitle(String name) {
    return '$name 님을 차단할까요?';
  }

  @override
  String get postBlockBody => '이 사용자의 게시물과 댓글이 보이지 않아요.';

  @override
  String get postBlockSuccess => '차단했어요';

  @override
  String get postBlockFailed => '차단에 실패했어요';

  @override
  String get postMenuReport => '신고하기';

  @override
  String get postMenuBlock => '차단하기';

  @override
  String get postAnonymous => '익명';

  @override
  String get createPostTitle => '사진 올리기';

  @override
  String get createPostSubmit => '올리기';

  @override
  String get createPostMaxImages => '사진은 최대 10장까지 올릴 수 있어요';

  @override
  String createPostCountLabel(int count, int max) {
    return '$count/$max · 얼굴은 자동으로 가려집니다. 사진을 탭해 수정할 수 있어요.';
  }

  @override
  String get createPostModeLabel => '촬영 모드';

  @override
  String get createPostCaptionHint => '한 줄 팁을 남겨보세요';

  @override
  String get createPostUploadFailed => '업로드에 실패했어요';

  @override
  String get accountTitle => '내 프로필';

  @override
  String get accountLoadFailed => '불러오지 못했어요';

  @override
  String get accountNoProfile => '프로필이 없어요';

  @override
  String get accountEditNickname => '닉네임 편집';

  @override
  String get accountChangePhoto => '프로필 사진 변경';

  @override
  String get accountLoginMethod => '로그인 방식';

  @override
  String get accountBlockedUsers => '차단한 사용자';

  @override
  String get accountTheme => '화면 테마';

  @override
  String get accountLogout => '로그아웃';

  @override
  String get accountWithdraw => '회원 탈퇴';

  @override
  String accountPhotoChangeFailed(String error) {
    return '사진 변경 실패: $error';
  }

  @override
  String get accountNicknameInvalid => '닉네임은 1~20자로 입력해 주세요';

  @override
  String get accountNicknameChangeFailed => '닉네임 변경에 실패했어요';

  @override
  String get accountLogoutTitle => '로그아웃 할까요?';

  @override
  String get accountLogoutBody => '다시 로그인하면 이어서 사용할 수 있어요.';

  @override
  String get accountLogoutConfirm => '로그아웃';

  @override
  String get accountWithdrawTitle => '정말 탈퇴하시겠어요?';

  @override
  String get accountWithdrawBody => '다시 로그인하면 재가입할 수 있어요.';

  @override
  String get accountWithdrawConfirm => '탈퇴';

  @override
  String get accountWithdrawFailed => '탈퇴에 실패했어요';

  @override
  String get accountThemeSystem => '시스템 설정';

  @override
  String get accountThemeLight => '라이트';

  @override
  String get accountThemeDark => '다크';

  @override
  String get accountThemePickerTitle => '화면 테마';

  @override
  String get accountEditNicknameTitle => '닉네임 편집';

  @override
  String get accountSave => '저장';

  @override
  String get accountLoginTypeSuffix => ' 로그인';

  @override
  String get maskEditorTitle => '개인정보 가림';

  @override
  String get maskEditorDone => '완료';

  @override
  String get maskEditorApplyFailed => '가림 처리에 실패했어요';

  @override
  String get maskEditorHint => '드래그로 가릴 영역 추가 · 탭으로 선택';

  @override
  String get maskEditorHide => '가림 켜기';

  @override
  String get maskEditorShow => '가림 끄기';

  @override
  String get maskEditorDelete => '삭제';

  @override
  String get reportTitle => '신고 사유를 선택하세요';

  @override
  String get reportReasonSpam => '스팸/광고';

  @override
  String get reportReasonHate => '욕설·혐오 발언';

  @override
  String get reportReasonInappropriate => '부적절한 사진';

  @override
  String get reportReasonPrivacy => '개인정보 노출';

  @override
  String get reportReasonEtc => '기타';

  @override
  String get remoteControlTitle => '리모컨';

  @override
  String get remoteQrRescan => 'QR 다시 스캔';

  @override
  String get remoteScanPrompt => '촬영 폰에 표시된 QR 코드를 스캔하세요';

  @override
  String get remoteScanHint => '촬영 폰: 카메라 화면 상단 리모컨 아이콘 → 이 폰으로 촬영하기';

  @override
  String get remoteHintReady => '좋아요';

  @override
  String get remoteCaptureSuccess => '찰칵! 촬영 폰에 저장했어요';

  @override
  String get remoteCommandFailed => '명령이 실패했어요';

  @override
  String get remoteTimerOff => '타이머\n끔';

  @override
  String remoteTimerOn(int sec) {
    return '타이머\n$sec초';
  }

  @override
  String get remoteQrExpired => 'QR이 만료됐어요. 촬영 폰에서 QR을 다시 띄워 스캔해 주세요.';

  @override
  String get remoteBusy => '이미 다른 리모컨이 연결돼 있어요.';

  @override
  String get remoteVersionMismatch => '연결이 거부됐어요. 두 폰의 앱을 최신으로 업데이트해 주세요.';

  @override
  String get remoteConnectFailed =>
      '연결하지 못했어요. 두 폰이 같은 Wi-Fi(또는 핫스팟)에 있는지 확인해 주세요.';

  @override
  String get remoteDisconnected => '연결이 끊겼어요.';

  @override
  String get remotePairingTitle => '리모컨 촬영';

  @override
  String get remotePairingHostTitle => '이 폰으로 촬영하기';

  @override
  String get remotePairingHostSubtitle => '삼각대에 두고, 다른 폰에서 QR을 스캔해요';

  @override
  String get remotePairingRemoteTitle => '이 폰을 리모컨으로';

  @override
  String get remotePairingRemoteSubtitle => '촬영 폰에 뜬 QR을 스캔해서 연결해요';

  @override
  String get remotePairingWifiHint => '두 폰이 같은 Wi-Fi(또는 한 폰의 핫스팟)에 있어야 해요.';

  @override
  String get remoteHostQrTitle => '리모컨 연결 대기';

  @override
  String get remoteHostQrInstruction =>
      '리모컨 폰의 똥손카메라에서\n[리모컨 촬영 → 이 폰을 리모컨으로]를 눌러\n이 QR을 스캔하세요.';

  @override
  String get poseOff => '끄기';

  @override
  String get poseAiRecommend => 'AI 추천';

  @override
  String get poseCategorySelfie => '셀카';

  @override
  String get poseCategoryFullBody => '전신';

  @override
  String get poseCategoryCouple => '커플';

  @override
  String get poseCategoryFriends => '우정';

  @override
  String get posePreparing => '포즈 준비 중';
}
