import 'package:kleihon/features/settings/app_settings.dart';
import 'package:kleihon/features/settings/app_settings_store.dart';

/// HANYA UNTUK TEST: penyimpanan pengaturan aplikasi di memori.
class InMemoryAppSettingsStore implements AppSettingsStore {
  InMemoryAppSettingsStore([this.value = AppSettings.defaults]);

  AppSettings value;

  /// Semua pemanggilan save, berurutan.
  final List<AppSettings> saved = [];

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
    saved.add(settings);
  }
}
