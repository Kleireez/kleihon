import 'package:kleihon/features/reader/reader_settings.dart';
import 'package:kleihon/features/reader/reader_settings_store.dart';
import 'package:kleihon/features/reader/screen_awake.dart';

/// HANYA UNTUK TEST: mencatat permintaan layar menyala.
class FakeScreenAwake implements ScreenAwake {
  final List<bool> calls = [];

  @override
  Future<void> set(bool enabled) async => calls.add(enabled);
}

/// HANYA UNTUK TEST: penyimpanan pengaturan di memori.
class InMemoryReaderSettingsStore implements ReaderSettingsStore {
  InMemoryReaderSettingsStore([this.value = ReaderSettings.defaults]);

  ReaderSettings value;

  /// Semua pemanggilan save, berurutan.
  final List<ReaderSettings> saved = [];

  @override
  Future<ReaderSettings> load() async => value;

  @override
  Future<void> save(ReaderSettings settings) async {
    value = settings;
    saved.add(settings);
  }
}
