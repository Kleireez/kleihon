import '../../core/errors/app_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/source_results.dart';
import '../../domain/repositories/comic_repository.dart';
import '../sources/comic_source.dart';
import '../sources/source_registry.dart';

class ComicRepositoryImpl implements ComicRepository {
  ComicRepositoryImpl(this._registry);

  final SourceRegistry _registry;

  @override
  bool supports(String sourceId, SourceCapability capability) =>
      _registry.byId(sourceId)?.supports(capability) ?? false;

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
  Future<PagedResult<Comic>> search({
    required String sourceId,
    required String query,
    required int page,
  }) => _guard(() => _source(sourceId).search(query, page));

  @override
  Future<Comic> getComicDetail({
    required String sourceId,
    required String comicRemoteId,
  }) => _guard(() => _source(sourceId).getComicDetail(comicRemoteId));

  @override
  Future<PagedResult<Chapter>> getChapters({
    required String sourceId,
    required String comicRemoteId,
    required int page,
  }) => _guard(() => _source(sourceId).getChapters(comicRemoteId, page));

  @override
  Future<List<ChapterPage>> getChapterPages({
    required String sourceId,
    required String chapterRemoteId,
  }) => _guard(() => _source(sourceId).getChapterPages(chapterRemoteId));

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
