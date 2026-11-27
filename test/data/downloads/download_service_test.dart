import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/network/dio_client.dart';
import 'package:kleihon/data/database/app_database.dart' as db;
import 'package:kleihon/data/database/enums.dart';
import 'package:kleihon/data/downloads/download_service.dart';
import 'package:kleihon/data/repositories/comic_repository_impl.dart';
import 'package:kleihon/data/sources/source_registry.dart';
import 'package:kleihon/domain/entities/chapter.dart';
import 'package:path/path.dart' as p;

import '../../helpers/fake_comic_source.dart';

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}

void main() {
  late Directory root;
  late db.AppDatabase database;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kleihon_dl_test_');
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('enqueue mengunduh halaman ke disk, membaca offline, dan menghapus', () async {
    final source = FakeComicSource(
      'mangadex',
      onPages: (chapterId) async => const [
        ChapterPage(index: 0, imageUrl: 'https://cdn.example/1.jpg'),
        ChapterPage(index: 1, imageUrl: 'https://cdn.example/2.png'),
      ],
    );
    final repo = ComicRepositoryImpl(SourceRegistry([source]));
    final client = DioClient();
    client.dio.httpClientAdapter = _BytesAdapter((options) {
      return ResponseBody.fromBytes(
        Uint8List.fromList([1, 2, 3, 4]),
        200,
      );
    });

    final service = DownloadService(
      database: database,
      repository: repo,
      downloadsRoot: () async => Directory(p.join(root.path, 'downloads')),
      client: client,
    );

    // Seed comic row to satisfy foreign key on downloads.
    await database.into(database.comics).insert(
          db.ComicsCompanion.insert(
            id: 'mangadex:m1',
            sourceId: 'mangadex',
            remoteId: 'm1',
            title: 'Komik Online',
            sourceUrl: 'https://mangadex.org/title/m1',
          ),
        );

    await service.enqueue(
      sourceId: 'mangadex',
      comicRemoteId: 'm1',
      chapterRemoteId: 'c1',
    );

    // Tunggu antrean selesai.
    Map<String, DownloadTaskInfo> latest = const {};
    for (var i = 0; i < 30; i++) {
      latest = await service
          .watchComicDownloads(sourceId: 'mangadex', comicRemoteId: 'm1')
          .first;
      if (latest['c1']?.status == DownloadStatus.completed) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(latest['c1']?.status, DownloadStatus.completed);
    expect(latest['c1']?.fileSize, 8);

    final offline = await service.getDownloadedPages(
      sourceId: 'mangadex',
      chapterRemoteId: 'c1',
    );
    expect(offline, isNotNull);
    expect(offline!.length, 2);
    expect(offline[0].imageUrl, startsWith('file://'));
    expect(offline[0].imageUrl, endsWith('0001.jpg'));
    expect(offline[1].imageUrl, endsWith('0002.png'));

    await service.deleteDownload(
      sourceId: 'mangadex',
      comicRemoteId: 'm1',
      chapterRemoteId: 'c1',
    );
    expect(
      await service.getDownloadedPages(
        sourceId: 'mangadex',
        chapterRemoteId: 'c1',
      ),
      isNull,
    );
  });

  test('kegagalan unduhan menandai status failed tanpa sisa folder tmp', () async {
    final source = FakeComicSource(
      'mangadex',
      onPages: (chapterId) async => const [
        ChapterPage(index: 0, imageUrl: 'https://cdn.example/1.jpg'),
      ],
    );
    final repo = ComicRepositoryImpl(SourceRegistry([source]));
    final client = DioClient();
    client.dio.httpClientAdapter = _BytesAdapter(
      (options) => ResponseBody.fromString('err', 404),
    );

    final service = DownloadService(
      database: database,
      repository: repo,
      downloadsRoot: () async => Directory(p.join(root.path, 'downloads')),
      client: client,
    );

    await database.into(database.comics).insert(
          db.ComicsCompanion.insert(
            id: 'mangadex:m1',
            sourceId: 'mangadex',
            remoteId: 'm1',
            title: 'Komik Online',
            sourceUrl: 'https://mangadex.org/title/m1',
          ),
        );

    await service.enqueue(
      sourceId: 'mangadex',
      comicRemoteId: 'm1',
      chapterRemoteId: 'c1',
    );

    Map<String, DownloadTaskInfo> latest = const {};
    for (var i = 0; i < 30; i++) {
      latest = await service
          .watchComicDownloads(sourceId: 'mangadex', comicRemoteId: 'm1')
          .first;
      if (latest['c1']?.status == DownloadStatus.failed) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(latest['c1']?.status, DownloadStatus.failed);
    final tmp = Directory(p.join(root.path, 'downloads', 'mangadex', 'm1', 'c1.tmp'));
    expect(await tmp.exists(), isFalse);
  });
}
