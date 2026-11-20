import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/sources/comic_source.dart';
import 'package:kleihon/data/sources/source_providers.dart';
import 'package:kleihon/data/sources/source_registry.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/features/home/home_providers.dart';
import 'package:kleihon/shared/providers/library_revision_provider.dart';

import '../helpers/fake_comic_source.dart';

ProviderContainer makeContainer(FakeComicSource source) {
  final container = ProviderContainer(
    overrides: [
      sourceRegistryProvider.overrideWithValue(SourceRegistry([source])),
    ],
  );
  addTearDown(container.dispose);
  // Menjaga provider autoDispose tetap hidup selama test.
  container.listen(homeLatestProvider, (previous, next) {});
  return container;
}

void main() {
  test('jumlah komik di Home dibatasi', () async {
    final container = makeContainer(
      FakeComicSource(
        'local',
        capabilities: {SourceCapability.latest},
        onLatest: (page) async => PagedResult(
          items: [for (var i = 0; i < 15; i++) testComic('local', 'k$i')],
          page: page,
          hasNext: true,
        ),
      ),
    );

    final items = await container.read(homeLatestProvider.future);
    expect(items, hasLength(homeSectionLimit));
    expect(items!.first.remoteId, 'k0');
  });

  test('bernilai null jika sumber tidak mendukung daftar terbaru', () async {
    final container = makeContainer(FakeComicSource('local'));

    expect(await container.read(homeLatestProvider.future), isNull);
  });

  test('dimuat ulang saat perpustakaan berubah', () async {
    var calls = 0;
    final container = makeContainer(
      FakeComicSource(
        'local',
        capabilities: {SourceCapability.latest},
        onLatest: (page) async {
          final version = calls++;
          return PagedResult(
            items: [testComic('local', 'v$version')],
            page: page,
            hasNext: false,
          );
        },
      ),
    );

    final first = await container.read(homeLatestProvider.future);
    expect(first!.single.remoteId, 'v0');

    container.read(libraryRevisionProvider.notifier).bump();

    final second = await container.read(homeLatestProvider.future);
    expect(second!.single.remoteId, 'v1');
  });
}
