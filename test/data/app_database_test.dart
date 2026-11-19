import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/database/app_database.dart';
import 'package:kleihon/data/database/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertComic(String id) {
    return db.into(db.comics).insert(
          ComicsCompanion.insert(
            id: id,
            sourceId: 'test',
            remoteId: id,
            title: 'Judul $id',
            sourceUrl: 'https://example.invalid/$id',
          ),
        );
  }

  test('komik dan chapter tersimpan dan terbaca kembali', () async {
    await insertComic('c1');
    await db.into(db.chapters).insert(
          ChaptersCompanion.insert(
            id: 'ch1',
            comicId: 'c1',
            title: 'Chapter 1',
            chapterUrl: 'https://example.invalid/c1/ch1',
          ),
        );

    final comics = await db.select(db.comics).get();
    final chapters = await db.select(db.chapters).get();
    expect(comics.single.title, 'Judul c1');
    expect(chapters.single.comicId, 'c1');
  });

  test('menghapus komik ikut menghapus chapter-nya', () async {
    await insertComic('c1');
    await db.into(db.chapters).insert(
          ChaptersCompanion.insert(
            id: 'ch1',
            comicId: 'c1',
            title: 'Chapter 1',
            chapterUrl: 'https://example.invalid/c1/ch1',
          ),
        );

    await db.delete(db.comics).go();
    expect(await db.select(db.chapters).get(), isEmpty);
  });

  test('bookmark untuk komik yang tidak ada ditolak', () async {
    await expectLater(
      db.into(db.bookmarks).insert(BookmarksCompanion.insert(comicId: 'nope')),
      throwsA(anything),
    );
  });

  test('komik yang punya bookmark tidak bisa dihapus dari cache', () async {
    await insertComic('c1');
    await db
        .into(db.bookmarks)
        .insert(BookmarksCompanion.insert(comicId: 'c1'));

    await expectLater(db.delete(db.comics).go(), throwsA(anything));
    expect(await db.select(db.comics).get(), hasLength(1));
  });

  test('status baca bawaan adalah unread', () async {
    await insertComic('c1');
    await db
        .into(db.bookmarks)
        .insert(BookmarksCompanion.insert(comicId: 'c1'));

    final bookmark = await db.select(db.bookmarks).getSingle();
    expect(bookmark.readingStatus, ReadingStatus.unread);
    expect(bookmark.followUpdates, isFalse);
  });

  test('status baca bisa diubah', () async {
    await insertComic('c1');
    await db
        .into(db.bookmarks)
        .insert(BookmarksCompanion.insert(comicId: 'c1'));

    await (db.update(db.bookmarks)..where((t) => t.comicId.equals('c1')))
        .write(const BookmarksCompanion(
      readingStatus: Value(ReadingStatus.reading),
    ));

    final bookmark = await db.select(db.bookmarks).getSingle();
    expect(bookmark.readingStatus, ReadingStatus.reading);
  });

  test('progres ganda untuk komik dan chapter yang sama ditolak', () async {
    await insertComic('c1');
    final entry = ReadingProgressEntriesCompanion.insert(
      comicId: 'c1',
      chapterId: 'ch1',
    );
    await db.into(db.readingProgressEntries).insert(entry);

    await expectLater(
      db.into(db.readingProgressEntries).insert(entry),
      throwsA(anything),
    );
  });

  test('riwayat pencarian tidak menyimpan kueri ganda', () async {
    await db
        .into(db.searchHistoryEntries)
        .insert(SearchHistoryEntriesCompanion.insert(query: 'solo'));

    await expectLater(
      db
          .into(db.searchHistoryEntries)
          .insert(SearchHistoryEntriesCompanion.insert(query: 'solo')),
      throwsA(anything),
    );
  });
}