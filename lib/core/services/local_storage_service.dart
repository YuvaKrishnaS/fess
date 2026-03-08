import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  HiveService._();
  static final HiveService instance = HiveService._();

  static const String _prefsBox = 'prefs';
  static const String _cacheBox = 'cache';

  late Box _preferencesBox;
  late Box _cacheBox;

  Future<void> initialized() async {
    await Hive.initFlutter();

    _preferencesBox = await Hive.openBox(_prefsBox);
    _cacheBox = await Hive.openBox(_cacheBox);
  }

  Box get prefs => _preferencesBox;
  Box get cache => _cacheBox;

  Future<void> setString(String key, String value) async {
    await _preferencesBox.put(key, value);
  }

  String? getString(String key) {
    return _preferencesBox.get(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _preferencesBox.put(key, value);
  }

  bool? getBool(String key) {
    return _preferencesBox.get(key);
  }

  Future<void> remove(String key) async {
    await _preferencesBox.delete(key);
  }

  Future<void> clearAll() async {
    await _preferencesBox.clear();
    await _cacheBox.clear();
  }
}