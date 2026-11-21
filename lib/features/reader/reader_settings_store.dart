import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'reader_settings.dart';

/// Penyimpanan pengaturan reader. Dipisah supaya bisa diganti saat test.
abstract class ReaderSettingsStore {
  Future<ReaderSettings> load();
  Future<void> save(ReaderSettings settings);
}

class PrefsReaderSettingsStore implements ReaderSettingsStore {
  PrefsReaderSettingsStore({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const String _key = 'reader_settings';

  final SharedPreferencesAsync _prefs;

  @override
  Future<ReaderSettings> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return ReaderSettings.defaults;
    try {
      return ReaderSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return ReaderSettings.defaults;
    }
  }

  @override
  Future<void> save(ReaderSettings settings) =>
      _prefs.setString(_key, jsonEncode(settings.toJson()));
}
