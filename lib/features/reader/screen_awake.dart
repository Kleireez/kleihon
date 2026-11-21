import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/utils/app_logger.dart';

/// Menjaga layar tetap menyala. Dipisah supaya bisa diganti saat test.
abstract class ScreenAwake {
  Future<void> set(bool enabled);
}

class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> set(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (e, stack) {
      // Fitur pelengkap: kegagalan tidak boleh mengganggu pembacaan.
      appLogger.w(
        'Gagal mengatur layar tetap menyala',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

final readerScreenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const WakelockScreenAwake(),
);
