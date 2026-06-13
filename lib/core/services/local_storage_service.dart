import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _appBoxName = 'fess_app_data';
  static const String _userBoxName = 'fess_user_data';

  // World mood keys
  static const String _kWorldMoodKey = 'world_mood';
  static const String _kWorldMoodDateKey = 'world_mood_date';

  static Box? _appBox;
  static Box? _userBox;

  // ── Initialization ──────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _appBox = await Hive.openBox(_appBoxName);
    _userBox = await Hive.openBox(_userBoxName);
  }

  // ── Box accessors ───────────────────────────────────────────────────────────

  static Box get appBox {
    if (_appBox == null || !_appBox!.isOpen) {
      throw Exception('App box not initialized. Call LocalStorageService.initialize() first.');
    }
    return _appBox!;
  }

  static Box get userBox {
    if (_userBox == null || !_userBox!.isOpen) {
      throw Exception('User box not initialized. Call LocalStorageService.initialize() first.');
    }
    return _userBox!;
  }

  // ── Onboarding ──────────────────────────────────────────────────────────────

  static Future<void> setHasSeenOnboarding(bool value) async {
    await appBox.put('has_seen_onboarding', value);
  }

  static bool getHasSeenOnboarding() {
    return appBox.get('has_seen_onboarding', defaultValue: false) as bool;
  }

  // ── Cached anonId ───────────────────────────────────────────────────────────
  // Avoids hitting Firestore on every launch.

  static Future<void> setCachedAnonId(String anonId) async {
    await userBox.put('cached_anon_id', anonId);
  }

  static String? getCachedAnonId() {
    final value = userBox.get('cached_anon_id');
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  // ── World chat mood (per-day) ───────────────────────────────────────────────
  // Mood is stored with today's date string so it auto-expires the next day.

  /// Returns the mood the user picked today, or null if not yet picked today.
  static String? getTodayMood() {
    final storedDate = userBox.get(_kWorldMoodDateKey) as String?;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (storedDate != todayStr) return null;
    return userBox.get(_kWorldMoodKey) as String?;
  }

  /// Saves the mood for today. Overwrites any previously saved mood for today.
  static Future<void> saveTodayMood(String mood) async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await userBox.put(_kWorldMoodDateKey, todayStr);
    await userBox.put(_kWorldMoodKey, mood);
  }

  // ── Clear ───────────────────────────────────────────────────────────────────

  /// Clears only user-specific data (called on sign out).
  static Future<void> clearUserData() async {
    await userBox.clear();
  }

  /// Clears everything — app settings + user data.
  static Future<void> clearAllData() async {
    await appBox.clear();
    await userBox.clear();
  }
}