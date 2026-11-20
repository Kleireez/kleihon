import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

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

/// Mengimpor CBZ milik pengguna ke penyimpanan aplikasi dan database.
class LocalLibrary {
  LocalLibrary({
    required AppDatabase database,
    required this._layout,
    this._extractor = const CbzExtractor(),
  }) : _db = database;

  final AppDatabase _db;
  final LocalLibraryLayout _layout;
  final CbzExtractor _extractor;

  /// Jika [comicRemoteId] kosong, komik baru dibuat. Jika diisi, chapter
  /// ditambahkan ke komik yang sudah ada.
  /// Melempar [LocalImportException] jika arsip bermasalah.
  Future<ImportedChapter> importCbz({
    required File file,
    required String comicTitle,
    String? comicRemoteId,
    String? chapterTitle,
    double? chapterNumber,
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

    final chapterKey = newLocalId();
    final chapterId = makeEntityId(localSourceId, chapterKey);
    final relative = LocalLibraryLayout.chapterRelativePath(
      comicKey,
      chapterKey,
    );
    final directory = await _layout.resolveDirectory(relative);

    final result = await _extractor.extract(
      source: file,
      destination: directory,
    );

    final name = (chapterTitle ?? p.basenameWithoutExtension(file.path)).trim();
    final now = DateTime.now();
    final cover = p.posix.join(relative, p.basename(result.pages.first.path));

    try {
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

        await _db
            .into(_db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: chapterId,
                comicId: comicId,
                title: name.isEmpty ? 'Chapter' : name,
                chapterUrl: relative,
                chapterNumber: Value(chapterNumber ?? guessChapterNumber(name)),
                publishedAt: Value(now),
              ),
            );
      });
    } catch (_) {
      await _deleteIfExists(directory);
      if (isNewComic) {
        await _deleteIfExists(
          await _layout.resolveDirectory(p.posix.join('comics', comicKey)),
        );
      }
      rethrow;
    }

    return ImportedChapter(
      comicRemoteId: comicKey,
      chapterRemoteId: chapterKey,
      pageCount: result.pages.length,
    );
  }

  Future<void> _deleteIfExists(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
