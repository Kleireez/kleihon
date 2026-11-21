import 'dart:async';

import 'package:kleihon/domain/entities/reading_progress.dart';
import 'package:kleihon/domain/repositories/reading_progress_repository.dart';

/// HANYA UNTUK TEST: penyimpanan progres di memori.
class FakeReadingProgressRepository implements ReadingProgressRepository {
  final Map<String, ReadingProgress> _store = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Riwayat semua pemanggilan saveProgress, berurutan.
  final List<ReadingProgress> saved = [];

  String _key(String sourceId, String comicId, String chapterId) =>
      '$sourceId|$comicId|$chapterId';

  /// Mengisi data awal tanpa dicatat sebagai penyimpanan.
  void seed(ReadingProgress progress) {
    _store[_key(
          progress.sourceId,
          progress.comicRemoteId,
          progress.chapterRemoteId,
        )] =
        progress;
    _changes.add(null);
  }

  Map<String, ReadingProgress> _forComic(String sourceId, String comicId) => {
    for (final entry in _store.values)
      if (entry.sourceId == sourceId && entry.comicRemoteId == comicId)
        entry.chapterRemoteId: entry,
  };

  @override
  Future<ReadingProgress?> getProgress({
    required String sourceId,
    required String comicRemoteId,
    required String chapterRemoteId,
  }) async => _store[_key(sourceId, comicRemoteId, chapterRemoteId)];

  @override
  Future<void> saveProgress(ReadingProgress progress) async {
    saved.add(progress);
    seed(progress);
  }

  @override
  Stream<Map<String, ReadingProgress>> watchComicProgress({
    required String sourceId,
    required String comicRemoteId,
  }) async* {
    yield _forComic(sourceId, comicRemoteId);
    await for (final _ in _changes.stream) {
      yield _forComic(sourceId, comicRemoteId);
    }
  }
}
