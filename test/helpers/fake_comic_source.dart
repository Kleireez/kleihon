import 'package:kleihon/data/sources/comic_source.dart';
import 'package:kleihon/domain/entities/chapter.dart';
import 'package:kleihon/domain/entities/comic.dart';
import 'package:kleihon/domain/entities/source_results.dart';

Comic testComic(String sourceId, String remoteId, [String? title]) => Comic(
  sourceId: sourceId,
  remoteId: remoteId,
  title: title ?? 'Judul $remoteId',
  sourceUrl: 'https://example.invalid/$remoteId',
);
Comic testComicWithAlternatives(String title, List<String> alternatives) =>
    Comic(
      sourceId: 's',
      remoteId: title.toLowerCase(),
      title: title,
      sourceUrl: 'https://example.invalid/${title.toLowerCase()}',
      alternativeTitles: alternatives,
    );
Chapter testChapter(String sourceId, String comicRemoteId, String remoteId) =>
    Chapter(
      sourceId: sourceId,
      comicRemoteId: comicRemoteId,
      remoteId: remoteId,
      title: 'Chapter $remoteId',
      chapterUrl: 'https://example.invalid/$comicRemoteId/$remoteId',
    );

/// HANYA UNTUK TEST. Perilaku diatur lewat callback. Tanpa callback,
/// fitur opsional bersifat tidak didukung seperti ComicSource asli.
class FakeComicSource extends ComicSource {
  FakeComicSource(
    this.id, {
    this.capabilities = const {},
    this.onLatest,
    this.onSearch,
    this.onChapters,
    this.onPages,
  });

  @override
  final String id;

  @override
  final Set<SourceCapability> capabilities;

  final Future<PagedResult<Comic>> Function(int page)? onLatest;
  final Future<PagedResult<Comic>> Function(String query, int page)? onSearch;
  final Future<PagedResult<Chapter>> Function(String comicId, int page)?
  onChapters;
  final Future<List<ChapterPage>> Function(String chapterId)? onPages;

  @override
  String get name => 'Fake $id';

  @override
  Future<PagedResult<Comic>> getLatest(int page) =>
      onLatest != null ? onLatest!(page) : super.getLatest(page);

  @override
  Future<PagedResult<Comic>> search(String query, int page) =>
      onSearch != null ? onSearch!(query, page) : super.search(query, page);

  @override
  Future<Comic> getComicDetail(String comicId) async => testComic(id, comicId);

  @override
  Future<PagedResult<Chapter>> getChapters(String comicId, int page) async =>
      onChapters != null
      ? onChapters!(comicId, page)
      : PagedResult(items: const [], page: page, hasNext: false);

  @override
  Future<List<ChapterPage>> getChapterPages(String chapterId) async =>
      onPages != null ? onPages!(chapterId) : [];
}
