import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mengatur bilah sistem Android. Dipisah supaya bisa diganti saat test.
abstract class ReaderSystemUi {
  /// Dipanggil saat reader dibuka: tampilan memenuhi layar, bilah sistem
  /// terlihat. Dengan begitu menyembunyikan bilah tidak mengubah ukuran
  /// area tampilan (tidak ada isi yang melompat).
  Future<void> enterReader();

  /// Dipanggil saat reader ditutup: kembali ke mode semula.
  Future<void> leaveReader();

  Future<void> hideBars();
  Future<void> showBars();
}

class PlatformReaderSystemUi implements ReaderSystemUi {
  const PlatformReaderSystemUi();

  @override
  Future<void> enterReader() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  @override
  Future<void> leaveReader() => SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  @override
  Future<void> hideBars() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  @override
  Future<void> showBars() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

final readerSystemUiProvider = Provider<ReaderSystemUi>(
  (ref) => const PlatformReaderSystemUi(),
);

/// Apakah ketukan di tengah layar juga menampilkan atau menyembunyikan
/// bilah status dan navigasi Android (selain kontrol reader sendiri).
/// Ubah menjadi false untuk percobaan getaran.
final readerToggleSystemBarsProvider = Provider<bool>((ref) => true);
