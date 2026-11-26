import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/storage/storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory library;
  late Directory cache;
  late int imageCacheClears;
  late DeviceStorageService service;

  File write(Directory directory, String relative, int size) {
    final file = File(p.join(directory.path, relative))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(size, 1));
    return file;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kleihon_storage_test_');
    library = Directory(p.join(root.path, 'library'));
    cache = Directory(p.join(root.path, 'cache'));
    imageCacheClears = 0;
    service = DeviceStorageService(
      libraryRoot: () async => library,
      cacheRoot: () async => cache,
      onCacheCleared: () => imageCacheClears++,
    );
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('ukuran perpustakaan menjumlahkan semua berkas bersarang', () async {
    write(library, 'a/1.bin', 100);
    write(library, 'a/b/2.bin', 250);
    write(library, 'c.bin', 50);

    expect(await service.libraryBytes(), 400);
  });

  test('folder yang belum ada dianggap kosong', () async {
    expect(await service.libraryBytes(), 0);
    expect(await service.cacheBytes(), 0);
  });

  test('ukuran cache dihitung terpisah dari perpustakaan', () async {
    write(library, '1.bin', 1000);
    write(cache, 'x/1.bin', 30);
    write(cache, '2.bin', 70);

    expect(await service.cacheBytes(), 100);
    expect(await service.libraryBytes(), 1000);
  });

  test('hapus cache mengosongkan isi, mempertahankan folder, dan melaporkan ukuran', () async {
    write(cache, 'x/1.bin', 30);
    write(cache, 'y/z/2.bin', 70);
    write(cache, '3.bin', 100);

    final freed = await service.clearCache();

    expect(freed, 200);
    expect(await service.cacheBytes(), 0);
    expect(cache.existsSync(), isTrue);
    expect(cache.listSync(), isEmpty);
    expect(imageCacheClears, 1);
  });

  test('hapus cache tidak menyentuh perpustakaan', () async {
    write(library, 'a/1.bin', 500);
    write(cache, '1.bin', 10);

    await service.clearCache();

    expect(await service.libraryBytes(), 500);
  });

  test('hapus cache pada folder yang belum ada tetap aman', () async {
    final freed = await service.clearCache();

    expect(freed, 0);
    expect(imageCacheClears, 1);
  });
}
