import 'dart:io';

import 'package:kleihon/data/repositories/reading_progress_repository_impl.dart';
import 'package:kleihon/domain/entities/reading_progress.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/database/app_database.dart';
import 'package:kleihon/data/local/local_library.dart';
import 'package:kleihon/data/local/local_library_layout.dart';
import 'package:path/path.dart' as p;

import '../../helpers/zip_builder.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late LocalLibraryLayout layout;
  late LocalLibrary library;

  File zip(String name, Map<String, List<int>> entries) =>
      makeTestZip(Directory(p.join(root.path, 'zips')), name, entries);

  Future<ImportedBatch> importThree({String title = 'Komik'}) {
    return library.importCbz(
      file: zip('$title.cbz', {
        'K/Chapter 1/1.jpg': [1],
        'K/Chapter 1/2.jpg': [2],
        'K/Chapter 2/1.jpg': [3],
        'K/Chapter 3/1.jpg': [4],
      }),
      comicTitle: title,
      splitByFolder: true,
    );
  }

  Future<bool> chapterFolderExists(ImportedBatch batch, int index) async {
    final relative = LocalLibraryLayout.chapterRelativePath(
      batch.comicRemoteId,
      batch.chapters[index].chapterRemoteId,
    );
    return (await layout.resolveDirectory(relative)).exists();
  }

  Future<String?> onlyComicCover() async =>
      (await database.select(database.comics).getSingle()).coverUrl;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kleihon_manage_test_');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    layout = LocalLibraryLayout(
      () async => Directory(p.join(root.path, 'library')),
    );
    library = LocalLibrary(database: database, layout: layout);
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('hapus chapter menghapus data dan berkasnya saja', () async {
    final batch = await importThree();

    await library.deleteChapter(
      comicRemoteId: batch.comicRemoteId,
      chapterRemoteId: batch.chapters[1].chapterRemoteId,
    );

    expect(await database.select(database.chapters).get(), hasLength(2));
    expect(await chapterFolderExists(batch, 1), isFalse);
    expect(await chapterFolderExists(batch, 0), isTrue);
    expect(await chapterFolderExists(batch, 2), isTrue);
  });

  test('sampul pindah saat chapter pemegang sampul dihapus', () async {
    final batch = await importThree();
    final firstDir = LocalLibraryLayout.chapterRelativePath(
      batch.comicRemoteId,
      batch.chapters[0].chapterRemoteId,
    );
    expect(await onlyComicCover(), startsWith(firstDir));

    await library.deleteChapter(
      comicRemoteId: batch.comicRemoteId,
      chapterRemoteId: batch.chapters[0].chapterRemoteId,
    );
    final secondDir = LocalLibraryLayout.chapterRelativePath(
      batch.comicRemoteId,
      batch.chapters[1].chapterRemoteId,
    );
    expect(await onlyComicCover(), startsWith(secondDir));

    await library.deleteChapter(
      comicRemoteId: batch.comicRemoteId,
      chapterRemoteId: batch.chapters[1].chapterRemoteId,
    );
    await library.deleteChapter(
      comicRemoteId: batch.comicRemoteId,
      chapterRemoteId: batch.chapters[2].chapterRemoteId,
    );
    expect(await onlyComicCover(), isNull);
    expect(await database.select(database.comics).get(), hasLength(1));
  });

  test(
    'hapus komik menghapus semua chapter dan folder komik itu saja',
    () async {
      final first = await importThree(title: 'Pertama');
      final second = await importThree(title: 'Kedua');

      await library.deleteComic(first.comicRemoteId);

      final comics = await database.select(database.comics).get();
      expect(comics.single.remoteId, second.comicRemoteId);
      expect(await database.select(database.chapters).get(), hasLength(3));

      final firstDir = await layout.resolveDirectory(
        p.posix.join('comics', first.comicRemoteId),
      );
      final secondDir = await layout.resolveDirectory(
        p.posix.join('comics', second.comicRemoteId),
      );
      expect(await firstDir.exists(), isFalse);
      expect(await secondDir.exists(), isTrue);
    },
  );

  test('hapus komik ikut menghapus bookmark-nya', () async {
    final batch = await importThree();
    await database
        .into(database.bookmarks)
        .insert(BookmarksCompanion.insert(comicId: batch.comicId));

    await library.deleteComic(batch.comicRemoteId);

    expect(await database.select(database.bookmarks).get(), isEmpty);
    expect(await database.select(database.comics).get(), isEmpty);
    expect(await chapterFolderExists(batch, 0), isFalse);
  });

  test('menghapus yang tidak ada dianggap kesalahan pemanggil', () async {
    final batch = await importThree();

    await expectLater(
      library.deleteChapter(
        comicRemoteId: batch.comicRemoteId,
        chapterRemoteId: 'hantu',
      ),
      throwsArgumentError,
    );
    await expectLater(library.deleteComic('hantu'), throwsArgumentError);
  });

  test('setCover mengganti sampul ke halaman yang dipilih', () async {
    final batch = await importThree();
    final chapter = batch.chapters[0];

    await library.setCover(
      comicRemoteId: batch.comicRemoteId,
      chapterRemoteId: chapter.chapterRemoteId,
      pageFileName: '0002.jpg',
    );

    expect(await onlyComicCover(), endsWith('/0002.jpg'));
  });

  test(
    'setCover menolak nama berbahaya, halaman hilang, dan chapter asing',
    () async {
      final batch = await importThree();
      final other = await importThree(title: 'Lain');
      final chapter = batch.chapters[0];

      for (final bad in ['../x.jpg', 'a/b.jpg', r'a\b.jpg', '', '0001.txt']) {
        await expectLater(
          library.setCover(
            comicRemoteId: batch.comicRemoteId,
            chapterRemoteId: chapter.chapterRemoteId,
            pageFileName: bad,
          ),
          throwsArgumentError,
          reason: 'nama "$bad"',
        );
      }

      await expectLater(
        library.setCover(
          comicRemoteId: batch.comicRemoteId,
          chapterRemoteId: chapter.chapterRemoteId,
          pageFileName: '0099.jpg',
        ),
        throwsArgumentError,
      );

      await expectLater(
        library.setCover(
          comicRemoteId: batch.comicRemoteId,
          chapterRemoteId: other.chapters[0].chapterRemoteId,
          pageFileName: '0001.jpg',
        ),
        throwsArgumentError,
      );
    },
  );

  test('listComics diurutkan menurut judul secara alami', () async {
    await importThree(title: 'beta');
    await importThree(title: 'Alpha 10');
    await importThree(title: 'Alpha 2');

    final comics = await library.listComics();
    expect(comics.map((c) => c.title).toList(), [
      'Alpha 2',
      'Alpha 10',
      'beta',
    ]);
  });

  Future<void> saveProgressFor(
    ImportedBatch batch,
    int chapterIndex, {
    int minute = 0,
  }) {
    return ReadingProgressRepositoryImpl(database).saveProgress(
      ReadingProgress(
        sourceId: 'local',
        comicRemoteId: batch.comicRemoteId,
        chapterRemoteId: batch.chapters[chapterIndex].chapterRemoteId,
        pageIndex: 1,
        pageCount: 5,
        scrollOffset: 1,
        aspects: const [1.0],
        updatedAt: DateTime(2026, 11, 21, 10, minute),
      ),
    );
  }

  test(
    'hapus chapter ikut menghapus progres dan riwayat chapter itu',
    () async {
      final batch = await importThree();
      await saveProgressFor(batch, 0, minute: 1);
      await saveProgressFor(batch, 1, minute: 2);

      await library.deleteChapter(
        comicRemoteId: batch.comicRemoteId,
        chapterRemoteId: batch.chapters[1].chapterRemoteId,
      );

      final progress = await database
          .select(database.readingProgressEntries)
          .get();
      expect(progress, hasLength(1));
      expect(progress.single.chapterId, batch.chapters[0].chapterId);
      // Riwayat menunjuk chapter yang dihapus, jadi dihapus juga.
      expect(
        await database.select(database.readingHistoryEntries).get(),
        isEmpty,
      );
    },
  );

  test('hapus komik ikut menghapus semua progres dan riwayatnya', () async {
    final batch = await importThree();
    await saveProgressFor(batch, 0);
    await saveProgressFor(batch, 2, minute: 3);

    await library.deleteComic(batch.comicRemoteId);

    expect(
      await database.select(database.readingProgressEntries).get(),
      isEmpty,
    );
    expect(
      await database.select(database.readingHistoryEntries).get(),
      isEmpty,
    );
    expect(await database.select(database.comics).get(), isEmpty);
  });
}
