import 'dart:async';

import 'package:kleihon/domain/entities/history.dart';
import 'package:kleihon/domain/repositories/history_repository.dart';

/// HANYA UNTUK TEST: riwayat di memori.
class FakeHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> _entries = [];
  final Map<String, HistoryEntry> _removed = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Panggilan removeComic dan clearAll, berurutan.
  final List<String> removedKeys = [];
  int clearCalls = 0;

  String _key(String sourceId, String comicId) => '$sourceId|$comicId';

  void seed(HistoryEntry entry) {
    _entries.add(entry);
    _changes.add(null);
  }

  List<HistoryEntry> _sorted() =>
      [..._entries]..sort((a, b) => b.readAt.compareTo(a.readAt));

  @override
  Stream<List<HistoryEntry>> watchHistory() async* {
    yield _sorted();
    await for (final _ in _changes.stream) {
      yield _sorted();
    }
  }

  @override
  Future<HistoryRestorePoint?> removeComic({
    required String sourceId,
    required String comicRemoteId,
  }) async {
    final key = _key(sourceId, comicRemoteId);
    final index = _entries.indexWhere(
      (e) => _key(e.comic.sourceId, e.comic.remoteId) == key,
    );
    if (index < 0) return null;

    removedKeys.add(key);
    final entry = _entries.removeAt(index);
    _removed[key] = entry;
    _changes.add(null);
    return HistoryRestorePoint(
      sourceId: sourceId,
      comicRemoteId: comicRemoteId,
      lastChapterRemoteId: entry.chapterRemoteId,
      lastReadAt: entry.readAt,
      progress: const [],
    );
  }

  @override
  Future<void> restore(HistoryRestorePoint point) async {
    final entry = _removed.remove(_key(point.sourceId, point.comicRemoteId));
    if (entry == null) return;
    _entries.add(entry);
    _changes.add(null);
  }

  @override
  Future<void> clearAll() async {
    clearCalls++;
    _entries.clear();
    _changes.add(null);
  }
}
