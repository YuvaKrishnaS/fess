import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/firebase_service.dart';
import 'core/services/local_storage_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await _initializeApp();

  // Run app
  runApp(
    const ProviderScope(
      child: FessApp(),
    ),
  );
}

Future<void> _initializeApp() async {
  try {
    print('Initializing Fess...');

    // Initialize Firebase
    await FirebaseService.initialize();
    print('✓ Firebase initialized');

    // Initialize local storage
    await LocalStorageService.initialize();
    print('✓ Local storage initialized');

    print('App initialization complete\n');
  } catch (e, stackTrace) {
    print('Initialization error: $e');
    print(stackTrace);
  }
}
