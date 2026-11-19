import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/sources/comic_source.dart';
import 'package:kleihon/data/sources/source_registry.dart';
import 'package:kleihon/domain/entities/chapter.dart';
import 'package:kleihon/domain/entities/comic.dart';
import 'package:kleihon/domain/entities/entity_id.dart';
import 'package:kleihon/domain/entities/source_results.dart';

/// HANYA UNTUK TEST. Bukan sumber nyata dan tidak dipakai di aplikasi.
class _FakeSource extends ComicSource {
  _FakeSource(this.id);

  @override
  final String id;

  @override
  String get name => 'Fake $id';

  @override
  Set<SourceCapability> get capabilities => {SourceCapability.search};

  @override
  Future<Comic> getComicDetail(String comicId) async => Comic(
        sourceId: id,
        remoteId: comicId,
        title: 'Test',
        sourceUrl: 'https://example.invalid/$comicId',
      );

  @override
  Future<PagedResult<Chapter>> getChapters(String comicId, int page) async =>
      PagedResult(items: const [], page: page, hasNext: false);

  @override
  Future<List<ChapterPage>> getChapterPages(String chapterId) async => [];
}

void main() {
  test('sumber terdaftar bisa dicari lewat id', () {
    final registry = SourceRegistry([_FakeSource('a'), _FakeSource('b')]);
    expect(registry.byId('a')?.id, 'a');
    expect(registry.require('b').id, 'b');
    expect(registry.all, hasLength(2));
  });

  test('id sumber ganda ditolak', () {
    final registry = SourceRegistry([_FakeSource('a')]);
    expect(() => registry.register(_FakeSource('a')), throwsArgumentError);
  });

  test('sumber yang tidak ada menghasilkan null atau StateError', () {
    final registry = SourceRegistry();
    expect(registry.byId('x'), isNull);
    expect(() => registry.require('x'), throwsStateError);
  });

  test('fitur yang tidak di-override melempar SourceFeatureUnsupported', () {
    final source = _FakeSource('a');
    expect(source.getLatest(1), throwsA(isA<SourceFeatureUnsupported>()));
    expect(source.getHome(), throwsA(isA<SourceFeatureUnsupported>()));
    expect(source.getGenres(), throwsA(isA<SourceFeatureUnsupported>()));
  });

  test('supports membaca capabilities', () {
    final source = _FakeSource('a');
    expect(source.supports(SourceCapability.search), isTrue);
    expect(source.supports(SourceCapability.popular), isFalse);
  });

  test('id gabungan komik dan chapter konsisten', () {
    expect(makeEntityId('src', '42'), 'src:42');

    const chapter = Chapter(
      sourceId: 'src',
      comicRemoteId: 'c1',
      remoteId: 'ch9',
      title: 'Chapter 9',
      chapterUrl: 'https://example.invalid/ch9',
    );
    expect(chapter.id, 'src:ch9');
    expect(chapter.comicId, 'src:c1');
  });
}