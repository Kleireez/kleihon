import 'comic.dart';
import 'reading_progress.dart';

/// Satu baris riwayat: komik beserta bacaan terakhirnya.
class HistoryEntry {
  const HistoryEntry({
    required this.comic,
    required this.chapterRemoteId,
    required this.readAt,
    this.chapterTitle,
    this.pageIndex = 0,
    this.pageCount = 0,
  });

  final Comic comic;

  /// Chapter terakhir yang dibaca.
  final String chapterRemoteId;

  /// Null jika chapter-nya sudah tidak ada.
  final String? chapterTitle;
  final DateTime readAt;

  /// Halaman terakhir (mulai dari 0). [pageCount] 0 berarti tidak diketahui.
  final int pageIndex;
  final int pageCount;

  bool get isCompleted => pageCount > 0 && pageIndex >= pageCount - 1;
}

/// Data yang dihapus bersama riwayat sebuah komik, untuk mengurungkannya.
class HistoryRestorePoint {
  const HistoryRestorePoint({
    required this.sourceId,
    required this.comicRemoteId,
    required this.progress,
    this.lastChapterRemoteId,
    this.lastReadAt,
  });

  final String sourceId;
  final String comicRemoteId;
  final String? lastChapterRemoteId;
  final DateTime? lastReadAt;

  /// Progres semua chapter komik itu.
  final List<ReadingProgress> progress;
}
