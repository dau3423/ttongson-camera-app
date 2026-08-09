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
  String get guideLevelLowerLeft => '左を下げて';

  @override
  String get guideLevelLowerRight => '右を下げて';

  @override
  String get guideHeadroomRaise => 'カメラを少し上げて';

  @override
  String get guideHeadroomLower => 'カメラを少し下げて';

  @override
  String get guideAngleEyeLevelDown => 'カメラを目線まで下げて';

  @override
  String get guideAngleEyeLevelUp => 'カメラを目線まで上げて';

  @override
  String get guideAngleFrontalDown => 'カメラを水平に下げて';

  @override
  String get guideAngleFrontalUp => 'カメラを水平に上げて';

  @override
  String get guideZoomCloser => '少し近づくかズームしてみて';

  @override
  String get guideZoomFarther => '少し離れるか引いてみて';

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
  String get guideMovePrompt => 'ここに移動して';

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
    return '$sidesが切れてるよ';
  }

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonAgree => '同意する';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonDelete => '削除';

  @override
  String get cameraSwitchFailed => 'カメラの切り替えに失敗しました';

  @override
  String get galleryOpenFailed => '写真を開けませんでした';

  @override
  String saveFailed(String error) {
    return '保存失敗: $error';
  }

  @override
  String get compositionConsentTitle => '構図おすすめのご案内';

  @override
  String get compositionConsentBody =>
      'おすすめ時に現在のフレーム1枚を分析サーバーへ送信します。画像は保存されません。';

  @override
  String get suggestFailed => 'おすすめを取得できませんでした。もう一度試してみてください。';

  @override
  String get posesLoadFailed => 'ポーズを読み込めませんでした';

  @override
  String get aiConsentTitle => 'AIおすすめのご案内';

  @override
  String get aiConsentBody => 'おすすめ時に現在のフレーム1枚を分析サーバーへ送信します。画像は保存されません。';

  @override
  String cameraRestartFailedDetail(String error) {
    return 'カメラを再起動できませんでした: $error';
  }

  @override
  String get wifiNotConnected => 'Wi-Fiに接続されていません。同じWi-Fiまたはホットスポットに接続してください。';

  @override
  String get remotePrepFailed => 'リモコン接続の準備に失敗しました。少し待ってからもう一度試してみてください。';

  @override
  String get remoteConnected => 'リモコン接続中';

  @override
  String get remoteWaiting => 'リモコン待機中';

  @override
  String get captureAiEnhanceConsentTitle => 'AI補正のご案内';

  @override
  String get captureAiEnhanceConsentBody =>
      'AI補正時に写真1枚を分析サーバーへ送信します。画像は保存されません。';

  @override
  String get captureEnhanceFailed => 'この写真は補正できません';

  @override
  String get captureAiEnhanceFailed => 'AI改善を取得できませんでした。プリセットを維持します。';

  @override
  String get captureSaved => '保存しました';

  @override
  String get captureSavePermissionFailed => '保存失敗 — 権限を確認してください';

  @override
  String get captureMoodTitle => '今日のムード';

  @override
  String get captureAiEnhanceTooltip => 'AIでもっとかわいく（この写真に合わせて）';

  @override
  String get captureSaveButton => '保存';

  @override
  String get captureNameHint => 'AIが名前をつけてくれます';

  @override
  String get captureOriginalLabel => '元の写真';

  @override
  String get authWelcomeBack => 'おかえり！';

  @override
  String get authLoginSubtitle => 'へたっぴでもプロみたいに · ログインして続きを撮ろう';

  @override
  String get authEmailLabel => 'メールアドレス';

  @override
  String get authPasswordLabel => 'パスワード';

  @override
  String get authLoginButton => 'ログイン';

  @override
  String get authOrDivider => 'または';

  @override
  String get authNoAccount => 'アカウントをお持ちでないですか？ ';

  @override
  String get authSignupLink => '新規登録';

  @override
  String get authEmailEmpty => 'メールアドレスとパスワードを入力してください。';

  @override
  String get authInvalidEmail => 'メールアドレスの形式が正しくありません。';

  @override
  String get authLoginFailed => 'ログインに失敗しました。';

  @override
  String get authLoginFailedRetry => 'ログインに失敗しました。もう一度試してみてください。';

  @override
  String get authWrongCredential => 'メールアドレスまたはパスワードが違います。';

  @override
  String get authAccountDisabled => 'このアカウントは使用できません。';

  @override
  String get authWithdrawnTitle => '退会済みのアカウントです';

  @override
  String get authWithdrawnBody => 'このアカウントは退会処理済みです。再登録しますか？';

  @override
  String get authRejoin => '再登録';

  @override
  String get authLoginSuccess => 'ようこそ！';

  @override
  String get authLoginSuccessSubtitle => 'さっそく撮影してみましょう！';

  @override
  String get authLoginSuccessCta => '撮影へ';

  @override
  String get authSignupTitle => '新規登録';

  @override
  String get authSignupSubtitle => '30秒でできます';

  @override
  String get authNicknameLabel => 'ニックネーム';

  @override
  String get authNicknameHint => 'へたっぴ卒業生';

  @override
  String get authPasswordHint => '8文字以上';

  @override
  String get authAgreeTerms => '利用規約とプライバシーポリシーに同意します';

  @override
  String get authSignupButton => '登録して始める';

  @override
  String get authHaveAccount => 'すでにアカウントをお持ちですか？ ';

  @override
  String get authSigninLink => 'ログイン';

  @override
  String get authKakao => 'カカオ';

  @override
  String get authAllFieldsRequired => 'すべての項目を入力してください。';

  @override
  String get authNicknameInvalid => 'ニックネームは1〜20文字で入力してください。';

  @override
  String get authWeakPassword => 'パスワードは8文字以上にしてください。';

  @override
  String get authAgreeRequired => '利用規約に同意してください。';

  @override
  String get authEmailInUse => 'このメールアドレスはすでに登録されています。ログインしてください。';

  @override
  String get authWeakPasswordServer => 'パスワードが弱すぎます。8文字以上にしてください。';

  @override
  String get authSignupFailed => '登録に失敗しました。もう一度試してみてください。';

  @override
  String get authSignupSuccess => '登録完了！';

  @override
  String get feedTitle => '撮影のコツ';

  @override
  String get feedTabPopular => '人気';

  @override
  String get feedTabRecent => '最新';

  @override
  String get feedFilterAll => 'すべて';

  @override
  String get feedMyAccountTooltip => 'マイアカウント';

  @override
  String get feedLoadFailed => '読み込めませんでした';

  @override
  String get feedEmpty => 'まだ投稿がありません。最初の写真を投稿してみましょう！';

  @override
  String get feedReportSuccess => '通報しました';

  @override
  String get feedReportFailed => '通報に失敗しました（すでに通報済みかもしれません）';

  @override
  String get feedDeleteSuccess => '削除しました';

  @override
  String get feedDeleteFailed => '削除に失敗しました';

  @override
  String get feedDeleteTitle => 'この投稿を削除しますか？';

  @override
  String get feedDeleteBody => '削除すると元に戻せません。';

  @override
  String get feedDeleteConfirm => '削除';

  @override
  String feedBlockTitle(String name) {
    return '$name さんをブロックしますか？';
  }

  @override
  String get feedBlockBody => 'このユーザーの投稿やコメントが表示されなくなります。';

  @override
  String get feedBlockConfirm => 'ブロック';

  @override
  String get feedBlockSuccess => 'ブロックしました';

  @override
  String get feedBlockFailed => 'ブロックに失敗しました';

  @override
  String get feedMenuReport => '通報する';

  @override
  String get feedMenuBlock => 'ブロックする';

  @override
  String get feedMenuDelete => '削除する';

  @override
  String get postDeleteTooltip => '削除';

  @override
  String get postDeleteTitle => 'この投稿を削除しますか？';

  @override
  String get postDeleteBody => '削除すると元に戻せません。';

  @override
  String get postDeleteSuccess => '削除しました';

  @override
  String get postDeleteFailed => '削除に失敗しました';

  @override
  String get postCommentDeleteTitle => 'コメントを削除しますか？';

  @override
  String get postCommentDeleteBody => '削除したコメントは元に戻せません。';

  @override
  String get postCommentSendFailed => 'コメントの送信に失敗しました';

  @override
  String get postCommentHint => 'コメントを書いてみよう';

  @override
  String get postCommentLoadFailed => 'コメントを読み込めませんでした';

  @override
  String get postCommentEmpty => '最初のコメントを書いてみよう';

  @override
  String get postReportSuccess => '通報しました';

  @override
  String get postReportFailed => '通報に失敗しました（すでに通報済みかもしれません）';

  @override
  String postBlockTitle(String name) {
    return '$name さんをブロックしますか？';
  }

  @override
  String get postBlockBody => 'このユーザーの投稿やコメントが表示されなくなります。';

  @override
  String get postBlockSuccess => 'ブロックしました';

  @override
  String get postBlockFailed => 'ブロックに失敗しました';

  @override
  String get postMenuReport => '通報する';

  @override
  String get postMenuBlock => 'ブロックする';

  @override
  String get postAnonymous => '匿名';

  @override
  String get createPostTitle => '写真を投稿';

  @override
  String get createPostSubmit => '投稿';

  @override
  String get createPostMaxImages => '写真は最大10枚まで投稿できます';

  @override
  String createPostCountLabel(int count, int max) {
    return '$count/$max · 顔は自動でマスクされます。写真をタップして編集できます。';
  }

  @override
  String get createPostModeLabel => '撮影モード';

  @override
  String get createPostCaptionHint => '一言アドバイスを書いてみよう';

  @override
  String get createPostUploadFailed => 'アップロードに失敗しました';

  @override
  String get accountTitle => 'マイプロフィール';

  @override
  String get accountLoadFailed => '読み込めませんでした';

  @override
  String get accountNoProfile => 'プロフィールがありません';

  @override
  String get accountEditNickname => 'ニックネームを編集';

  @override
  String get accountChangePhoto => 'プロフィール写真を変更';

  @override
  String get accountLoginMethod => 'ログイン方法';

  @override
  String get accountBlockedUsers => 'ブロックしたユーザー';

  @override
  String get blockedUsersEmpty => 'ブロックしたユーザーはいません';

  @override
  String get blockedUsersUnblock => 'ブロック解除';

  @override
  String get accountTheme => 'テーマ';

  @override
  String get accountLogout => 'ログアウト';

  @override
  String get accountWithdraw => '退会する';

  @override
  String accountPhotoChangeFailed(String error) {
    return '写真の変更に失敗しました: $error';
  }

  @override
  String get accountNicknameInvalid => 'ニックネームは1〜20文字で入力してください';

  @override
  String get accountNicknameChangeFailed => 'ニックネームの変更に失敗しました';

  @override
  String get accountLogoutTitle => 'ログアウトしますか？';

  @override
  String get accountLogoutBody => '再ログインすればいつでも続きができます。';

  @override
  String get accountLogoutConfirm => 'ログアウト';

  @override
  String get accountWithdrawTitle => '本当に退会しますか？';

  @override
  String get accountWithdrawBody => '再登録はいつでもできます。';

  @override
  String get accountWithdrawConfirm => '退会';

  @override
  String get accountWithdrawFailed => '退会に失敗しました';

  @override
  String get accountThemeSystem => 'システム設定';

  @override
  String get accountThemeLight => 'ライト';

  @override
  String get accountThemeDark => 'ダーク';

  @override
  String get accountThemePickerTitle => 'テーマ';

  @override
  String get accountEditNicknameTitle => 'ニックネームを編集';

  @override
  String get accountSave => '保存';

  @override
  String get accountLoginTypeSuffix => ' ログイン';

  @override
  String get maskEditorTitle => 'プライバシーマスク';

  @override
  String get maskEditorDone => '完了';

  @override
  String get maskEditorApplyFailed => 'マスク処理に失敗しました';

  @override
  String get maskEditorHint => 'ドラッグでマスク領域を追加 · タップで選択';

  @override
  String get maskEditorHide => 'マスクをオン';

  @override
  String get maskEditorShow => 'マスクをオフ';

  @override
  String get maskEditorDelete => '削除';

  @override
  String get reportTitle => '通報理由を選んでください';

  @override
  String get reportReasonSpam => 'スパム・広告';

  @override
  String get reportReasonHate => '暴言・ヘイトスピーチ';

  @override
  String get reportReasonInappropriate => '不適切な写真';

  @override
  String get reportReasonPrivacy => '個人情報の漏洩';

  @override
  String get reportReasonEtc => 'その他';

  @override
  String get remoteControlTitle => 'リモコン';

  @override
  String get remoteQrRescan => 'QRを再スキャン';

  @override
  String get remoteScanPrompt => '撮影スマホに表示されたQRコードをスキャンしてください';

  @override
  String get remoteScanHint => '撮影スマホ：カメラ画面上部のリモコンアイコン → このスマホで撮影';

  @override
  String get remoteHintReady => 'いいね！';

  @override
  String get remoteCaptureSuccess => 'パシャ！撮影スマホに保存しました';

  @override
  String get remoteCommandFailed => 'コマンドに失敗しました';

  @override
  String get remoteTimerOff => 'タイマー\nOFF';

  @override
  String remoteTimerOn(int sec) {
    return 'タイマー\n$sec秒';
  }

  @override
  String get remoteQrExpired => 'QRの有効期限が切れました。撮影スマホでQRを再表示してスキャンしてください。';

  @override
  String get remoteBusy => 'すでに別のリモコンが接続されています。';

  @override
  String get remoteVersionMismatch => '接続が拒否されました。両方のスマホのアプリを最新版にアップデートしてください。';

  @override
  String get remoteConnectFailed =>
      '接続できませんでした。両方のスマホが同じWi-Fi（またはホットスポット）に接続しているか確認してください。';

  @override
  String get remoteDisconnected => '接続が切れました。';

  @override
  String get remotePairingTitle => 'リモコン撮影';

  @override
  String get remotePairingHostTitle => 'このスマホで撮影する';

  @override
  String get remotePairingHostSubtitle => '三脚に置いて、別のスマホでQRをスキャンしてね';

  @override
  String get remotePairingRemoteTitle => 'このスマホをリモコンにする';

  @override
  String get remotePairingRemoteSubtitle => '撮影スマホのQRをスキャンして接続しよう';

  @override
  String get remotePairingWifiHint =>
      '両方のスマホが同じWi-Fi（またはホットスポット）に接続している必要があります。';

  @override
  String get remoteHostQrTitle => 'リモコン接続待機中';

  @override
  String get remoteHostQrInstruction =>
      'リモコンスマホのへたっぴカメラで\n[リモコン撮影 → このスマホをリモコンにする]をタップして\nこのQRをスキャンしてください。';

  @override
  String get poseOff => 'オフ';

  @override
  String get poseAiRecommend => 'AIおすすめ';

  @override
  String get poseCategorySelfie => '自撮り';

  @override
  String get poseCategoryFullBody => '全身';

  @override
  String get poseCategoryCouple => 'カップル';

  @override
  String get poseCategoryFriends => '友達';

  @override
  String get posePreparing => 'ポーズ準備中';
}
