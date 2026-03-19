import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_storage_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.authStateChanges;
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

enum SignInResult { success, cancelled, error }

class AuthService {
  final FirebaseAuth _auth = FirebaseService.auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseService.firestore;

  // ── Google Sign-In ──────────────────────────────────────────────────────────
  Future<SignInResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled the picker
      if (googleUser == null) return SignInResult.cancelled;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return SignInResult.success;
    } catch (e) {
      return SignInResult.error;
    }
  }

  // ── Check if user already has a persona ────────────────────────────────────
  // Returns anonId if persona exists, null if not
  Future<String?> getAnonId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Check cache first
    final cached = LocalStorageService.getCachedAnonId();
    if (cached != null) return cached;

    // Check Firestore
    try {
      final doc = await _firestore
          .collection('private_users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final anonId = doc.data()?['publicProfileId'] as String?;
        if (anonId != null && anonId.isNotEmpty) {
          // Cache it locally
          await LocalStorageService.setCachedAnonId(anonId);
          return anonId;
        }
      }
    } catch (_) {
      // If Firestore fails, treat as no persona (safe fallback)
    }

    return null;
  }

  // ── Sign out ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await LocalStorageService.clearUserData();
  }

  User? get currentUser => _auth.currentUser;
}
