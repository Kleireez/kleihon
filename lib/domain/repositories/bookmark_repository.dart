import '../entities/bookmark.dart';
import '../entities/reading_status.dart';

abstract class BookmarkRepository {
  Future<Bookmark?> getBookmark({
    required String sourceId,
    required String comicRemoteId,
  });

  /// Memancarkan nilai baru setiap bookmark komik ini berubah (null jika
  /// tidak di-bookmark).
  Stream<Bookmark?> watchBookmark({
    required String sourceId,
    required String comicRemoteId,
  });

  /// Idempoten: jika sudah di-bookmark, tidak ada yang berubah (status lama
  /// dipertahankan). Komik harus sudah ada di database.
  Future<void> addBookmark({
    required String sourceId,
    required String comicRemoteId,
    ReadingStatus status = ReadingStatus.unread,
  });

  /// Tidak melakukan apa pun jika bookmark tidak ada.
  Future<void> removeBookmark({
    required String sourceId,
    required String comicRemoteId,
  });

  /// True jika sebuah bookmark diperbarui, false jika bookmark tidak ada.
  Future<bool> setReadingStatus({
    required String sourceId,
    required String comicRemoteId,
    required ReadingStatus status,
  });

  /// True jika sebuah bookmark diperbarui, false jika bookmark tidak ada.
  Future<bool> setFollowUpdates({
    required String sourceId,
    required String comicRemoteId,
    required bool follow,
  });

  /// Semua komik yang di-bookmark, tanpa urutan tertentu. Memancarkan nilai
  /// baru setiap bookmark, komik, atau riwayat baca berubah.
  Stream<List<LibraryEntry>> watchLibrary();
}
