import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Disable analytics and crash reporting
    await _disableAnalytics();

    // Configure Firestore settings
    _configureFirestore();
  }

  static Future<void> _disableAnalytics() async {
    // Firebase Analytics is not included in dependencies
    // This ensures no tracking is enabled by default
    // print('[SUCCESS] Analytics disabled (not included in project)');
  }

  static void _configureFirestore() {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // print('[SUCCESS] Firestore configured');
  }

  // Auth instance
  static FirebaseAuth get auth => FirebaseAuth.instance;

  // Firestore instance
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  // Current user
  static User? get currentUser => auth.currentUser;

  // Auth state stream
  static Stream<User?> get authStateChanges => auth.authStateChanges();
}
