import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/data/repositories/comic_repository_impl.dart';
import 'package:kleihon/data/sources/comic_source.dart';
import 'package:kleihon/data/sources/source_registry.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/domain/usecases/comic_usecases.dart';

import '../helpers/fake_comic_source.dart';

void main() {
  test('SearchComics tidak mengirim request untuk kata kunci kosong', () async {
    var calls = 0;
    String? lastQuery;
    final repository = ComicRepositoryImpl(
      SourceRegistry([
        FakeComicSource(
          's',
          capabilities: {SourceCapability.search},
          onSearch: (query, page) async {
            calls++;
            lastQuery = query;
            return PagedResult(items: const [], page: page, hasNext: false);
          },
        ),
      ]),
    );
    final search = SearchComics(repository);

    final empty = await search(sourceId: 's', query: '   ');
    expect(empty.items, isEmpty);
    expect(calls, 0);

    await search(sourceId: 's', query: '  abc ');
    expect(calls, 1);
    expect(lastQuery, 'abc');
  });

  test('GetAllChapters menggabungkan semua halaman berurutan', () async {
    final repository = ComicRepositoryImpl(
      SourceRegistry([
        FakeComicSource(
          's',
          onChapters: (comicId, page) async {
            final items = {
              1: [
                testChapter('s', comicId, 'c1'),
                testChapter('s', comicId, 'c2'),
              ],
              2: [testChapter('s', comicId, 'c3')],
              3: [testChapter('s', comicId, 'c4')],
            }[page]!;
            return PagedResult(items: items, page: page, hasNext: page < 3);
          },
        ),
      ]),
    );

    final chapters = await GetAllChapters(repository)(
      sourceId: 's',
      comicRemoteId: 'k',
    );
    expect(chapters.map((c) => c.remoteId).toList(), ['c1', 'c2', 'c3', 'c4']);
  });

  test(
    'GetAllChapters berhenti dengan error jika paginasi tak berakhir',
    () async {
      var calls = 0;
      final repository = ComicRepositoryImpl(
        SourceRegistry([
          FakeComicSource(
            's',
            onChapters: (comicId, page) async {
              calls++;
              return PagedResult(
                items: [testChapter('s', comicId, 'c$page')],
                page: page,
                hasNext: true,
              );
            },
          ),
        ]),
      );

      await expectLater(
        GetAllChapters(repository, maxPages: 3)(
          sourceId: 's',
          comicRemoteId: 'k',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.type,
            'type',
            AppErrorType.parsing,
          ),
        ),
      );
      expect(calls, 3);
    },
  );
}
