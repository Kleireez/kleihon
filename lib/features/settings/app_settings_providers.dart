import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import 'app_settings.dart';
import 'app_settings_store.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>(
  (ref) => PrefsAppSettingsStore(),
);

/// Nilai awal pengaturan. main() memuatnya dari penyimpanan sebelum
/// aplikasi digambar, sehingga tema tidak berkedip.
final initialAppSettingsProvider = Provider<AppSettings>(
  (ref) => AppSettings.defaults,
);

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialAppSettingsProvider);

  /// Menerapkan pengaturan langsung, lalu menyimpannya. Kegagalan menyimpan
  /// tidak membatalkan pengaturan yang sedang dipakai.
  Future<void> update(AppSettings next) async {
    state = next;
    try {
      await ref.read(appSettingsStoreProvider).save(next);
    } catch (e, stack) {
      appLogger.w(
        'Gagal menyimpan pengaturan aplikasi',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
