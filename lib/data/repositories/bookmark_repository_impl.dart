import 'package:drift/drift.dart'
    show InsertMode, SimpleSelectStatement, Value, innerJoin, leftOuterJoin;

import '../../domain/entities/bookmark.dart';
import '../../domain/entities/entity_id.dart';
import '../../domain/entities/reading_status.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../database/app_database.dart' as db;
import 'comic_row_mapper.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  BookmarkRepositoryImpl(this._db, this._resolveCover);

  final db.AppDatabase _db;
  final CoverResolver _resolveCover;

  @override
  Future<Bookmark?> getBookmark({
    required String sourceId,
    required String comicRemoteId,
  }) async {
    final row = await _bookmarkQuery(sourceId, comicRemoteId).getSingleOrNull();
    return row == null ? null : _toBookmark(sourceId, row);
  }

  @override
  Stream<Bookmark?> watchBookmark({
    required String sourceId,
    required String comicRemoteId,
  }) {
    return _bookmarkQuery(sourceId, comicRemoteId).watchSingleOrNull().map(
      (row) => row == null ? null : _toBookmark(sourceId, row),
    );
  }

  @override
  Future<void> addBookmark({
    required String sourceId,
    required String comicRemoteId,
    ReadingStatus status = ReadingStatus.unread,
  }) async {
    // insertOrIgnore: bookmark yang sudah ada dibiarkan apa adanya. Komik
    // yang tidak ada tetap ditolak oleh relasi database.
    await _db
        .into(_db.bookmarks)
        .insert(
          db.BookmarksCompanion.insert(
            comicId: makeEntityId(sourceId, comicRemoteId),
            readingStatus: Value(status),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<void> removeBookmark({
    required String sourceId,
    required String comicRemoteId,
  }) async {
    final comicId = makeEntityId(sourceId, comicRemoteId);
    await (_db.delete(
      _db.bookmarks,
    )..where((t) => t.comicId.equals(comicId))).go();
  }

  @override
  Future<bool> setReadingStatus({
    required String sourceId,
    required String comicRemoteId,
    required ReadingStatus status,
  }) async {
    final comicId = makeEntityId(sourceId, comicRemoteId);
    final updated =
        await (_db.update(_db.bookmarks)
              ..where((t) => t.comicId.equals(comicId)))
            .write(db.BookmarksCompanion(readingStatus: Value(status)));
    return updated > 0;
  }

  @override
  Future<bool> setFollowUpdates({
    required String sourceId,
    required String comicRemoteId,
    required bool follow,
  }) async {
    final comicId = makeEntityId(sourceId, comicRemoteId);
    final updated =
        await (_db.update(_db.bookmarks)
              ..where((t) => t.comicId.equals(comicId)))
            .write(db.BookmarksCompanion(followUpdates: Value(follow)));
    return updated > 0;
  }

  @override
  Stream<List<LibraryEntry>> watchLibrary() {
    final query = _db.select(_db.bookmarks).join([
      innerJoin(_db.comics, _db.comics.id.equalsExp(_db.bookmarks.comicId)),
      leftOuterJoin(
        _db.readingHistoryEntries,
        _db.readingHistoryEntries.comicId.equalsExp(_db.bookmarks.comicId),
      ),
      leftOuterJoin(
        _db.chapters,
        _db.chapters.id.equalsExp(_db.readingHistoryEntries.chapterId),
      ),
    ]);

    return query.watch().asyncMap((rows) async {
      final entries = <LibraryEntry>[];
      for (final row in rows) {
        final bookmark = row.readTable(_db.bookmarks);
        final comicRow = row.readTable(_db.comics);
        final history = row.readTableOrNull(_db.readingHistoryEntries);
        final chapter = row.readTableOrNull(_db.chapters);

        entries.add(
          LibraryEntry(
            comic: await comicFromRow(comicRow, _resolveCover),
            bookmark: _toBookmark(comicRow.sourceId, bookmark),
            lastRead: history == null
                ? null
                : LastRead(
                    chapterRemoteId: remoteIdFromEntityId(
                      comicRow.sourceId,
                      history.chapterId,
                    ),
                    readAt: history.lastReadAt,
                    chapterTitle: chapter?.title,
                  ),
          ),
        );
      }
      return entries;
    });
  }

  SimpleSelectStatement<db.$BookmarksTable, db.Bookmark> _bookmarkQuery(
    String sourceId,
    String comicRemoteId,
  ) {
    final comicId = makeEntityId(sourceId, comicRemoteId);
    return _db.select(_db.bookmarks)..where((t) => t.comicId.equals(comicId));
  }

  Bookmark _toBookmark(String sourceId, db.Bookmark row) {
    return Bookmark(
      sourceId: sourceId,
      comicRemoteId: remoteIdFromEntityId(sourceId, row.comicId),
      status: row.readingStatus,
      followUpdates: row.followUpdates,
      createdAt: row.createdAt,
    );
  }
}
