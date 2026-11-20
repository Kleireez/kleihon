import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/local/cbz_extractor.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kleihon_cbz_test_');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  File makeZip(String name, Map<String, List<int>> entries) {
    final archive = Archive();
    entries.forEach((entryName, bytes) {
      archive.addFile(ArchiveFile.bytes(entryName, bytes));
    });
    final data = ZipEncoder().encodeBytes(archive);
    return File(p.join(root.path, name))..writeAsBytesSync(data);
  }

  Directory dest(String name) => Directory(p.join(root.path, name));

  Matcher importError(LocalImportError expected) => throwsA(
    isA<LocalImportException>().having((e) => e.error, 'error', expected),
  );

  test('halaman diurutkan alami dan diberi nama baru', () async {
    final zip = makeZip('a.cbz', {
      'ch/10.jpg': [10],
      'ch/2.jpg': [2],
      'ch/1.png': [1],
    });

    final result = await const CbzExtractor().extract(
      source: zip,
      destination: dest('out'),
    );

    expect(result.pages.map((f) => p.basename(f.path)).toList(), [
      '0001.png',
      '0002.jpg',
      '0003.jpg',
    ]);
    expect(result.pages[0].readAsBytesSync(), [1]);
    expect(result.pages[1].readAsBytesSync(), [2]);
    expect(result.pages[2].readAsBytesSync(), [10]);
    expect(result.skippedEntries, 0);
  });

  test('entri bukan gambar, tersembunyi, dan berbahaya dilewati', () async {
    final zip = makeZip('b.cbz', {
      'a.jpg': [1],
      'readme.txt': [2],
      '__MACOSX/1.jpg': [3],
      '.hidden.jpg': [4],
      '../evil.jpg': [5],
    });

    final result = await const CbzExtractor().extract(
      source: zip,
      destination: dest('out'),
    );

    expect(result.pages, hasLength(1));
    expect(result.skippedEntries, 4);
    expect(File(p.join(root.path, 'evil.jpg')).existsSync(), isFalse);
  });

  test('arsip tanpa gambar ditolak dan tidak meninggalkan folder', () async {
    final zip = makeZip('c.cbz', {
      'readme.txt': [1],
    });
    final target = dest('out');

    await expectLater(
      const CbzExtractor().extract(source: zip, destination: target),
      importError(LocalImportError.noImages),
    );
    expect(target.existsSync(), isFalse);
    expect(Directory('${target.path}.tmp').existsSync(), isFalse);
  });

  test('file yang bukan arsip ditolak', () async {
    final file = File(p.join(root.path, 'bukan.cbz'))
      ..writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8]);

    await expectLater(
      const CbzExtractor().extract(source: file, destination: dest('out')),
      importError(LocalImportError.notAnArchive),
    );
  });

  test('jumlah halaman melebihi batas ditolak', () async {
    final zip = makeZip('d.cbz', {
      '1.jpg': [1],
      '2.jpg': [2],
      '3.jpg': [3],
    });

    await expectLater(
      const CbzExtractor(limits: CbzLimits(maxPages: 2))
          .extract(source: zip, destination: dest('out')),
      importError(LocalImportError.tooManyEntries),
    );
  });

  test('halaman yang terlalu besar ditolak', () async {
    final zip = makeZip('e.cbz', {'1.jpg': List<int>.filled(10, 7)});

    await expectLater(
      const CbzExtractor(limits: CbzLimits(maxPageBytes: 3))
          .extract(source: zip, destination: dest('out')),
      importError(LocalImportError.entryTooLarge),
    );
  });

  test(
    'folder tujuan yang sudah ada ditolak sebagai kesalahan pemanggil',
    () async {
      final zip = makeZip('f.cbz', {
        '1.jpg': [1],
      });
      final target = dest('out')..createSync();

      await expectLater(
        const CbzExtractor().extract(source: zip, destination: target),
        throwsArgumentError,
      );
    },
  );
}
