import '../../domain/entities/chapter.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/source_results.dart';

enum SourceCapability {
  home,
  latest,
  popular,
  search,
  genres,
  comicsByGenre,
}

/// Dilempar kalau sumber tidak menyediakan fitur yang diminta.
class SourceFeatureUnsupported implements Exception {
  const SourceFeatureUnsupported(this.sourceId, this.feature);

  final String sourceId;
  final String feature;

  @override
  String toString() => 'SourceFeatureUnsupported($sourceId, $feature)';
}

/// Kontrak sumber komik. Semua komunikasi dengan sumber lewat sini.
/// Parameter comicId dan chapterId adalah ID dari sumber (remoteId).
abstract class ComicSource {
  String get id;
  String get name;
  Set<SourceCapability> get capabilities;

  bool supports(SourceCapability capability) =>
      capabilities.contains(capability);

  // Wajib: tanpa ini komik tidak bisa dibaca.
  Future<Comic> getComicDetail(String comicId);
  Future<PagedResult<Chapter>> getChapters(String comicId, int page);
  Future<List<ChapterPage>> getChapterPages(String chapterId);

  // Opsional: adapter hanya meng-override yang benar-benar tersedia.
  Future<HomeData> getHome() async =>
      throw SourceFeatureUnsupported(id, 'getHome');

  Future<PagedResult<Comic>> getLatest(int page) async =>
      throw SourceFeatureUnsupported(id, 'getLatest');

  Future<PagedResult<Comic>> getPopular(int page) async =>
      throw SourceFeatureUnsupported(id, 'getPopular');

  Future<PagedResult<Comic>> search(String query, int page) async =>
      throw SourceFeatureUnsupported(id, 'search');

  Future<List<Genre>> getGenres() async =>
      throw SourceFeatureUnsupported(id, 'getGenres');

  Future<PagedResult<Comic>> getComicsByGenre(String genreId, int page) async =>
      throw SourceFeatureUnsupported(id, 'getComicsByGenre');
}