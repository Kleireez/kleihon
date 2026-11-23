import 'comic.dart';
import 'reading_status.dart';

class Bookmark {
  const Bookmark({
    required this.sourceId,
    required this.comicRemoteId,
    required this.status,
    required this.followUpdates,
    required this.createdAt,
  });

  final String sourceId;
  final String comicRemoteId;
  final ReadingStatus status;

  /// Untuk kategori "Diikuti untuk update".
  final bool followUpdates;
  final DateTime createdAt;
}

/// Chapter terakhir yang dibaca pada sebuah komik.
class LastRead {
  const LastRead({
    required this.chapterRemoteId,
    required this.readAt,
    this.chapterTitle,
  });

  final String chapterRemoteId;
  final DateTime readAt;

  /// Null jika chapter-nya sudah tidak ada.
  final String? chapterTitle;
}

/// Satu baris di Library: komik, bookmark-nya, dan bacaan terakhirnya.
class LibraryEntry {
  const LibraryEntry({
    required this.comic,
    required this.bookmark,
    this.lastRead,
  });

  final Comic comic;
  final Bookmark bookmark;
  final LastRead? lastRead;

  /// Waktu aktivitas terakhir: terakhir dibaca, atau saat bookmark dibuat.
  DateTime get activityAt => lastRead?.readAt ?? bookmark.createdAt;
}
