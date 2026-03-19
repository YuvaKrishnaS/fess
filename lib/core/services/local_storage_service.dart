import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _appBoxName = 'fess_app_data';
  static const String _userBoxName = 'fess_user_data';

  static Box? _appBox;
  static Box? _userBox;

  static Future<void> initialize() async {
    await Hive.initFlutter();

    _appBox = await Hive.openBox(_appBoxName);
    _userBox = await Hive.openBox(_userBoxName);

    print('✓ Hive boxes initialized');
  }

  static Box get appBox {
    if (_appBox == null || !_appBox!.isOpen) {
      throw Exception('App box not initialized');
    }
    return _appBox!;
  }

  static Box get userBox {
    if (_userBox == null || !_userBox!.isOpen) {
      throw Exception('User box not initialized');
    }
    return _userBox!;
  }

  // Onboarding
  static Future<void> setHasSeenOnboarding(bool value) async {
    await appBox.put('has_seen_onboarding', value);
  }

  static bool getHasSeenOnboarding() {
    return appBox.get('has_seen_onboarding', defaultValue: false) as bool;
  }

  // Pending email for magic link
  static const _pendingEmailKey = 'pending_email_for_link';

  static Future<void> setPendingEmail(String email) async {
    await userBox.put(_pendingEmailKey, email);
  }

  static String? getPendingEmail() {
    final value = userBox.get(_pendingEmailKey);
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static Future<void> clearPendingEmail() async {
    await userBox.delete(_pendingEmailKey);
  }

  // User-level data reset
  static Future<void> clearUserData() async {
    await userBox.clear();
  }

  static Future<void> clearAllData() async {
    await appBox.clear();
    await userBox.clear();
  }
}
