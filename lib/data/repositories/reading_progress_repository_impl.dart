import 'dart:convert';

import 'package:drift/drift.dart'
    show BooleanExpressionOperators, DoUpdate, Value;

import '../../domain/entities/entity_id.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/reading_progress_repository.dart';
import '../database/app_database.dart';

class ReadingProgressRepositoryImpl implements ReadingProgressRepository {
  ReadingProgressRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<ReadingProgress?> getProgress({
    required String sourceId,
    required String comicRemoteId,
    required String chapterRemoteId,
  }) async {
    final comicId = makeEntityId(sourceId, comicRemoteId);
    final chapterId = makeEntityId(sourceId, chapterRemoteId);
    final row =
        await (_db.select(_db.readingProgressEntries)..where(
              (t) => t.comicId.equals(comicId) & t.chapterId.equals(chapterId),
            ))
            .getSingleOrNull();
    return row == null ? null : _toEntity(sourceId, row);
  }

  @override
  Future<void> saveProgress(ReadingProgress progress) async {
    final comicId = makeEntityId(progress.sourceId, progress.comicRemoteId);
    final chapterId = makeEntityId(progress.sourceId, progress.chapterRemoteId);
    final pageIndex = progress.pageIndex < 0 ? 0 : progress.pageIndex;
    final progressTable = _db.readingProgressEntries;
    final historyTable = _db.readingHistoryEntries;

    await _db.transaction(() async {
      final values = ReadingProgressEntriesCompanion(
        pageIndex: Value(pageIndex),
        scrollPosition: Value(progress.scrollOffset),
        updatedAt: Value(progress.updatedAt),
        pageCount: Value(progress.pageCount),
        aspectsJson: Value(jsonEncode(progress.aspects)),
      );
      await _db
          .into(progressTable)
          .insert(
            ReadingProgressEntriesCompanion.insert(
              comicId: comicId,
              chapterId: chapterId,
              pageIndex: values.pageIndex,
              scrollPosition: values.scrollPosition,
              updatedAt: values.updatedAt,
              pageCount: values.pageCount,
              aspectsJson: values.aspectsJson,
            ),
            onConflict: DoUpdate(
              (old) => values,
              target: [progressTable.comicId, progressTable.chapterId],
            ),
          );

      await _db
          .into(historyTable)
          .insert(
            ReadingHistoryEntriesCompanion.insert(
              comicId: comicId,
              chapterId: chapterId,
              lastReadAt: Value(progress.updatedAt),
            ),
            onConflict: DoUpdate(
              (old) => ReadingHistoryEntriesCompanion(
                chapterId: Value(chapterId),
                lastReadAt: Value(progress.updatedAt),
              ),
              target: [historyTable.comicId],
            ),
          );
    });
  }

  @override
  Stream<Map<String, ReadingProgress>> watchComicProgress({
    required String sourceId,
    required String comicRemoteId,
  }) {
    final comicId = makeEntityId(sourceId, comicRemoteId);
    final query = _db.select(_db.readingProgressEntries)
      ..where((t) => t.comicId.equals(comicId));

    return query.watch().map(
      (rows) => {
        for (final row in rows)
          remoteIdFromEntityId(sourceId, row.chapterId): _toEntity(
            sourceId,
            row,
          ),
      },
    );
  }

  ReadingProgress _toEntity(String sourceId, ReadingProgressEntry row) {
    return ReadingProgress(
      sourceId: sourceId,
      comicRemoteId: remoteIdFromEntityId(sourceId, row.comicId),
      chapterRemoteId: remoteIdFromEntityId(sourceId, row.chapterId),
      pageIndex: row.pageIndex,
      pageCount: row.pageCount,
      scrollOffset: row.scrollPosition,
      aspects: _decodeAspects(row.aspectsJson),
      updatedAt: row.updatedAt,
    );
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
