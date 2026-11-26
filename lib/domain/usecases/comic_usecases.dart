import '../../core/errors/app_exception.dart';
import '../entities/chapter.dart';
import '../entities/comic.dart';
import '../entities/source_results.dart';
import '../repositories/comic_repository.dart';

class GetLatestComics {
  const GetLatestComics(this._repository);

  final ComicRepository _repository;

  Future<PagedResult<Comic>> call({required String sourceId, int page = 1}) =>
      _repository.getLatest(sourceId: sourceId, page: page);
}

class GetPopularComics {
  const GetPopularComics(this._repository);

  final ComicRepository _repository;

  Future<PagedResult<Comic>> call({required String sourceId, int page = 1}) =>
      _repository.getPopular(sourceId: sourceId, page: page);
}

class SearchComics {
  const SearchComics(this._repository);

  final ComicRepository _repository;

  /// Kata kunci kosong tidak mengirim request apa pun.
  Future<PagedResult<Comic>> call({
    required String sourceId,
    required String query,
    int page = 1,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return PagedResult(items: const [], page: page, hasNext: false);
    }
    return _repository.search(sourceId: sourceId, query: trimmed, page: page);
  }
}

class GetComicDetail {
  const GetComicDetail(this._repository);

  final ComicRepository _repository;

  Future<Comic> call({
    required String sourceId,
    required String comicRemoteId,
  }) => _repository.getComicDetail(
    sourceId: sourceId,
    comicRemoteId: comicRemoteId,
  );
}

/// Menggabungkan semua halaman daftar chapter menjadi satu daftar.
class GetAllChapters {
  const GetAllChapters(this._repository, {this.maxPages = 100});

  final ComicRepository _repository;
  final int maxPages;

  Future<List<Chapter>> call({
    required String sourceId,
    required String comicRemoteId,
  }) async {
    final all = <Chapter>[];
    for (var page = 1; page <= maxPages; page++) {
      final result = await _repository.getChapters(
        sourceId: sourceId,
        comicRemoteId: comicRemoteId,
        page: page,
      );
      all.addAll(result.items);
      if (!result.hasNext) return all;
    }
    throw AppException(
      AppErrorType.parsing,
      debugMessage: 'Paginasi chapter tidak berakhir setelah $maxPages halaman',
    );
  }
}

class GetChapterPages {
  const GetChapterPages(this._repository);

  final ComicRepository _repository;

  Future<List<ChapterPage>> call({
    required String sourceId,
    required String chapterRemoteId,
  }) => _repository.getChapterPages(
    sourceId: sourceId,
    chapterRemoteId: chapterRemoteId,
  );
}
