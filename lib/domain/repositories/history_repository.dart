import '../entities/history.dart';

abstract class HistoryRepository {
  /// Riwayat semua komik, terbaru dibaca dulu. Memancarkan nilai baru setiap
  /// riwayat, progres, atau data komik berubah.
  Stream<List<HistoryEntry>> watchHistory();

  /// Menghapus riwayat dan progres baca sebuah komik. Bookmark tidak
  /// tersentuh. Mengembalikan null jika tidak ada yang dihapus.
  Future<HistoryRestorePoint?> removeComic({
    required String sourceId,
    required String comicRemoteId,
  });

  /// Mengembalikan data dari [removeComic]. Data yang lebih baru tidak
  /// ditimpa.
  Future<void> restore(HistoryRestorePoint point);

  /// Menghapus seluruh riwayat dan progres baca.
  Future<void> clearAll();
}
