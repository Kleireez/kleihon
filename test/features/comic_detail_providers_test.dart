import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/data/sources/source_providers.dart';
import 'package:kleihon/data/sources/source_registry.dart';
import 'package:kleihon/domain/entities/comic.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/features/comic_detail/comic_detail_providers.dart';
import 'package:kleihon/shared/providers/library_revision_provider.dart';

import '../helpers/fake_comic_source.dart';

/// HANYA UNTUK TEST: komik yang tidak ditemukan.
class _MissingComicSource extends FakeComicSource {
  _MissingComicSource() : super('local');

  @override
  Future<Comic> getComicDetail(String comicId) async =>
      throw const AppException(AppErrorType.notFound);
}

const ComicKey _key = (sourceId: 'local', comicId: 'k1');

ProviderContainer makeContainer(FakeComicSource source) {
  final container = ProviderContainer(
    // Tanpa pengulangan otomatis, seperti di aplikasi.
    retry: (retryCount, error) => null,
    overrides: [
      sourceRegistryProvider.overrideWithValue(SourceRegistry([source])),
    ],
  );
  addTearDown(container.dispose);
  // Menjaga provider autoDispose tetap hidup selama test.
  container.listen(comicDetailProvider(_key), (previous, next) {});
  return container;
}

void main() {
  test('memuat komik dan chapter sesuai urutan dari sumber', () async {
    final container = makeContainer(
      FakeComicSource(
        'local',
        onChapters: (comicId, page) async => PagedResult(
          items: [
            testChapter('local', comicId, 'c1'),
            testChapter('local', comicId, 'c2'),
          ],
          page: page,
          hasNext: false,
        ),
      ),
    );

    final data = await container.read(comicDetailProvider(_key).future);
    expect(data.comic.remoteId, 'k1');
    expect(data.comic.title, 'Judul k1');
    expect(data.chapters.map((c) => c.remoteId).toList(), ['c1', 'c2']);
  });

  test('error dari sumber diteruskan sebagai AppException', () async {
    final container = makeContainer(_MissingComicSource());

    await expectLater(
      container.read(comicDetailProvider(_key).future),
      throwsA(
        isA<AppException>().having(
          (e) => e.type,
          'type',
          AppErrorType.notFound,
        ),
      ),
    );
  });

  test('dimuat ulang saat perpustakaan berubah', () async {
    var calls = 0;
    final container = makeContainer(
      FakeComicSource(
        'local',
        onChapters: (comicId, page) async {
          final count = ++calls;
          return PagedResult(
            items: [
              for (var i = 0; i < count; i++)
                testChapter('local', comicId, 'c$i'),
            ],
            page: page,
            hasNext: false,
          );
        },
      ),
    );

    final first = await container.read(comicDetailProvider(_key).future);
    expect(first.chapters, hasLength(1));

    container.read(libraryRevisionProvider.notifier).bump();

    final second = await container.read(comicDetailProvider(_key).future);
    expect(second.chapters, hasLength(2));
  });
}
