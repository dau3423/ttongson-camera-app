// lib/community/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Auth 래퍼. 소셜 로그인은 모두 Firebase 사용자(uid)로 수렴한다.
/// (A1: Google. Apple/Kakao는 후속 계획에서 메서드 추가.)
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  AuthService({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn();

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
    return result.user;
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
