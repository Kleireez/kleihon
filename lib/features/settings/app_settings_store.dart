import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Penyimpanan pengaturan aplikasi. Dipisah supaya bisa diganti saat test.
abstract class AppSettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class PrefsAppSettingsStore implements AppSettingsStore {
  PrefsAppSettingsStore({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const String _key = 'app_settings';

  final SharedPreferencesAsync _prefs;

  @override
  Future<AppSettings> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return AppSettings.defaults;
    try {
      return AppSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  @override
  Future<void> save(AppSettings settings) =>
      _prefs.setString(_key, jsonEncode(settings.toJson()));
}
