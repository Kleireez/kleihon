import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/natural_compare.dart';
import '../../domain/entities/entity_id.dart';
import '../database/app_database.dart';
import 'cbz_extractor.dart';
import 'local_library_layout.dart';

/// ID acak berbasis waktu, aman dipakai sebagai nama folder.
String newLocalId() {
  final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = Random.secure().nextInt(0x7fffffff).toRadixString(36);
  return '$micros-$salt';
}

/// Angka terakhir di teks, misalnya "Chapter 12" menjadi 12.
double? guessChapterNumber(String text) {
  final matches = RegExp(r'\d+(?:\.\d+)?').allMatches(text).toList();
  if (matches.isEmpty) return null;
  return double.tryParse(matches.last.group(0)!);
}

class ImportedChapter {
  const ImportedChapter({
    required this.comicRemoteId,
    required this.chapterRemoteId,
    required this.pageCount,
  });

  final String comicRemoteId;
  final String chapterRemoteId;
  final int pageCount;

  String get comicId => makeEntityId(localSourceId, comicRemoteId);
  String get chapterId => makeEntityId(localSourceId, chapterRemoteId);
}

/// Hasil satu kali impor: satu komik dan satu atau lebih chapter baru.
class ImportedBatch {
  const ImportedBatch({required this.comicRemoteId, required this.chapters});

  final String comicRemoteId;
  final List<ImportedChapter> chapters;

  int get pageCount => chapters.fold(0, (sum, c) => sum + c.pageCount);
  String get comicId => makeEntityId(localSourceId, comicRemoteId);
}

/// Ringkasan komik lokal untuk pilihan di dialog impor.
class LocalComicSummary {
  const LocalComicSummary({required this.remoteId, required this.title});

  final String remoteId;
  final String title;
}

class _CreatedChapter {
  const _CreatedChapter({
    required this.key,
    required this.relative,
    required this.title,
    required this.pageCount,
    required this.firstPage,
  });

  final String key;
  final String relative;
  final String title;
  final int pageCount;
  final String firstPage;
}

/// Mengimpor dan mengelola komik lokal di penyimpanan aplikasi dan database.
class LocalLibrary {
  LocalLibrary({
    required AppDatabase database,
    required this.layout,
    this.extractor = const CbzExtractor(),
  }) : _db = database;

  final AppDatabase _db;
  final LocalLibraryLayout layout;
  final CbzExtractor extractor;

  /// Daftar folder berisi gambar di dalam arsip (untuk memutuskan pemisahan).
  Future<List<ArchiveGroup>> inspectArchive(File file) =>
      extractor.listGroups(file);

  /// Semua komik lokal, diurutkan menurut judul.
  Future<List<LocalComicSummary>> listComics() async {
    final rows = await (_db.select(
      _db.comics,
    )..where((t) => t.sourceId.equals(localSourceId))).get();
    final list = [
      for (final row in rows)
        LocalComicSummary(remoteId: row.remoteId, title: row.title),
    ]..sort((a, b) => naturalCompare(a.title, b.title));
    return list;
  }

  /// Jika [comicRemoteId] kosong, komik baru dibuat. Jika diisi, chapter
  /// ditambahkan ke komik yang sudah ada.
  /// Jika [splitByFolder] true dan arsip berisi lebih dari satu folder
  /// bergambar, tiap folder menjadi satu chapter. Selain itu semua halaman
  /// menjadi satu chapter.
  /// Semua atau tidak sama sekali: jika ada yang gagal, tidak ada yang tersisa.
  /// Melempar [LocalImportException] jika arsip bermasalah.
  Future<ImportedBatch> importCbz({
    required File file,
    required String comicTitle,
    String? comicRemoteId,
    String? chapterTitle,
    double? chapterNumber,
    bool splitByFolder = false,
  }) async {
    final title = comicTitle.trim();
    if (title.isEmpty) {
      throw ArgumentError.value(
        comicTitle,
        'comicTitle',
        'Judul tidak boleh kosong',
      );
    }

    final isNewComic = comicRemoteId == null;
    final comicKey = comicRemoteId ?? newLocalId();
    final comicId = makeEntityId(localSourceId, comicKey);

    if (!isNewComic) {
      final existing = await (_db.select(
        _db.comics,
      )..where((t) => t.id.equals(comicId))).getSingleOrNull();
      if (existing == null) {
        throw ArgumentError.value(
          comicRemoteId,
          'comicRemoteId',
          'Komik tidak ditemukan',
        );
      }
    }

    // null berarti semua halaman menjadi satu chapter.
    final List<ArchiveGroup?> plan;
    if (splitByFolder) {
      final groups = await extractor.listGroups(file);
      plan = groups.length > 1 ? groups : [null];
    } else {
      plan = [null];
    }

    final baseName = p.basenameWithoutExtension(file.path);
    final fallbackTitle = (chapterTitle ?? baseName).trim();
    final created = <_CreatedChapter>[];

    Future<void> cleanup() async {
      for (final chapter in created) {
        await _deleteIfExists(await layout.resolveDirectory(chapter.relative));
      }
      if (isNewComic) {
        await _deleteIfExists(
          await layout.resolveDirectory(p.posix.join('comics', comicKey)),
        );
      }
    }

    try {
      for (final group in plan) {
        final chapterKey = newLocalId();
        final relative = LocalLibraryLayout.chapterRelativePath(
          comicKey,
          chapterKey,
        );
        final result = await extractor.extract(
          source: file,
          destination: await layout.resolveDirectory(relative),
          groupPath: group?.path,
        );

        final groupTitle = group?.title.trim() ?? '';
        created.add(
          _CreatedChapter(
            key: chapterKey,
            relative: relative,
            title: groupTitle.isEmpty ? fallbackTitle : groupTitle,
            pageCount: result.pages.length,
            firstPage: p.basename(result.pages.first.path),
          ),
        );
      }

      final now = DateTime.now();
      final cover = p.posix.join(
        created.first.relative,
        created.first.firstPage,
      );

      await _db.transaction(() async {
        if (isNewComic) {
          await _db
              .into(_db.comics)
              .insert(
                ComicsCompanion.insert(
                  id: comicId,
                  sourceId: localSourceId,
                  remoteId: comicKey,
                  title: title,
                  sourceUrl: 'local:$comicKey',
                  coverUrl: Value(cover),
                  updatedAt: Value(now),
                ),
              );
        } else {
          await (_db.update(_db.comics)..where((t) => t.id.equals(comicId)))
              .write(ComicsCompanion(updatedAt: Value(now)));
        }

        for (final chapter in created) {
          final number = created.length == 1
              ? (chapterNumber ?? guessChapterNumber(chapter.title))
              : guessChapterNumber(chapter.title);
          await _db
              .into(_db.chapters)
              .insert(
                ChaptersCompanion.insert(
                  id: makeEntityId(localSourceId, chapter.key),
                  comicId: comicId,
                  title: chapter.title.isEmpty ? 'Chapter' : chapter.title,
                  chapterUrl: chapter.relative,
                  chapterNumber: Value(number),
                  publishedAt: Value(now),
                ),
              );
        }
      });
    } catch (_) {
      await cleanup();
      rethrow;
    }

    return ImportedBatch(
      comicRemoteId: comicKey,
      chapters: [
        for (final chapter in created)
          ImportedChapter(
            comicRemoteId: comicKey,
            chapterRemoteId: chapter.key,
            pageCount: chapter.pageCount,
          ),
      ],
    );
  }

  /// Menghapus satu chapter beserta berkas gambar, progres, dan riwayatnya.
  /// Jika chapter itu memegang sampul, sampul dipindah ke chapter yang
  /// tersisa (atau kosong).
  Future<void> deleteChapter({
    required String comicRemoteId,
    required String chapterRemoteId,
  }) async {
    final comicId = makeEntityId(localSourceId, comicRemoteId);
    final chapterId = makeEntityId(localSourceId, chapterRemoteId);

    final chapter =
        await (_db.select(
              _db.chapters,
            )..where((t) => t.id.equals(chapterId) & t.comicId.equals(comicId)))
            .getSingleOrNull();
    if (chapter == null) {
      throw ArgumentError.value(
        chapterRemoteId,
        'chapterRemoteId',
        'Chapter tidak ditemukan',
      );
    }
    final comic = await (_db.select(
      _db.comics,
    )..where((t) => t.id.equals(comicId))).getSingle();

    final cover = comic.coverUrl;
    final coverInDeleted =
        cover != null && p.posix.dirname(cover) == chapter.chapterUrl;
    final replacement = coverInDeleted
        ? await _coverFromRemaining(comicId, chapterId)
        : null;

    await _db.transaction(() async {
      await (_db.delete(_db.readingProgressEntries)..where(
            (t) => t.comicId.equals(comicId) & t.chapterId.equals(chapterId),
          ))
          .go();
      await (_db.delete(_db.readingHistoryEntries)..where(
            (t) => t.comicId.equals(comicId) & t.chapterId.equals(chapterId),
          ))
          .go();
      await (_db.delete(
        _db.chapters,
      )..where((t) => t.id.equals(chapterId))).go();
      if (coverInDeleted) {
        await (_db.update(_db.comics)..where((t) => t.id.equals(comicId)))
            .write(ComicsCompanion(coverUrl: Value(replacement)));
      }
    });

    await _deleteIfExists(await layout.resolveDirectory(chapter.chapterUrl));
  }

  /// Menghapus komik, semua chapter, progres, riwayat, dan seluruh berkasnya.
  /// Data di database dihapus lebih dulu dalam satu transaksi: jika ditolak
  /// (misalnya masih ada bookmark), tidak ada yang berubah dan tidak ada
  /// berkas yang terhapus.
  Future<void> deleteComic(String comicRemoteId) async {
    final comicId = makeEntityId(localSourceId, comicRemoteId);
    final comic = await (_db.select(
      _db.comics,
    )..where((t) => t.id.equals(comicId))).getSingleOrNull();
    if (comic == null) {
      throw ArgumentError.value(
        comicRemoteId,
        'comicRemoteId',
        'Komik tidak ditemukan',
      );
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.readingProgressEntries,
      )..where((t) => t.comicId.equals(comicId))).go();
      await (_db.delete(
        _db.readingHistoryEntries,
      )..where((t) => t.comicId.equals(comicId))).go();
      await (_db.delete(
        _db.chapters,
      )..where((t) => t.comicId.equals(comicId))).go();
      await (_db.delete(_db.comics)..where((t) => t.id.equals(comicId))).go();
    });

    await _deleteIfExists(
      await layout.resolveDirectory(p.posix.join('comics', comicRemoteId)),
    );
  }

  /// Menjadikan sebuah halaman chapter sebagai sampul komik.
  Future<void> setCover({
    required String comicRemoteId,
    required String chapterRemoteId,
    required String pageFileName,
  }) async {
    final looksSafe =
        pageFileName.isNotEmpty &&
        pageFileName == p.basename(pageFileName) &&
        !pageFileName.contains('\\') &&
        !pageFileName.contains('/') &&
        CbzExtractor.imageExtensions.contains(
          p.extension(pageFileName).toLowerCase(),
        );
    if (!looksSafe) {
      throw ArgumentError.value(
        pageFileName,
        'pageFileName',
        'Nama berkas halaman tidak valid',
      );
    }

    final comicId = makeEntityId(localSourceId, comicRemoteId);
    final chapterId = makeEntityId(localSourceId, chapterRemoteId);
    final chapter =
        await (_db.select(
              _db.chapters,
            )..where((t) => t.id.equals(chapterId) & t.comicId.equals(comicId)))
            .getSingleOrNull();
    if (chapter == null) {
      throw ArgumentError.value(
        chapterRemoteId,
        'chapterRemoteId',
        'Chapter tidak ditemukan pada komik ini',
      );
    }

    final relative = p.posix.join(chapter.chapterUrl, pageFileName);
    final file = await layout.resolveFile(relative);
    if (!await file.exists()) {
      throw ArgumentError.value(
        pageFileName,
        'pageFileName',
        'Halaman tidak ditemukan',
      );
    }

    await (_db.update(_db.comics)..where((t) => t.id.equals(comicId))).write(
      ComicsCompanion(coverUrl: Value(relative)),
    );
  }

  Future<String?> _coverFromRemaining(
    String comicId,
    String excludedChapterId,
  ) async {
    final rows =
        (await (_db.select(
              _db.chapters,
            )..where((t) => t.comicId.equals(comicId))).get())
            .where((row) => row.id != excludedChapterId)
            .toList()
          ..sort((a, b) {
            final an = a.chapterNumber;
            final bn = b.chapterNumber;
            if (an != null && bn != null && an != bn) return an.compareTo(bn);
            return naturalCompare(a.title, b.title);
          });

    for (final row in rows) {
      final cover = await _firstPageOf(row.chapterUrl);
      if (cover != null) return cover;
    }
    return null;
  }

  Future<String?> _firstPageOf(String relativeDirectory) async {
    final directory = await layout.resolveDirectory(relativeDirectory);
    if (!await directory.exists()) return null;

    final names = <String>[];
    await for (final entity in directory.list()) {
      if (entity is File &&
          CbzExtractor.imageExtensions.contains(
            p.extension(entity.path).toLowerCase(),
          )) {
        names.add(p.basename(entity.path));
      }
    }
    if (names.isEmpty) return null;
    names.sort(naturalCompare);
    return p.posix.join(relativeDirectory, names.first);
  }

  Future<void> _deleteIfExists(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
