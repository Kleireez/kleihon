import 'package:drift/drift.dart';

import 'enums.dart';

/// Metadata komik. Id berformat `sourceId:remoteId`.
class Comics extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text()();
  TextColumn get remoteId => text()();
  TextColumn get title => text()();
  TextColumn get alternativeTitlesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get synopsis => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get type => text().nullable()();
  TextColumn get genresJson => text().withDefault(const Constant('[]'))();
  RealColumn get rating => real().nullable()();

  /// URL asli di sumber, supaya data bisa diperbarui lagi.
  TextColumn get sourceUrl => text()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Chapter dihapus otomatis kalau komiknya dihapus dari cache.
class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get comicId =>
      text().references(Comics, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  RealColumn get chapterNumber => real().nullable()();

  /// URL asli chapter di sumber.
  TextColumn get chapterUrl => text()();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get comicId => text().unique().references(Comics, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get readingStatus => intEnum<ReadingStatus>().withDefault(
    Constant(ReadingStatus.unread.index),
  )();

  /// Untuk kategori "Diikuti untuk update".
  BoolColumn get followUpdates =>
      boolean().withDefault(const Constant(false))();
}

/// Satu baris per pasangan komik + chapter.
class ReadingProgressEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get comicId => text().references(Comics, #id)();
  TextColumn get chapterId => text()();
  IntColumn get pageIndex => integer().withDefault(const Constant(0))();
  RealColumn get scrollPosition => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {comicId, chapterId},
  ];
}

/// Satu baris per komik: chapter terakhir yang dibaca.
class ReadingHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get comicId => text().unique().references(Comics, #id)();
  TextColumn get chapterId => text()();
  DateTimeColumn get lastReadAt => dateTime().withDefault(currentDateAndTime)();
}

class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get comicId => text().references(Comics, #id)();
  TextColumn get chapterId => text().unique()();
  TextColumn get localPath => text()();
  IntColumn get downloadStatus => intEnum<DownloadStatus>().withDefault(
    Constant(DownloadStatus.queued.index),
  )();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
}

class SearchHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text().unique()();
  DateTimeColumn get searchedAt => dateTime().withDefault(currentDateAndTime)();
}
