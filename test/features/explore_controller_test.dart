import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/data/sources/comic_source.dart';
import 'package:kleihon/data/sources/source_providers.dart';
import 'package:kleihon/data/sources/source_registry.dart';
import 'package:kleihon/domain/entities/comic.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/features/explore/explore_controller.dart';

import '../helpers/fake_comic_source.dart';

/// Memberi kesempatan semua Future dan Timer bernilai nol selesai.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

PagedResult<Comic> pageOf(List<String> ids, int page, {bool hasNext = false}) =>
    PagedResult(
      items: [for (final id in ids) testComic('local', id)],
      page: page,
      hasNext: hasNext,
    );

ProviderContainer makeContainer(FakeComicSource source) {
  final container = ProviderContainer(
    overrides: [
      sourceRegistryProvider.overrideWithValue(SourceRegistry([source])),
      exploreDebounceProvider.overrideWithValue(Duration.zero),
    ],
  );
  addTearDown(container.dispose);
  // Menjaga provider autoDispose tetap hidup selama test.
  container.listen(exploreControllerProvider, (previous, next) {});
  return container;
}

const _caps = {SourceCapability.latest, SourceCapability.search};

void main() {
  test('memuat daftar terbaru saat dibuka', () async {
    final container = makeContainer(
      FakeComicSource(
        'local',
        capabilities: _caps,
        onLatest: (page) async => pageOf(['a', 'b'], page),
      ),
    );
    await settle();

    final state = container.read(exploreControllerProvider);
    expect(state.loading, isFalse);
    expect(state.items.map((c) => c.remoteId).toList(), ['a', 'b']);
    expect(state.error, isNull);
  });

  test('loadMore menambah halaman dan membuang duplikat', () async {
    final container = makeContainer(
      FakeComicSource(
        'local',
        capabilities: _caps,
        onLatest: (page) async => page == 1
            ? pageOf(['a', 'b'], 1, hasNext: true)
            : pageOf(['b', 'c'], 2),
      ),
    );
    await settle();

    await container.read(exploreControllerProvider.notifier).loadMore();

    final state = container.read(exploreControllerProvider);
    expect(state.items.map((c) => c.remoteId).toList(), ['a', 'b', 'c']);
    expect(state.hasNext, isFalse);
    expect(state.page, 2);
  });

  test(
    'pencarian mengganti daftar dan kata kosong kembali ke terbaru',
    () async {
      final container = makeContainer(
        FakeComicSource(
          'local',
          capabilities: _caps,
          onLatest: (page) async => pageOf(['a'], page),
          onSearch: (query, page) async => pageOf(['q-$query'], page),
        ),
      );
      await settle();
      final notifier = container.read(exploreControllerProvider.notifier);

      notifier.setQuery('  abc ');
      await settle();
      var state = container.read(exploreControllerProvider);
      expect(state.query, 'abc');
      expect(state.items.map((c) => c.remoteId).toList(), ['q-abc']);

      notifier.setQuery('');
      await settle();
      state = container.read(exploreControllerProvider);
      expect(state.query, '');
      expect(state.items.map((c) => c.remoteId).toList(), ['a']);
    },
  );

  test('jawaban pencarian yang usang diabaikan', () async {
    final slow = Completer<PagedResult<Comic>>();
    final container = makeContainer(
      FakeComicSource(
        'local',
        capabilities: _caps,
        onLatest: (page) async => pageOf(['a'], page),
        onSearch: (query, page) => query == 'lambat'
            ? slow.future
            : Future.value(pageOf(['cepat'], page)),
      ),
    );
    await settle();
    final notifier = container.read(exploreControllerProvider.notifier);

    notifier.setQuery('lambat');
    await settle();
    notifier.setQuery('cepat');
    await settle();

    slow.complete(pageOf(['hasil-lambat'], 1));
    await settle();

    final state = container.read(exploreControllerProvider);
    expect(state.query, 'cepat');
    expect(state.items.map((c) => c.remoteId).toList(), ['cepat']);
  });

  test('gagal memuat halaman pertama lalu pulih lewat refresh', () async {
    var fail = true;
    final container = makeContainer(
      FakeComicSource(
        'local',
        capabilities: _caps,
        onLatest: (page) async {
          if (fail) throw const AppException(AppErrorType.timeout);
          return pageOf(['a'], page);
        },
      ),
    );
    await settle();

    var state = container.read(exploreControllerProvider);
    expect(state.error?.type, AppErrorType.timeout);
    expect(state.items, isEmpty);
    expect(state.loading, isFalse);

    fail = false;
    await container.read(exploreControllerProvider.notifier).refresh();

    state = container.read(exploreControllerProvider);
    expect(state.error, isNull);
    expect(state.items.map((c) => c.remoteId).toList(), ['a']);
  });

  test('gagal memuat halaman berikutnya mempertahankan daftar', () async {
    var page2Calls = 0;
    var failPage2 = true;
    final container = makeContainer(
      FakeComicSource(
        'local',
        capabilities: _caps,
        onLatest: (page) async {
          if (page == 1) return pageOf(['a'], 1, hasNext: true);
          page2Calls++;
          if (failPage2) throw const AppException(AppErrorType.server);
          return pageOf(['b'], 2);
        },
      ),
    );
    await settle();
    final notifier = container.read(exploreControllerProvider.notifier);

    await notifier.loadMore();
    var state = container.read(exploreControllerProvider);
    expect(state.moreError?.type, AppErrorType.server);
    expect(state.items.map((c) => c.remoteId).toList(), ['a']);
    expect(page2Calls, 1);

    // Tidak mencoba ulang sendiri selama masih ada error.
    await notifier.loadMore();
    expect(page2Calls, 1);

    failPage2 = false;
    await notifier.retryLoadMore();
    state = container.read(exploreControllerProvider);
    expect(state.moreError, isNull);
    expect(state.items.map((c) => c.remoteId).toList(), ['a', 'b']);
  });
}
