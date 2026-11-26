import '../entities/chapter.dart';
import '../entities/comic.dart';
import '../entities/source_capability.dart';
import '../entities/source_results.dart';

/// Pintu masuk data komik untuk lapisan UI. Semua kegagalan dilempar
/// sebagai AppException.
abstract class ComicRepository {
  bool supports(String sourceId, SourceCapability capability);

  Future<PagedResult<Comic>> getLatest({
    required String sourceId,
    required int page,
  });

  Future<PagedResult<Comic>> getPopular({
    required String sourceId,
    required int page,
  });

  Future<PagedResult<Comic>> search({
    required String sourceId,
    required String query,
    required int page,
  });

  Future<Comic> getComicDetail({
    required String sourceId,
    required String comicRemoteId,
  });

  Future<PagedResult<Chapter>> getChapters({
    required String sourceId,
    required String comicRemoteId,
    required int page,
  });

  Future<List<ChapterPage>> getChapterPages({
    required String sourceId,
    required String chapterRemoteId,
  });
}
