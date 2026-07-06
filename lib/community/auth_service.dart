// lib/community/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import 'user_repository.dart';
import 'models/user_profile.dart';

/// Firebase Auth 래퍼. 소셜 로그인은 모두 Firebase 사용자(uid)로 수렴한다.
/// (A1: Google. Apple/Kakao는 후속 계획에서 메서드 추가.)
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  final UserRepository _users;
  AuthService({FirebaseAuth? auth, GoogleSignIn? google, UserRepository? users})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn(),
      _users = users ?? UserRepository();

  Stream<User?> authState() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Google 로그인. 사용자가 취소하면 null.
  Future<User?> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return null; // 취소
    final gAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) {
      await _users.ensureProfile(user: user, loginType: LoginType.google);
    }
    return user;
  }

  /// Apple 로그인. 사용자가 취소하면 null.
  Future<User?> signInWithApple() async {
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauth = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      final result = await _auth.signInWithCredential(oauth);
      final user = result.user;
      if (user != null) {
        await _users.ensureProfile(user: user, loginType: LoginType.apple);
      }
      return user;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null; // 취소
      rethrow;
    }
  }

  /// 카카오 로그인. 사용자가 취소하면 null.
  Future<User?> signInWithKakao() async {
    final OAuthToken kakaoToken;
    try {
      kakaoToken = await isKakaoTalkInstalled()
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return null; // 사용자 취소
      rethrow;
    }
    final callable = FirebaseFunctions.instanceFor(
      region: 'asia-northeast3',
    ).httpsCallable('kakaoCustomToken');
    final result = await callable.call<Map<String, dynamic>>({
      'accessToken': kakaoToken.accessToken,
    });
    final customToken = result.data['token'] as String;
    final cred = await _auth.signInWithCustomToken(customToken);
    final user = cred.user;
    if (user != null) {
      await _users.ensureProfile(user: user, loginType: LoginType.kakao);
    }
    return user;
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
