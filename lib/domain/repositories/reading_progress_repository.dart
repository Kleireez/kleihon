import '../entities/reading_progress.dart';

abstract class ReadingProgressRepository {
  Future<ReadingProgress?> getProgress({
    required String sourceId,
    required String comicRemoteId,
    required String chapterRemoteId,
  });

  /// Menyimpan (atau memperbarui) progres chapter dan riwayat komiknya.
  Future<void> saveProgress(ReadingProgress progress);

  /// Progres semua chapter sebuah komik, dengan kunci chapterRemoteId.
  /// Memancarkan nilai baru setiap ada perubahan.
  Stream<Map<String, ReadingProgress>> watchComicProgress({
    required String sourceId,
    required String comicRemoteId,
  });
}
