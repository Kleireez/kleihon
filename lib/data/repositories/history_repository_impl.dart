import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/entity_id.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/history_repository.dart';
import '../database/app_database.dart' as db;
import 'comic_row_mapper.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._db, this._resolveCover);

  final db.AppDatabase _db;
  final CoverResolver _resolveCover;

  @override
  Stream<List<HistoryEntry>> watchHistory() {
    final history = _db.readingHistoryEntries;
    final progress = _db.readingProgressEntries;

    final query = _db.select(history).join([
      innerJoin(_db.comics, _db.comics.id.equalsExp(history.comicId)),
      leftOuterJoin(_db.chapters, _db.chapters.id.equalsExp(history.chapterId)),
      leftOuterJoin(
        progress,
        progress.comicId.equalsExp(history.comicId) &
            progress.chapterId.equalsExp(history.chapterId),
      ),
    ])..orderBy([OrderingTerm.desc(history.lastReadAt)]);

    return query.watch().asyncMap((rows) async {
      final entries = <HistoryEntry>[];
      for (final row in rows) {
        final historyRow = row.readTable(history);
        final comicRow = row.readTable(_db.comics);
        final chapterRow = row.readTableOrNull(_db.chapters);
        final progressRow = row.readTableOrNull(progress);

        entries.add(
          HistoryEntry(
            comic: await comicFromRow(comicRow, _resolveCover),
            chapterRemoteId: remoteIdFromEntityId(
              comicRow.sourceId,
              historyRow.chapterId,
            ),
            chapterTitle: chapterRow?.title,
            readAt: historyRow.lastReadAt,
            pageIndex: progressRow?.pageIndex ?? 0,
            pageCount: progressRow?.pageCount ?? 0,
          ),
        );
      }
      return entries;
    });
  }

  @override
  Future<HistoryRestorePoint?> removeComic({
    required String sourceId,
    required String comicRemoteId,
  }) {
    final comicId = makeEntityId(sourceId, comicRemoteId);
    final history = _db.readingHistoryEntries;
    final progress = _db.readingProgressEntries;

    return _db.transaction(() async {
      final historyRow = await (_db.select(
        history,
      )..where((t) => t.comicId.equals(comicId))).getSingleOrNull();
      final progressRows = await (_db.select(
        progress,
      )..where((t) => t.comicId.equals(comicId))).get();

      if (historyRow == null && progressRows.isEmpty) return null;

      await (_db.delete(history)..where((t) => t.comicId.equals(comicId))).go();
      await (_db.delete(
        progress,
      )..where((t) => t.comicId.equals(comicId))).go();

      return HistoryRestorePoint(
        sourceId: sourceId,
        comicRemoteId: comicRemoteId,
        lastChapterRemoteId: historyRow == null
            ? null
            : remoteIdFromEntityId(sourceId, historyRow.chapterId),
        lastReadAt: historyRow?.lastReadAt,
        progress: [
          for (final row in progressRows)
            ReadingProgress(
              sourceId: sourceId,
              comicRemoteId: comicRemoteId,
              chapterRemoteId: remoteIdFromEntityId(sourceId, row.chapterId),
              pageIndex: row.pageIndex,
              pageCount: row.pageCount,
              scrollOffset: row.scrollPosition,
              aspects: _decodeAspects(row.aspectsJson),
              updatedAt: row.updatedAt,
            ),
        ],
      );
    });
  }

  @override
  Future<void> restore(HistoryRestorePoint point) {
    final comicId = makeEntityId(point.sourceId, point.comicRemoteId);
    final chapter = point.lastChapterRemoteId;
    final readAt = point.lastReadAt;

    // insertOrIgnore: data yang lebih baru tidak ditimpa. Komik yang sudah
    // tidak ada tetap ditolak oleh relasi database.
    return _db.transaction(() async {
      if (chapter != null && readAt != null) {
        await _db
            .into(_db.readingHistoryEntries)
            .insert(
              db.ReadingHistoryEntriesCompanion.insert(
                comicId: comicId,
                chapterId: makeEntityId(point.sourceId, chapter),
                lastReadAt: Value(readAt),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      for (final item in point.progress) {
        await _db
            .into(_db.readingProgressEntries)
            .insert(
              db.ReadingProgressEntriesCompanion.insert(
                comicId: comicId,
                chapterId: makeEntityId(point.sourceId, item.chapterRemoteId),
                pageIndex: Value(item.pageIndex),
                scrollPosition: Value(item.scrollOffset),
                updatedAt: Value(item.updatedAt),
                pageCount: Value(item.pageCount),
                aspectsJson: Value(jsonEncode(item.aspects)),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  @override
  Future<void> clearAll() {
    return _db.transaction(() async {
      await _db.delete(_db.readingHistoryEntries).go();
      await _db.delete(_db.readingProgressEntries).go();
    });
  }

  List<double?> _decodeAspects(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return [
          for (final item in decoded) item is num ? item.toDouble() : null,
        ];
      }
    } catch (_) {
      // Data rusak diperlakukan sebagai belum ada.
    }
    return const [];
  }
}
