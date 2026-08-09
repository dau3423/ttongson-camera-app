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
  String get guideLevelLowerLeft => '把左边放低一点';

  @override
  String get guideLevelLowerRight => '把右边放低一点';

  @override
  String get guideHeadroomRaise => '相机稍微抬高一点';

  @override
  String get guideHeadroomLower => '相机稍微放低一点';

  @override
  String get guideAngleEyeLevelDown => '相机往下调到眼平高度';

  @override
  String get guideAngleEyeLevelUp => '相机往上调到眼平高度';

  @override
  String get guideAngleFrontalDown => '相机往下调至水平';

  @override
  String get guideAngleFrontalUp => '相机往上调至水平';

  @override
  String get guideZoomCloser => '靠近一点或放大';

  @override
  String get guideZoomFarther => '退后一点或缩小';

  @override
  String get guideMoveRight => '右';

  @override
  String get guideMoveLeft => '左';

  @override
  String get guideMoveUp => '上';

  @override
  String get guideMoveDown => '下';

  @override
  String get guideMoveSeparator => ' · ';

  @override
  String get guideMovePrompt => '往这边移';

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
    return '$sides被切到了';
  }

  @override
  String get commonCancel => '取消';

  @override
  String get commonAgree => '同意';

  @override
  String get commonRetry => '重试';

  @override
  String get commonDelete => '删除';

  @override
  String get cameraSwitchFailed => '切换相机失败';

  @override
  String get galleryOpenFailed => '无法打开相册';

  @override
  String saveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get compositionConsentTitle => '构图推荐说明';

  @override
  String get compositionConsentBody => '请求推荐时，会将当前画面发送至分析服务器，图像不会被留存。';

  @override
  String get suggestFailed => '获取推荐失败，请重试。';

  @override
  String get posesLoadFailed => '加载姿势失败';

  @override
  String get aiConsentTitle => 'AI推荐说明';

  @override
  String get aiConsentBody => '请求推荐时，会将当前画面发送至分析服务器，图像不会被留存。';

  @override
  String cameraRestartFailedDetail(String error) {
    return '相机重启失败：$error';
  }

  @override
  String get wifiNotConnected => '未连接Wi-Fi，请连接到同一Wi-Fi或热点。';

  @override
  String get remotePrepFailed => '遥控连接准备失败，请稍后重试。';

  @override
  String get remoteConnected => '遥控已连接';

  @override
  String get remoteWaiting => '等待遥控中';

  @override
  String get captureAiEnhanceConsentTitle => 'AI修图说明';

  @override
  String get captureAiEnhanceConsentBody => 'AI修图时，会将一张照片发送至分析服务器，图像不会被留存。';

  @override
  String get captureEnhanceFailed => '这张照片无法修图';

  @override
  String get captureAiEnhanceFailed => 'AI优化失败，保持原有滤镜。';

  @override
  String get captureSaved => '已保存';

  @override
  String get captureSavePermissionFailed => '保存失败——请检查权限';

  @override
  String get captureMoodTitle => '今日氛围';

  @override
  String get captureAiEnhanceTooltip => 'AI美化（针对这张照片）';

  @override
  String get captureSaveButton => '保存';

  @override
  String get captureNameHint => '让AI给它取个名字';

  @override
  String get captureOriginalLabel => '原图';

  @override
  String get authWelcomeBack => '欢迎回来';

  @override
  String get authLoginSubtitle => '手残也能拍出大片 · 登录后继续拍';

  @override
  String get authEmailLabel => '邮箱';

  @override
  String get authPasswordLabel => '密码';

  @override
  String get authLoginButton => '登录';

  @override
  String get authOrDivider => '或';

  @override
  String get authNoAccount => '还没有账号？ ';

  @override
  String get authSignupLink => '注册';

  @override
  String get authEmailEmpty => '请输入邮箱和密码。';

  @override
  String get authInvalidEmail => '邮箱格式不正确。';

  @override
  String get authLoginFailed => '登录失败。';

  @override
  String get authLoginFailedRetry => '登录失败，请重试。';

  @override
  String get authWrongCredential => '邮箱或密码不正确。';

  @override
  String get authAccountDisabled => '此账号已被禁用。';

  @override
  String get authWithdrawnTitle => '该账号已注销';

  @override
  String get authWithdrawnBody => '此账号已注销，要重新注册吗？';

  @override
  String get authRejoin => '重新注册';

  @override
  String get authLoginSuccess => '欢迎回来！';

  @override
  String get authLoginSuccessSubtitle => '开始拍摄吧？';

  @override
  String get authLoginSuccessCta => '去拍照';

  @override
  String get authSignupTitle => '注册';

  @override
  String get authSignupSubtitle => '30秒搞定';

  @override
  String get authNicknameLabel => '昵称';

  @override
  String get authNicknameHint => '手残逆袭者';

  @override
  String get authPasswordHint => '8位以上';

  @override
  String get authAgreeTerms => '我同意用户协议和隐私政策';

  @override
  String get authSignupButton => '注册并开始';

  @override
  String get authHaveAccount => '已有账号？ ';

  @override
  String get authSigninLink => '登录';

  @override
  String get authKakao => 'Kakao';

  @override
  String get authAllFieldsRequired => '请填写所有字段。';

  @override
  String get authNicknameInvalid => '昵称需为1~20个字符。';

  @override
  String get authWeakPassword => '密码至少需要8个字符。';

  @override
  String get authAgreeRequired => '请同意条款。';

  @override
  String get authEmailInUse => '该邮箱已被注册，请直接登录。';

  @override
  String get authWeakPasswordServer => '密码太简单，请使用8位以上字符。';

  @override
  String get authSignupFailed => '注册失败，请重试。';

  @override
  String get authSignupSuccess => '注册成功！';

  @override
  String get feedTitle => '拍摄技巧';

  @override
  String get feedTabPopular => '热门';

  @override
  String get feedTabRecent => '最新';

  @override
  String get feedFilterAll => '全部';

  @override
  String get feedMyAccountTooltip => '我的账号';

  @override
  String get feedLoadFailed => '加载失败';

  @override
  String get feedEmpty => '还没有帖子，来发第一张照片吧！';

  @override
  String get feedReportSuccess => '已举报';

  @override
  String get feedReportFailed => '举报失败（可能已经举报过了）';

  @override
  String get feedDeleteSuccess => '已删除';

  @override
  String get feedDeleteFailed => '删除失败';

  @override
  String get feedDeleteTitle => '删除这篇帖子？';

  @override
  String get feedDeleteBody => '删除后无法恢复。';

  @override
  String get feedDeleteConfirm => '删除';

  @override
  String feedBlockTitle(String name) {
    return '屏蔽 $name？';
  }

  @override
  String get feedBlockBody => '屏蔽后将看不到该用户的帖子和评论。';

  @override
  String get feedBlockConfirm => '屏蔽';

  @override
  String get feedBlockSuccess => '已屏蔽';

  @override
  String get feedBlockFailed => '屏蔽失败';

  @override
  String get feedMenuReport => '举报';

  @override
  String get feedMenuBlock => '屏蔽';

  @override
  String get feedMenuDelete => '删除';

  @override
  String get postDeleteTooltip => '删除';

  @override
  String get postDeleteTitle => '删除这篇帖子？';

  @override
  String get postDeleteBody => '删除后无法恢复。';

  @override
  String get postDeleteSuccess => '已删除';

  @override
  String get postDeleteFailed => '删除失败';

  @override
  String get postCommentDeleteTitle => '删除这条评论？';

  @override
  String get postCommentDeleteBody => '删除后无法恢复。';

  @override
  String get postCommentSendFailed => '评论发送失败';

  @override
  String get postCommentHint => '来说点什么吧';

  @override
  String get postCommentLoadFailed => '加载评论失败';

  @override
  String get postCommentEmpty => '来留下第一条评论吧';

  @override
  String get postReportSuccess => '已举报';

  @override
  String get postReportFailed => '举报失败（可能已经举报过了）';

  @override
  String postBlockTitle(String name) {
    return '屏蔽 $name？';
  }

  @override
  String get postBlockBody => '屏蔽后将看不到该用户的帖子和评论。';

  @override
  String get postBlockSuccess => '已屏蔽';

  @override
  String get postBlockFailed => '屏蔽失败';

  @override
  String get postMenuReport => '举报';

  @override
  String get postMenuBlock => '屏蔽';

  @override
  String get postAnonymous => '匿名';

  @override
  String get createPostTitle => '发布照片';

  @override
  String get createPostSubmit => '发布';

  @override
  String get createPostMaxImages => '最多可上传10张照片';

  @override
  String createPostCountLabel(int count, int max) {
    return '$count/$max · 人脸自动打码，点击照片可编辑。';
  }

  @override
  String get createPostModeLabel => '拍摄模式';

  @override
  String get createPostCaptionHint => '留下一条拍摄小贴士';

  @override
  String get createPostUploadFailed => '上传失败';

  @override
  String get accountTitle => '我的主页';

  @override
  String get accountLoadFailed => '加载失败';

  @override
  String get accountNoProfile => '暂无个人资料';

  @override
  String get accountEditNickname => '编辑昵称';

  @override
  String get accountChangePhoto => '更换头像';

  @override
  String get accountLoginMethod => '登录方式';

  @override
  String get accountBlockedUsers => '已屏蔽的用户';

  @override
  String get blockedUsersEmpty => '还没有屏蔽任何人';

  @override
  String get blockedUsersUnblock => '解除屏蔽';

  @override
  String get accountTheme => '界面主题';

  @override
  String get accountLogout => '退出登录';

  @override
  String get accountWithdraw => '注销账号';

  @override
  String accountPhotoChangeFailed(String error) {
    return '头像更换失败：$error';
  }

  @override
  String get accountNicknameInvalid => '昵称需为1~20个字符';

  @override
  String get accountNicknameChangeFailed => '昵称修改失败';

  @override
  String get accountLogoutTitle => '退出登录？';

  @override
  String get accountLogoutBody => '重新登录后可继续使用。';

  @override
  String get accountLogoutConfirm => '退出登录';

  @override
  String get accountWithdrawTitle => '确定要注销账号吗？';

  @override
  String get accountWithdrawBody => '注销后可以重新登录注册。';

  @override
  String get accountWithdrawConfirm => '注销';

  @override
  String get accountWithdrawFailed => '注销失败';

  @override
  String get accountThemeSystem => '跟随系统';

  @override
  String get accountThemeLight => '浅色';

  @override
  String get accountThemeDark => '深色';

  @override
  String get accountThemePickerTitle => '界面主题';

  @override
  String get accountEditNicknameTitle => '编辑昵称';

  @override
  String get accountSave => '保存';

  @override
  String get accountLoginTypeSuffix => ' 登录';

  @override
  String get maskEditorTitle => '隐私遮蔽';

  @override
  String get maskEditorDone => '完成';

  @override
  String get maskEditorApplyFailed => '遮蔽处理失败';

  @override
  String get maskEditorHint => '拖动添加遮蔽区域 · 点击选中';

  @override
  String get maskEditorHide => '开启遮蔽';

  @override
  String get maskEditorShow => '关闭遮蔽';

  @override
  String get maskEditorDelete => '删除';

  @override
  String get reportTitle => '请选择举报原因';

  @override
  String get reportReasonSpam => '垃圾广告/营销';

  @override
  String get reportReasonHate => '辱骂/仇恨言论';

  @override
  String get reportReasonInappropriate => '不当内容';

  @override
  String get reportReasonPrivacy => '隐私泄露';

  @override
  String get reportReasonEtc => '其他';

  @override
  String get remoteControlTitle => '遥控';

  @override
  String get remoteQrRescan => '重新扫码';

  @override
  String get remoteScanPrompt => '扫描拍摄手机上的二维码';

  @override
  String get remoteScanHint => '拍摄手机：相机界面顶部遥控图标 → 用这台手机拍摄';

  @override
  String get remoteHintReady => '棒！';

  @override
  String get remoteCaptureSuccess => '咔嚓！已保存到拍摄手机';

  @override
  String get remoteCommandFailed => '指令发送失败';

  @override
  String get remoteTimerOff => '定时\n关';

  @override
  String remoteTimerOn(int sec) {
    return '定时\n$sec秒';
  }

  @override
  String get remoteQrExpired => '二维码已过期，请在拍摄手机上重新生成并扫码。';

  @override
  String get remoteBusy => '已有其他遥控器在连接中。';

  @override
  String get remoteVersionMismatch => '连接被拒绝，请把两台手机的应用都更新到最新版本。';

  @override
  String get remoteConnectFailed => '连接失败，请确认两台手机在同一Wi-Fi（或热点）下。';

  @override
  String get remoteDisconnected => '连接已断开。';

  @override
  String get remotePairingTitle => '遥控拍摄';

  @override
  String get remotePairingHostTitle => '用这台手机拍摄';

  @override
  String get remotePairingHostSubtitle => '架好三脚架，用另一台手机扫码';

  @override
  String get remotePairingRemoteTitle => '把这台手机当遥控器';

  @override
  String get remotePairingRemoteSubtitle => '扫描拍摄手机上的二维码即可连接';

  @override
  String get remotePairingWifiHint => '两台手机需在同一Wi-Fi（或其中一台的热点）下。';

  @override
  String get remoteHostQrTitle => '等待遥控器连接';

  @override
  String get remoteHostQrInstruction =>
      '在遥控手机的手残相机里，\n点击【遥控拍摄 → 把这台手机当遥控器】\n然后扫描这个二维码。';

  @override
  String get poseOff => '关闭';

  @override
  String get poseAiRecommend => 'AI推荐';

  @override
  String get poseCategorySelfie => '自拍';

  @override
  String get poseCategoryFullBody => '全身';

  @override
  String get poseCategoryCouple => '情侣';

  @override
  String get poseCategoryFriends => '朋友';

  @override
  String get posePreparing => '姿势加载中';
}
