import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.authStateChanges;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  final FirebaseAuth _auth = FirebaseService.auth;

  Future<void> sendEmailLink(String email) async {
    // Hosting-based email link URL – MUST match authorized domain
    const continueUrl = 'https://fess-v2.firebaseapp.com/finishSignUp';

    final actionCodeSettings = ActionCodeSettings(
      url: continueUrl,
      handleCodeInApp: true,
      androidPackageName: 'com.confes.fessv2',
      androidInstallApp: true,
      androidMinimumVersion: '21',
      // linkDomain is optional; default Hosting domain is used
    );

    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );

    // Store email locally for completing sign-in later
    await LocalStorageService.setPendingEmail(email);
  }

  bool isSignInLink(String link) {
    return _auth.isSignInWithEmailLink(link);
  }

  Future<UserCredential> signInWithEmailLink(String email, String link) async {
    final credential =
    await _auth.signInWithEmailLink(email: email, emailLink: link);
    // Clear pending email after successful sign-in
    await LocalStorageService.clearPendingEmail();
    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
