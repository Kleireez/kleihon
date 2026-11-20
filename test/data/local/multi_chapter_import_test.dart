import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/database/app_database.dart';
import 'package:kleihon/data/local/cbz_extractor.dart';
import 'package:kleihon/data/local/local_comic_source.dart';
import 'package:kleihon/data/local/local_library.dart';
import 'package:kleihon/data/local/local_library_layout.dart';
import 'package:path/path.dart' as p;

import '../../helpers/zip_builder.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late LocalLibraryLayout layout;
  late LocalLibrary library;
  late LocalComicSource source;

  File zip(String name, Map<String, List<int>> entries) =>
      makeTestZip(Directory(p.join(root.path, 'zips')), name, entries);

  Map<String, List<int>> threeChapters() => {
    'Komik/Chapter 10/1.jpg': [10],
    'Komik/Chapter 1/1.jpg': [1],
    'Komik/Chapter 1/2.jpg': [2],
    'Komik/Chapter 2/1.jpg': [3],
  };

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kleihon_multi_test_');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    layout = LocalLibraryLayout(
      () async => Directory(p.join(root.path, 'library')),
    );
    library = LocalLibrary(database: database, layout: layout);
    source = LocalComicSource(database: database, layout: layout);
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('listGroups mengelompokkan per folder dengan urutan alami', () async {
    final groups = await const CbzExtractor().listGroups(
      zip('a.cbz', threeChapters()),
    );

    expect(groups.map((g) => g.title).toList(), [
      'Chapter 1',
      'Chapter 2',
      'Chapter 10',
    ]);
    expect(groups.map((g) => g.pageCount).toList(), [2, 1, 1]);
  });

  test('impor dengan pemisahan membuat satu chapter per folder', () async {
    final batch = await library.importCbz(
      file: zip('a.cbz', threeChapters()),
      comicTitle: 'Komik Uji',
      splitByFolder: true,
    );

    expect(batch.chapters, hasLength(3));
    expect(batch.pageCount, 4);

    final chapters = await source.getChapters(batch.comicRemoteId, 1);
    expect(chapters.items.map((c) => c.title).toList(), [
      'Chapter 1',
      'Chapter 2',
      'Chapter 10',
    ]);
    expect(chapters.items.map((c) => c.chapterNumber).toList(), [1, 2, 10]);

    final firstPages = await source.getChapterPages(
      chapters.items.first.remoteId,
    );
    expect(firstPages, hasLength(2));
    expect(await database.select(database.comics).get(), hasLength(1));
  });

  test('tanpa pemisahan semua halaman menjadi satu chapter', () async {
    final batch = await library.importCbz(
      file: zip('b.cbz', threeChapters()),
      comicTitle: 'Komik Uji',
    );

    expect(batch.chapters, hasLength(1));
    expect(batch.pageCount, 4);
  });

  test('satu folder saja tetap menjadi satu chapter', () async {
    final batch = await library.importCbz(
      file: zip('c.cbz', {
        'Isi/1.jpg': [1],
        'Isi/2.jpg': [2],
      }),
      comicTitle: 'Komik Uji',
      chapterTitle: 'Chapter 7',
      splitByFolder: true,
    );

    expect(batch.chapters, hasLength(1));
    final chapters = await source.getChapters(batch.comicRemoteId, 1);
    expect(chapters.items.single.title, 'Chapter 7');
    expect(chapters.items.single.chapterNumber, 7);
  });

  test('extract dengan groupPath hanya mengambil folder itu', () async {
    final result = await const CbzExtractor().extract(
      source: zip('d.cbz', threeChapters()),
      destination: Directory(p.join(root.path, 'out')),
      groupPath: 'Komik/Chapter 1',
    );

    expect(result.pages, hasLength(2));
    expect(result.pages[0].readAsBytesSync(), [1]);
    expect(result.pages[1].readAsBytesSync(), [2]);
  });

  test('gagal di tengah impor tidak menyisakan data atau berkas', () async {
    final strict = LocalLibrary(
      database: database,
      layout: layout,
      extractor: const CbzExtractor(limits: CbzLimits(maxPages: 2)),
    );

    await expectLater(
      strict.importCbz(
        file: zip('e.cbz', {
          'A/1.jpg': [1],
          'A/2.jpg': [2],
          'B/1.jpg': [3],
          'B/2.jpg': [4],
          'B/3.jpg': [5],
        }),
        comicTitle: 'Komik Uji',
        splitByFolder: true,
      ),
      throwsA(
        isA<LocalImportException>().having(
          (e) => e.error,
          'error',
          LocalImportError.tooManyEntries,
        ),
      ),
    );

    expect(await database.select(database.comics).get(), isEmpty);
    expect(await database.select(database.chapters).get(), isEmpty);
    final libraryDir = Directory(p.join(root.path, 'library'));
    final files = libraryDir.existsSync()
        ? libraryDir.listSync(recursive: true).whereType<File>()
        : <File>[];
    expect(files, isEmpty);
  });
}
