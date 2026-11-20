import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/errors/app_exception.dart';
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
  late LocalLibrary library;
  late LocalComicSource source;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kleihon_local_test_');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final layout = LocalLibraryLayout(
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

  File zip(String name, [Map<String, List<int>>? entries]) => makeTestZip(
    Directory(p.join(root.path, 'zips')),
    name,
    entries ??
        {
          '1.jpg': [1],
          '2.jpg': [2],
        },
  );

  Matcher notFound() => throwsA(
    isA<AppException>().having((e) => e.type, 'type', AppErrorType.notFound),
  );

  test('impor CBZ baru bisa dibaca lewat source', () async {
    final imported = await library.importCbz(
      file: zip('Chapter 12.cbz'),
      comicTitle: 'Judul Uji',
    );

    final comic = await source.getComicDetail(imported.comicRemoteId);
    expect(comic.title, 'Judul Uji');
    expect(comic.sourceId, 'local');
    expect(File.fromUri(Uri.parse(comic.coverUrl!)).existsSync(), isTrue);

    final chapters = await source.getChapters(imported.comicRemoteId, 1);
    expect(chapters.hasNext, isFalse);
    expect(chapters.items.single.chapterNumber, 12);

    final pages = await source.getChapterPages(chapters.items.single.remoteId);
    expect(pages, hasLength(2));
    for (final page in pages) {
      expect(File.fromUri(Uri.parse(page.imageUrl)).existsSync(), isTrue);
    }
  });

  test('chapter ditambahkan ke komik yang sama dan diurutkan', () async {
    final first = await library.importCbz(
      file: zip('ch 10.cbz'),
      comicTitle: 'Komik A',
    );
    await library.importCbz(
      file: zip('ch 2.cbz'),
      comicTitle: 'Komik A',
      comicRemoteId: first.comicRemoteId,
    );

    final chapters = await source.getChapters(first.comicRemoteId, 1);
    expect(chapters.items.map((c) => c.title).toList(), ['ch 2', 'ch 10']);
    expect(await database.select(database.comics).get(), hasLength(1));
  });

  test('terbaru dan pencarian bekerja', () async {
    await library.importCbz(file: zip('a.cbz'), comicTitle: 'Alpha Satu');
    await library.importCbz(file: zip('b.cbz'), comicTitle: 'Beta Dua');

    final latest = await source.getLatest(1);
    expect(latest.items.map((c) => c.title).toList(), [
      'Beta Dua',
      'Alpha Satu',
    ]);

    final found = await source.search('alpha', 1);
    expect(found.items.single.title, 'Alpha Satu');

    // Karakter khusus LIKE tidak boleh dianggap wildcard.
    expect((await source.search('%', 1)).items, isEmpty);
  });

  test('pagination daftar komik', () async {
    for (var i = 0; i < 21; i++) {
      await library.importCbz(file: zip('c$i.cbz'), comicTitle: 'Komik $i');
    }

    final page1 = await source.getLatest(1);
    final page2 = await source.getLatest(2);
    expect(page1.items, hasLength(LocalComicSource.pageSize));
    expect(page1.hasNext, isTrue);
    expect(page2.items, hasLength(1));
    expect(page2.hasNext, isFalse);
  });

  test('komik atau chapter yang tidak ada menghasilkan notFound', () async {
    await expectLater(source.getComicDetail('nope'), notFound());
    await expectLater(source.getChapterPages('nope'), notFound());
  });

  test('impor gagal tidak meninggalkan data atau berkas', () async {
    final bad = zip('bad.cbz', {
      'readme.txt': [1],
    });

    await expectLater(
      library.importCbz(file: bad, comicTitle: 'X'),
      throwsA(isA<LocalImportException>()),
    );

    expect(await database.select(database.comics).get(), isEmpty);
    final libraryDir = Directory(p.join(root.path, 'library'));
    final leftovers = libraryDir.existsSync()
        ? libraryDir.listSync(recursive: true).whereType<File>()
        : <File>[];
    expect(leftovers, isEmpty);
  });

  test('menambah ke komik yang tidak ada ditolak sebelum ekstraksi', () async {
    await expectLater(
      library.importCbz(
        file: zip('x.cbz'),
        comicTitle: 'X',
        comicRemoteId: 'ghost',
      ),
      throwsArgumentError,
    );
    expect(Directory(p.join(root.path, 'library')).existsSync(), isFalse);
  });

  test('guessChapterNumber mengambil angka terakhir', () {
    expect(guessChapterNumber('Chapter 12'), 12);
    expect(guessChapterNumber('ch 3.5 final'), 3.5);
    expect(guessChapterNumber('Vol 2 Chapter 15'), 15);
    expect(guessChapterNumber('Prolog'), isNull);
  });
}
