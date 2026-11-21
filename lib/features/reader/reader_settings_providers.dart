import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import 'reader_settings.dart';
import 'reader_settings_store.dart';

final readerSettingsStoreProvider = Provider<ReaderSettingsStore>(
  (ref) => PrefsReaderSettingsStore(),
);

class ReaderSettingsController extends AsyncNotifier<ReaderSettings> {
  @override
  Future<ReaderSettings> build() async {
    try {
      return await ref.read(readerSettingsStoreProvider).load();
    } catch (e, stack) {
      appLogger.w(
        'Gagal memuat pengaturan reader',
        error: e,
        stackTrace: stack,
      );
      return ReaderSettings.defaults;
    }
  }

  /// Menerapkan pengaturan langsung, lalu menyimpannya. Kegagalan menyimpan
  /// tidak membatalkan pengaturan yang sedang dipakai.
  Future<void> apply(ReaderSettings next) async {
    // Pastikan pemuatan awal selesai agar tidak menimpa pilihan ini.
    await future;
    state = AsyncData(next);
    try {
      await ref.read(readerSettingsStoreProvider).save(next);
    } catch (e, stack) {
      appLogger.w(
        'Gagal menyimpan pengaturan reader',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

final readerSettingsProvider =
    AsyncNotifierProvider<ReaderSettingsController, ReaderSettings>(
      ReaderSettingsController.new,
    );
