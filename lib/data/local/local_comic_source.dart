import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_exception.dart';
import '../../core/utils/natural_compare.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/entity_id.dart';
import '../../domain/entities/source_results.dart';
import '../database/app_database.dart' as db;
import '../sources/comic_source.dart';
import 'cbz_extractor.dart';
import 'local_library_layout.dart';

/// Sumber komik dari perpustakaan lokal (CBZ yang diimpor pengguna).
/// Gambar disajikan sebagai URI file:// untuk dibuka dengan Image.file.
class LocalComicSource extends ComicSource {
  LocalComicSource({required db.AppDatabase database, required this._layout})
    : _db = database;

  static const int pageSize = 20;

  final db.AppDatabase _db;
  final LocalLibraryLayout _layout;

  @override
  String get id => localSourceId;

  @override
  String get name => 'Perpustakaan lokal';

  @override
  Set<SourceCapability> get capabilities => const {
    SourceCapability.latest,
    SourceCapability.search,
  };

  @override
  Future<Comic> getComicDetail(String comicId) async {
    final row = await (_db.select(
      _db.comics,
    )..where((t) => t.id.equals(makeEntityId(id, comicId)))).getSingleOrNull();
    if (row == null) {
      throw AppException(
        AppErrorType.notFound,
        debugMessage: 'Komik lokal tidak ada: $comicId',
      );
    }
    return _toComic(row);
  }

  @override
  Future<PagedResult<Chapter>> getChapters(String comicId, int page) async {
    if (page > 1) {
      return PagedResult(items: const [], page: page, hasNext: false);
    }
    final rows = await (_db.select(
      _db.chapters,
    )..where((t) => t.comicId.equals(makeEntityId(id, comicId)))).get();

    final chapters = [
      for (final row in rows)
        Chapter(
          sourceId: id,
          comicRemoteId: comicId,
          remoteId: _remoteIdOf(row.id),
          title: row.title,
          chapterUrl: row.chapterUrl,
          chapterNumber: row.chapterNumber,
          publishedAt: row.publishedAt,
        ),
    ]..sort(_compareChapters);

    return PagedResult(items: chapters, page: 1, hasNext: false);
  }

  @override
  Future<List<ChapterPage>> getChapterPages(String chapterId) async {
    final row =
        await (_db.select(_db.chapters)
              ..where((t) => t.id.equals(makeEntityId(id, chapterId))))
            .getSingleOrNull();
    if (row == null) {
      throw AppException(
        AppErrorType.notFound,
        debugMessage: 'Chapter lokal tidak ada: $chapterId',
      );
    }

    final directory = await _layout.resolveDirectory(row.chapterUrl);
    if (!await directory.exists()) {
      throw AppException(
        AppErrorType.notFound,
        debugMessage: 'Folder chapter hilang: ${row.chapterUrl}',
      );
    }

    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File &&
          CbzExtractor.imageExtensions.contains(
            p.extension(entity.path).toLowerCase(),
          )) {
        files.add(entity);
      }
    }
    files.sort(
      (a, b) => naturalCompare(p.basename(a.path), p.basename(b.path)),
    );

    return [
      for (var i = 0; i < files.length; i++)
        ChapterPage(index: i, imageUrl: files[i].uri.toString()),
    ];
  }

  @override
  Future<PagedResult<Comic>> getLatest(int page) => _listComics(page: page);

  @override
  Future<PagedResult<Comic>> search(String query, int page) =>
      _listComics(page: page, query: query.trim());

  /// Tanpa [query]: paginasi di database. Dengan [query]: pencocokan
  /// substring tanpa peka huruf besar-kecil dilakukan di Dart, supaya
  /// karakter seperti % dan _ diperlakukan sebagai teks biasa.
  Future<PagedResult<Comic>> _listComics({
    required int page,
    String? query,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final offset = (safePage - 1) * pageSize;

    final statement = _db.select(_db.comics)
      ..where((t) => t.sourceId.equals(id))
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.id),
      ]);

    final needle = query?.trim().toLowerCase();
    final List<db.Comic> rows;
    if (needle == null || needle.isEmpty) {
      statement.limit(pageSize + 1, offset: offset);
      rows = await statement.get();
    } else {
      final all = await statement.get();
      rows = all
          .where((row) => row.title.toLowerCase().contains(needle))
          .skip(offset)
          .take(pageSize + 1)
          .toList();
    }

    final hasNext = rows.length > pageSize;
    final pageRows = hasNext ? rows.sublist(0, pageSize) : rows;

    return PagedResult(
      items: [for (final row in pageRows) await _toComic(row)],
      page: safePage,
      hasNext: hasNext,
    );
  }

  Future<Comic> _toComic(db.Comic row) async {
    String? cover;
    final relativeCover = row.coverUrl;
    if (relativeCover != null) {
      cover = (await _layout.resolveFile(relativeCover)).uri.toString();
    }
    return Comic(
      sourceId: row.sourceId,
      remoteId: row.remoteId,
      title: row.title,
      sourceUrl: row.sourceUrl,
      alternativeTitles: _decodeList(row.alternativeTitlesJson),
      coverUrl: cover,
      synopsis: row.synopsis,
      author: row.author,
      artist: row.artist,
      status: row.status,
      type: row.type,
      genres: _decodeList(row.genresJson),
      rating: row.rating,
      updatedAt: row.updatedAt,
    );
  }

  List<String> _decodeList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {
      // Data rusak diperlakukan sebagai daftar kosong.
    }
    return const [];
  }

  String _remoteIdOf(String entityId) {
    final prefix = '$id:';
    return entityId.startsWith(prefix)
        ? entityId.substring(prefix.length)
        : entityId;
  }

  int _compareChapters(Chapter a, Chapter b) {
    final an = a.chapterNumber;
    final bn = b.chapterNumber;
    if (an != null && bn != null && an != bn) return an.compareTo(bn);
    return naturalCompare(a.title, b.title);
  }
}
