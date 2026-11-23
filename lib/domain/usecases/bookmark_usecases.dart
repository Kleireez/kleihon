import '../entities/reading_status.dart';
import '../repositories/bookmark_repository.dart';

/// Menambah bookmark jika belum ada, menghapusnya jika sudah ada.
class ToggleBookmark {
  const ToggleBookmark(this._repository);

  final BookmarkRepository _repository;

  /// Mengembalikan true jika komik sekarang di-bookmark.
  Future<bool> call({
    required String sourceId,
    required String comicRemoteId,
  }) async {
    final existing = await _repository.getBookmark(
      sourceId: sourceId,
      comicRemoteId: comicRemoteId,
    );
    if (existing != null) {
      await _repository.removeBookmark(
        sourceId: sourceId,
        comicRemoteId: comicRemoteId,
      );
      return false;
    }
    await _repository.addBookmark(
      sourceId: sourceId,
      comicRemoteId: comicRemoteId,
    );
    return true;
  }
}

/// Status baru setelah progres baca disimpan, atau null jika tidak berubah.
///
/// - [chapterJustCompleted] dan [isLastChapter]: chapter terakhir baru saja
///   selesai, status menjadi selesai.
/// - [firstProgressForChapter]: chapter ini baru mulai dibaca. Belum dibaca
///   atau selesai (misalnya ada chapter baru) menjadi sedang dibaca.
///
/// Hanya bereaksi pada dua peristiwa itu, sehingga status yang diubah manual
/// tidak ditimpa oleh penyimpanan progres biasa di chapter yang sama.
ReadingStatus? autoStatusAfterProgress({
  required ReadingStatus current,
  required bool firstProgressForChapter,
  required bool chapterJustCompleted,
  required bool isLastChapter,
}) {
  if (chapterJustCompleted && isLastChapter) {
    return current == ReadingStatus.completed ? null : ReadingStatus.completed;
  }
  if (firstProgressForChapter && current != ReadingStatus.reading) {
    return ReadingStatus.reading;
  }
  return null;
}
