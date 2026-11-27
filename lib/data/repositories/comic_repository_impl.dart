import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/errors/app_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/entity_id.dart';
import '../../domain/entities/source_results.dart';
import '../../domain/repositories/comic_repository.dart';
import '../database/app_database.dart' as db;
import '../local/local_library_layout.dart';
import '../sources/comic_source.dart';
import '../sources/source_registry.dart';

class ComicRepositoryImpl implements ComicRepository {
  ComicRepositoryImpl(this._registry, {db.AppDatabase? database})
    : _db = database;

  final SourceRegistry _registry;
  final db.AppDatabase? _db;

  @override
  bool supports(String sourceId, SourceCapability capability) =>
      _registry.byId(sourceId)?.supports(capability) ?? false;

  @override
  Future<HomeData> getHome({required String sourceId}) =>
      _guard(() => _source(sourceId).getHome());

  @override
  Future<PagedResult<Comic>> getLatest({
    required String sourceId,
    required int page,
  }) => _guard(() => _source(sourceId).getLatest(page));

  @override
  Future<PagedResult<Comic>> getPopular({
    required String sourceId,
    required int page,
  }) => _guard(() => _source(sourceId).getPopular(page));

  @override
  Future<List<Genre>> getGenres({required String sourceId}) =>
      _guard(() => _source(sourceId).getGenres());

  @override
  Future<PagedResult<Comic>> getComicsByGenre({
    required String sourceId,
    required String genreId,
    required int page,
  }) => _guard(() => _source(sourceId).getComicsByGenre(genreId, page));

  @override
  Future<PagedResult<Comic>> search({
    required String sourceId,
    required String query,
    required int page,
  }) => _guard(() => _source(sourceId).search(query, page));

  @override
  Future<Comic> getComicDetail({
    required String sourceId,
    required String comicRemoteId,
  }) => _guard(() async {
    final comic = await _source(sourceId).getComicDetail(comicRemoteId);
    if (sourceId != localSourceId) {
      await _cacheComic(comic);
    }
    return comic;
  });

  @override
  Future<PagedResult<Chapter>> getChapters({
    required String sourceId,
    required String comicRemoteId,
    required int page,
  }) => _guard(() async {
    final result = await _source(sourceId).getChapters(comicRemoteId, page);
    if (sourceId != localSourceId && result.items.isNotEmpty) {
      await _cacheChapters(sourceId, comicRemoteId, result.items);
    }
    return result;
  });

  @override
  Future<List<ChapterPage>> getChapterPages({
    required String sourceId,
    required String chapterRemoteId,
  }) => _guard(() => _source(sourceId).getChapterPages(chapterRemoteId));

  Future<void> _cacheComic(Comic comic) async {
    final database = _db;
    if (database == null) return;
    try {
      await database
          .into(database.comics)
          .insertOnConflictUpdate(
            db.ComicsCompanion.insert(
              id: comic.id,
              sourceId: comic.sourceId,
              remoteId: comic.remoteId,
              title: comic.title,
              alternativeTitlesJson: Value(
                jsonEncode(comic.alternativeTitles),
              ),
              coverUrl: Value(comic.coverUrl),
              synopsis: Value(comic.synopsis),
              author: Value(comic.author),
              artist: Value(comic.artist),
              status: Value(comic.status),
              type: Value(comic.type),
              genresJson: Value(jsonEncode(comic.genres)),
              rating: Value(comic.rating),
              sourceUrl: comic.sourceUrl,
              updatedAt: Value(comic.updatedAt),
              cachedAt: Value(DateTime.now()),
            ),
          );
    } catch (e, s) {
      appLogger.w('Gagal menyimpan cache komik', error: e, stackTrace: s);
    }
  }

  Future<void> _cacheChapters(
    String sourceId,
    String comicRemoteId,
    List<Chapter> chapters,
  ) async {
    final database = _db;
    if (database == null) return;
    try {
      final comicId = makeEntityId(sourceId, comicRemoteId);
      final exists =
          await (database.select(database.comics)
                ..where((t) => t.id.equals(comicId)))
              .getSingleOrNull();
      if (exists == null) return;

      final now = DateTime.now();
      await database.batch((batch) {
        batch.insertAllOnConflictUpdate(database.chapters, [
          for (final chapter in chapters)
            db.ChaptersCompanion.insert(
              id: chapter.id,
              comicId: chapter.comicId,
              title: chapter.title,
              chapterNumber: Value(chapter.chapterNumber),
              chapterUrl: chapter.chapterUrl,
              publishedAt: Value(chapter.publishedAt),
              cachedAt: Value(now),
            ),
        ]);
      });
    } catch (e, s) {
      appLogger.w('Gagal menyimpan cache chapter', error: e, stackTrace: s);
    }
  }

  ComicSource _source(String sourceId) {
    final source = _registry.byId(sourceId);
    if (source == null) {
      throw AppException(
        AppErrorType.notFound,
        debugMessage: 'Sumber tidak terdaftar: $sourceId',
      );
    }
    return source;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } on SourceFeatureUnsupported catch (e) {
      throw AppException(AppErrorType.unsupported, debugMessage: e.toString());
    } catch (e, stack) {
      appLogger.e(
        'Kegagalan tak terduga dari sumber',
        error: e,
        stackTrace: stack,
      );
      throw AppException(AppErrorType.unknown, debugMessage: e.toString());
    }
  }
}
