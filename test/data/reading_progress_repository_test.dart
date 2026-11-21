import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/database/app_database.dart';
import 'package:kleihon/data/repositories/reading_progress_repository_impl.dart';
import 'package:kleihon/domain/entities/reading_progress.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' show driftRuntimeOptions;

void main() {
  late AppDatabase db;
  late ReadingProgressRepositoryImpl repository;

  Future<void> insertComic(String remoteId) {
    return db
        .into(db.comics)
        .insert(
          ComicsCompanion.insert(
            id: 's:$remoteId',
            sourceId: 's',
            remoteId: remoteId,
            title: 'Judul $remoteId',
            sourceUrl: 'https://example.invalid/$remoteId',
          ),
        );
  }

  ReadingProgress progress({
    String comic = 'k',
    String chapter = 'c1',
    int page = 2,
    int count = 10,
    double offset = 1.5,
    List<double?> aspects = const [1.0, null, 3.5],
    int minute = 0,
  }) => ReadingProgress(
    sourceId: 's',
    comicRemoteId: comic,
    chapterRemoteId: chapter,
    pageIndex: page,
    pageCount: count,
    scrollOffset: offset,
    aspects: aspects,
    updatedAt: DateTime(2026, 11, 21, 10, minute),
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ReadingProgressRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('progres tersimpan dan terbaca kembali utuh', () async {
    await insertComic('k');
    await repository.saveProgress(progress());

    final loaded = await repository.getProgress(
      sourceId: 's',
      comicRemoteId: 'k',
      chapterRemoteId: 'c1',
    );

    expect(loaded, isNotNull);
    expect(loaded!.pageIndex, 2);
    expect(loaded.pageCount, 10);
    expect(loaded.scrollOffset, 1.5);
    expect(loaded.aspects, [1.0, null, 3.5]);
    expect(loaded.updatedAt, DateTime(2026, 11, 21, 10, 0));
    expect(loaded.comicRemoteId, 'k');
    expect(loaded.chapterRemoteId, 'c1');
  });

  test('chapter tanpa progres menghasilkan null', () async {
    await insertComic('k');

    expect(
      await repository.getProgress(
        sourceId: 's',
        comicRemoteId: 'k',
        chapterRemoteId: 'c1',
      ),
      isNull,
    );
  });

  test('menyimpan lagi memperbarui baris yang sama', () async {
    await insertComic('k');
    await repository.saveProgress(progress(page: 2));
    await repository.saveProgress(progress(page: 7, minute: 5));

    final rows = await db.select(db.readingProgressEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.pageIndex, 7);
    expect(rows.single.updatedAt, DateTime(2026, 11, 21, 10, 5));
  });

  test('riwayat satu baris per komik menunjuk chapter terakhir', () async {
    await insertComic('k');
    await repository.saveProgress(progress(chapter: 'c1', minute: 1));
    await repository.saveProgress(progress(chapter: 'c2', minute: 2));

    final history = await db.select(db.readingHistoryEntries).get();
    expect(history, hasLength(1));
    expect(history.single.chapterId, 's:c2');
    expect(history.single.lastReadAt, DateTime(2026, 11, 21, 10, 2));
  });

  test('indeks halaman negatif disimpan sebagai 0', () async {
    await insertComic('k');
    await repository.saveProgress(progress(page: -5));

    final loaded = await repository.getProgress(
      sourceId: 's',
      comicRemoteId: 'k',
      chapterRemoteId: 'c1',
    );
    expect(loaded!.pageIndex, 0);
  });

  test('menyimpan untuk komik yang tidak ada ditolak tanpa sisa', () async {
    await expectLater(repository.saveProgress(progress()), throwsA(anything));

    expect(await db.select(db.readingProgressEntries).get(), isEmpty);
    expect(await db.select(db.readingHistoryEntries).get(), isEmpty);
  });

  test(
    'watchComicProgress memancarkan perubahan dengan kunci chapter',
    () async {
      await insertComic('k');
      await insertComic('lain');

      final emissions = <Map<String, ReadingProgress>>[];
      final subscription = repository
          .watchComicProgress(sourceId: 's', comicRemoteId: 'k')
          .listen(emissions.add);
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await repository.saveProgress(progress(chapter: 'c1'));
      await pumpEventQueue();
      expect(emissions.last.keys.toList(), ['c1']);

      // Komik lain tidak ikut.
      await repository.saveProgress(progress(comic: 'lain', chapter: 'x'));
      await pumpEventQueue();
      expect(emissions.last.keys.toList(), ['c1']);

      await repository.saveProgress(progress(chapter: 'c2', page: 5));
      await pumpEventQueue();
      expect(emissions.last.keys.toSet(), {'c1', 'c2'});

      await subscription.cancel();
    },
  );

  test('migrasi dari versi 1 menambah kolom dan mempertahankan data', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('kleihon_migration_');
    final file = File(p.join(dir.path, 'lama.sqlite'));
    final old = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(
            'CREATE TABLE reading_progress_entries ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'comic_id TEXT NOT NULL, '
            'chapter_id TEXT NOT NULL, '
            'page_index INTEGER NOT NULL DEFAULT 0, '
            'scroll_position REAL NOT NULL DEFAULT 0, '
            'updated_at INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute(
            "INSERT INTO reading_progress_entries "
            "(comic_id, chapter_id, page_index, scroll_position, updated_at) "
            "VALUES ('s:c', 's:ch', 3, 1.5, 1000)",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );

    final columns = await old
        .customSelect('PRAGMA table_info(reading_progress_entries)')
        .get();
    final names = columns.map((row) => row.read<String>('name')).toList();
    expect(names, containsAll(['page_count', 'aspects_json']));

    final rows = await old
        .customSelect(
          'SELECT page_index, page_count, aspects_json '
          'FROM reading_progress_entries',
        )
        .get();
    expect(rows.single.read<int>('page_index'), 3);
    expect(rows.single.read<int>('page_count'), 0);
    expect(rows.single.read<String>('aspects_json'), '[]');

    await old.close();
    await dir.delete(recursive: true);
  });
}
