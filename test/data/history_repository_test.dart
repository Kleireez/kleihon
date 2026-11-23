import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/database/app_database.dart' as db;
import 'package:kleihon/data/repositories/history_repository_impl.dart';
import 'package:kleihon/data/repositories/reading_progress_repository_impl.dart';
import 'package:kleihon/domain/entities/history.dart';
import 'package:kleihon/domain/entities/reading_progress.dart';
import 'package:drift/drift.dart' show Value;

void main() {
  late db.AppDatabase database;
  late HistoryRepositoryImpl history;
  late ReadingProgressRepositoryImpl progress;

  Future<void> insertComic(String remoteId, {String? cover}) {
    return database
        .into(database.comics)
        .insert(
          db.ComicsCompanion.insert(
            id: 's:$remoteId',
            sourceId: 's',
            remoteId: remoteId,
            title: 'Judul $remoteId',
            sourceUrl: 'https://example.invalid/$remoteId',
            coverUrl: cover == null ? const Value.absent() : Value(cover),
          ),
        );
  }

  Future<void> insertChapter(String comic, String chapter, String title) {
    return database
        .into(database.chapters)
        .insert(
          db.ChaptersCompanion.insert(
            id: 's:$chapter',
            comicId: 's:$comic',
            title: title,
            chapterUrl: 'x',
          ),
        );
  }

  Future<void> read(
    String comic,
    String chapter, {
    required int page,
    int count = 10,
    required int hour,
  }) {
    return progress.saveProgress(
      ReadingProgress(
        sourceId: 's',
        comicRemoteId: comic,
        chapterRemoteId: chapter,
        pageIndex: page,
        pageCount: count,
        scrollOffset: 1,
        aspects: const [1.0],
        updatedAt: DateTime(2026, 11, 21, hour),
      ),
    );
  }

  Future<List<HistoryEntry>> current() => history.watchHistory().first;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    history = HistoryRepositoryImpl(
      database,
      (sourceId, stored) async => stored == null ? null : 'resolved:$stored',
    );
    progress = ReadingProgressRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('riwayat berurutan terbaru dulu dengan chapter dan halaman', () async {
    await insertComic('k1', cover: 'a/cover.jpg');
    await insertComic('k2');
    await insertChapter('k1', 'c1', 'Chapter 1');
    await insertChapter('k2', 'c7', 'Chapter 7');
    await read('k1', 'c1', page: 3, hour: 10);
    await read('k2', 'c7', page: 9, hour: 11);

    final entries = await current();

    expect(entries.map((e) => e.comic.remoteId).toList(), ['k2', 'k1']);

    final first = entries[1];
    expect(first.chapterRemoteId, 'c1');
    expect(first.chapterTitle, 'Chapter 1');
    expect(first.pageIndex, 3);
    expect(first.pageCount, 10);
    expect(first.isCompleted, isFalse);
    expect(first.comic.coverUrl, 'resolved:a/cover.jpg');
    expect(first.readAt, DateTime(2026, 11, 21, 10));

    expect(entries[0].isCompleted, isTrue);
  });

  test('komik tanpa riwayat tidak muncul', () async {
    await insertComic('k1');

    expect(await current(), isEmpty);
  });

  test(
    'hapus riwayat satu komik tidak menyentuh komik lain dan bookmark',
    () async {
      await insertComic('k1');
      await insertComic('k2');
      await insertChapter('k1', 'c1', 'Chapter 1');
      await insertChapter('k2', 'c2', 'Chapter 2');
      await read('k1', 'c1', page: 3, hour: 10);
      await read('k2', 'c2', page: 4, hour: 11);
      await database
          .into(database.bookmarks)
          .insert(db.BookmarksCompanion.insert(comicId: 's:k1'));

      final point = await history.removeComic(
        sourceId: 's',
        comicRemoteId: 'k1',
      );

      expect(point, isNotNull);
      expect(point!.lastChapterRemoteId, 'c1');
      expect(point.progress.single.pageIndex, 3);
      expect((await current()).map((e) => e.comic.remoteId).toList(), ['k2']);
      final progressRows = await database
          .select(database.readingProgressEntries)
          .get();
      expect(progressRows.map((r) => r.comicId).toList(), ['s:k2']);
      expect(await database.select(database.bookmarks).get(), hasLength(1));
      expect(await database.select(database.comics).get(), hasLength(2));
    },
  );

  test('hapus komik tanpa riwayat mengembalikan null', () async {
    await insertComic('k1');

    expect(
      await history.removeComic(sourceId: 's', comicRemoteId: 'k1'),
      isNull,
    );
  });

  test('urungkan memulihkan riwayat dan progres', () async {
    await insertComic('k1');
    await insertChapter('k1', 'c1', 'Chapter 1');
    await read('k1', 'c1', page: 3, hour: 10);
    final point = (await history.removeComic(
      sourceId: 's',
      comicRemoteId: 'k1',
    ))!;
    expect(await current(), isEmpty);

    await history.restore(point);

    final entries = await current();
    expect(entries, hasLength(1));
    expect(entries.single.pageIndex, 3);
    expect(entries.single.pageCount, 10);
    expect(entries.single.readAt, DateTime(2026, 11, 21, 10));
    final restored = await progress.getProgress(
      sourceId: 's',
      comicRemoteId: 'k1',
      chapterRemoteId: 'c1',
    );
    expect(restored?.aspects, [1.0]);
    expect(restored?.scrollOffset, 1);
  });

  test('urungkan tidak menimpa data yang lebih baru', () async {
    await insertComic('k1');
    await insertChapter('k1', 'c1', 'Chapter 1');
    await read('k1', 'c1', page: 3, hour: 10);
    final point = (await history.removeComic(
      sourceId: 's',
      comicRemoteId: 'k1',
    ))!;

    // Komik dibaca lagi sebelum penghapusan diurungkan.
    await read('k1', 'c1', page: 7, hour: 12);
    await history.restore(point);

    final entries = await current();
    expect(entries, hasLength(1));
    expect(entries.single.pageIndex, 7);
    expect(entries.single.readAt, DateTime(2026, 11, 21, 12));
  });

  test(
    'hapus semua membersihkan riwayat dan progres tapi bukan bookmark',
    () async {
      await insertComic('k1');
      await insertComic('k2');
      await insertChapter('k1', 'c1', 'Chapter 1');
      await insertChapter('k2', 'c2', 'Chapter 2');
      await read('k1', 'c1', page: 3, hour: 10);
      await read('k2', 'c2', page: 4, hour: 11);
      await database
          .into(database.bookmarks)
          .insert(db.BookmarksCompanion.insert(comicId: 's:k1'));

      await history.clearAll();

      expect(await current(), isEmpty);
      expect(
        await database.select(database.readingProgressEntries).get(),
        isEmpty,
      );
      expect(await database.select(database.bookmarks).get(), hasLength(1));
      expect(await database.select(database.comics).get(), hasLength(2));
    },
  );

  test('watchHistory memancarkan perubahan', () async {
    await insertComic('k1');
    await insertChapter('k1', 'c1', 'Chapter 1');

    final emissions = <List<HistoryEntry>>[];
    final subscription = history.watchHistory().listen(emissions.add);
    await pumpEventQueue();
    expect(emissions.last, isEmpty);

    await read('k1', 'c1', page: 2, hour: 10);
    await pumpEventQueue();
    expect(emissions.last, hasLength(1));

    await history.clearAll();
    await pumpEventQueue();
    expect(emissions.last, isEmpty);

    await subscription.cancel();
  });
}
