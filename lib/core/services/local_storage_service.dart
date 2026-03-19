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

  // Cached anonId so we don't hit Firestore on every launch
  static Future<void> setCachedAnonId(String anonId) async {
    await userBox.put('cached_anon_id', anonId);
  }

  static String? getCachedAnonId() {
    final value = userBox.get('cached_anon_id');
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static Future<void> clearUserData() async {
    await userBox.clear();
  }

  static Future<void> clearAllData() async {
    await appBox.clear();
    await userBox.clear();
  }
}
