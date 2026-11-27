import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DoUpdate, Value;
import 'package:path/path.dart' as p;

import '../../core/constants/app_info.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/natural_compare.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/entity_id.dart';
import '../../domain/repositories/comic_repository.dart';
import '../database/app_database.dart' as db;
import '../database/enums.dart';
import '../local/cbz_extractor.dart';
import '../local/local_library_layout.dart';

class DownloadTaskInfo {
  const DownloadTaskInfo({
    required this.sourceId,
    required this.comicRemoteId,
    required this.chapterRemoteId,
    required this.localPath,
    required this.status,
    this.fileSize = 0,
    this.downloadedAt,
  });

  final String sourceId;
  final String comicRemoteId;
  final String chapterRemoteId;
  final String localPath;
  final DownloadStatus status;
  final int fileSize;
  final DateTime? downloadedAt;
}

typedef _DownloadJob = ({
  String sourceId,
  String comicRemoteId,
  String chapterRemoteId,
});

/// Mengelola antrean unduhan chapter sumber online ke penyimpanan lokal.
class DownloadService {
  DownloadService({
    required db.AppDatabase database,
    required this.repository,
    required this.downloadsRoot,
    DioClient? client,
  }) : _db = database,
       _client = client ?? DioClient();

  final db.AppDatabase _db;
  final ComicRepository repository;
  final Future<Directory> Function() downloadsRoot;
  final DioClient _client;

  final Queue<_DownloadJob> _queue = Queue<_DownloadJob>();
  final Set<String> _cancelled = <String>{};
  bool _processing = false;

  /// Memantau status unduhan semua chapter milik satu komik.
  Stream<Map<String, DownloadTaskInfo>> watchComicDownloads({
    required String sourceId,
    required String comicRemoteId,
  }) {
    final comicId = makeEntityId(sourceId, comicRemoteId);
    final query = _db.select(_db.downloads)
      ..where((t) => t.comicId.equals(comicId));

    return query.watch().map((rows) {
      return {
        for (final row in rows)
          remoteIdFromEntityId(sourceId, row.chapterId): DownloadTaskInfo(
            sourceId: sourceId,
            comicRemoteId: comicRemoteId,
            chapterRemoteId: remoteIdFromEntityId(sourceId, row.chapterId),
            localPath: row.localPath,
            status: row.downloadStatus,
            fileSize: row.fileSize,
            downloadedAt: row.downloadedAt,
          ),
      };
    });
  }

  /// Mengembalikan halaman lokal (`file://`) jika chapter sudah selesai diunduh
  /// dan berkasnya masih ada di perangkat.
  Future<List<ChapterPage>?> getDownloadedPages({
    required String sourceId,
    required String chapterRemoteId,
  }) async {
    if (sourceId == localSourceId) return null;
    final chapterId = makeEntityId(sourceId, chapterRemoteId);
    final row = await (_db.select(
      _db.downloads,
    )..where((t) => t.chapterId.equals(chapterId))).getSingleOrNull();
    if (row == null || row.downloadStatus != DownloadStatus.completed) {
      return null;
    }

    final root = await downloadsRoot();
    final dir = Directory(p.join(root.path, row.localPath));
    if (!await dir.exists()) return null;

    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File &&
          CbzExtractor.imageExtensions.contains(
            p.extension(entity.path).toLowerCase(),
          )) {
        files.add(entity);
      }
    }
    if (files.isEmpty) return null;

    files.sort(
      (a, b) => naturalCompare(p.basename(a.path), p.basename(b.path)),
    );
    return [
      for (var i = 0; i < files.length; i++)
        ChapterPage(index: i, imageUrl: files[i].uri.toString()),
    ];
  }

  /// Menambahkan chapter ke antrean unduhan.
  Future<void> enqueue({
    required String sourceId,
    required String comicRemoteId,
    required String chapterRemoteId,
  }) async {
    if (sourceId == localSourceId) return;

    final comicId = makeEntityId(sourceId, comicRemoteId);
    final chapterId = makeEntityId(sourceId, chapterRemoteId);
    final relativePath = _relativePath(sourceId, comicRemoteId, chapterRemoteId);
    _cancelled.remove(chapterId);

    await _upsertDownloadRow(
      comicId: comicId,
      chapterId: chapterId,
      localPath: relativePath,
      status: DownloadStatus.queued,
    );

    final alreadyQueued = _queue.any(
      (job) =>
          job.sourceId == sourceId && job.chapterRemoteId == chapterRemoteId,
    );
    if (!alreadyQueued) {
      _queue.add((
        sourceId: sourceId,
        comicRemoteId: comicRemoteId,
        chapterRemoteId: chapterRemoteId,
      ));
    }
    unawaited(_processQueue());
  }

  /// Menghapus berkas unduhan dan catatan database untuk satu chapter.
  Future<void> deleteDownload({
    required String sourceId,
    required String comicRemoteId,
    required String chapterRemoteId,
  }) async {
    final chapterId = makeEntityId(sourceId, chapterRemoteId);
    _cancelled.add(chapterId);
    _queue.removeWhere(
      (job) =>
          job.sourceId == sourceId && job.chapterRemoteId == chapterRemoteId,
    );

    final row = await (_db.select(
      _db.downloads,
    )..where((t) => t.chapterId.equals(chapterId))).getSingleOrNull();
    final relative =
        row?.localPath ??
        _relativePath(sourceId, comicRemoteId, chapterRemoteId);

    await (_db.delete(
      _db.downloads,
    )..where((t) => t.chapterId.equals(chapterId))).go();

    final root = await downloadsRoot();
    final dir = Directory(p.join(root.path, relative));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeFirst();
        await _runJob(job);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _runJob(_DownloadJob job) async {
    final comicId = makeEntityId(job.sourceId, job.comicRemoteId);
    final chapterId = makeEntityId(job.sourceId, job.chapterRemoteId);
    if (_cancelled.contains(chapterId)) return;

    final relativePath = _relativePath(
      job.sourceId,
      job.comicRemoteId,
      job.chapterRemoteId,
    );

    await _upsertDownloadRow(
      comicId: comicId,
      chapterId: chapterId,
      localPath: relativePath,
      status: DownloadStatus.downloading,
    );

    final root = await downloadsRoot();
    final targetDir = Directory(p.join(root.path, relativePath));
    final tempDir = Directory('${targetDir.path}.tmp');
    var success = false;

    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);

      final pages = await repository.getChapterPages(
        sourceId: job.sourceId,
        chapterRemoteId: job.chapterRemoteId,
      );
      if (pages.isEmpty) {
        throw StateError('Chapter tidak memiliki halaman');
      }

      final digits = pages.length.toString().length;
      final width = digits < 4 ? 4 : digits;
      var totalBytes = 0;

      for (var i = 0; i < pages.length; i++) {
        if (_cancelled.contains(chapterId)) return;
        final page = pages[i];
        final response = await _client.get<List<int>>(
          page.imageUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: const {'User-Agent': 'KleiHon/$appVersion'},
          ),
        );
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) {
          throw StateError('Halaman ${i + 1} kosong');
        }

        final ext = _extensionOf(page.imageUrl);
        final fileName = '${(i + 1).toString().padLeft(width, '0')}$ext';
        await File(p.join(tempDir.path, fileName)).writeAsBytes(
          bytes,
          flush: true,
        );
        totalBytes += bytes.length;
      }

      if (_cancelled.contains(chapterId)) return;
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await targetDir.parent.create(recursive: true);
      await tempDir.rename(targetDir.path);
      success = true;

      await _upsertDownloadRow(
        comicId: comicId,
        chapterId: chapterId,
        localPath: relativePath,
        status: DownloadStatus.completed,
        fileSize: totalBytes,
        downloadedAt: DateTime.now(),
      );
    } catch (e, s) {
      appLogger.w('Gagal mengunduh chapter $chapterId', error: e, stackTrace: s);
      if (!_cancelled.contains(chapterId)) {
        await _upsertDownloadRow(
          comicId: comicId,
          chapterId: chapterId,
          localPath: relativePath,
          status: DownloadStatus.failed,
        );
      }
    } finally {
      if (!success && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> _upsertDownloadRow({
    required String comicId,
    required String chapterId,
    required String localPath,
    required DownloadStatus status,
    int fileSize = 0,
    DateTime? downloadedAt,
  }) async {
    final table = _db.downloads;
    await _db
        .into(table)
        .insert(
          db.DownloadsCompanion.insert(
            comicId: comicId,
            chapterId: chapterId,
            localPath: localPath,
            downloadStatus: Value(status),
            fileSize: Value(fileSize),
            downloadedAt: Value(downloadedAt),
          ),
          onConflict: DoUpdate(
            (old) => db.DownloadsCompanion(
              localPath: Value(localPath),
              downloadStatus: Value(status),
              fileSize: Value(fileSize),
              downloadedAt: Value(downloadedAt),
            ),
            target: [table.chapterId],
          ),
        );
  }

  static String _relativePath(
    String sourceId,
    String comicRemoteId,
    String chapterRemoteId,
  ) {
    return p.join(
      _safeSegment(sourceId),
      _safeSegment(comicRemoteId),
      _safeSegment(chapterRemoteId),
    );
  }

  static String _safeSegment(String raw) {
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  static String _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final ext = p.extension(path).toLowerCase();
    if (CbzExtractor.imageExtensions.contains(ext)) return ext;
    return '.jpg';
  }
}
