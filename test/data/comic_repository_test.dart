import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/data/repositories/comic_repository_impl.dart';
import 'package:kleihon/data/sources/comic_source.dart';
import 'package:kleihon/data/sources/source_registry.dart';
import 'package:kleihon/domain/entities/source_results.dart';

import '../helpers/fake_comic_source.dart';

void main() {
  late ComicRepositoryImpl repository;

  PagedResult<T> single<T>(List<T> items, int page) =>
      PagedResult(items: items, page: page, hasNext: false);

  setUp(() {
    repository = ComicRepositoryImpl(
      SourceRegistry([
        FakeComicSource(
          'a',
          capabilities: {SourceCapability.latest},
          onLatest: (page) async =>
              single([testComic('a', '1', 'Dari A')], page),
        ),
        FakeComicSource(
          'b',
          capabilities: {SourceCapability.latest},
          onLatest: (page) async =>
              single([testComic('b', '1', 'Dari B')], page),
        ),
        FakeComicSource('plain'),
        FakeComicSource(
          'rusak',
          onLatest: (_) async =>
              throw const FormatException('rahasia-internal'),
        ),
        FakeComicSource(
          'app',
          onLatest: (_) async => throw const AppException(AppErrorType.timeout),
        ),
      ]),
    );
  });

  Matcher appError(AppErrorType type) =>
      throwsA(isA<AppException>().having((e) => e.type, 'type', type));

  test('permintaan diteruskan ke sumber yang tepat', () async {
    final a = await repository.getLatest(sourceId: 'a', page: 1);
    final b = await repository.getLatest(sourceId: 'b', page: 1);
    expect(a.items.single.title, 'Dari A');
    expect(b.items.single.title, 'Dari B');
  });

  test('sumber yang tidak terdaftar menghasilkan notFound', () async {
    await expectLater(
      repository.getLatest(sourceId: 'hantu', page: 1),
      appError(AppErrorType.notFound),
    );
  });

  test('fitur yang tidak didukung menghasilkan unsupported', () async {
    await expectLater(
      repository.getLatest(sourceId: 'plain', page: 1),
      appError(AppErrorType.unsupported),
    );
    await expectLater(
      repository.search(sourceId: 'plain', query: 'x', page: 1),
      appError(AppErrorType.unsupported),
    );
  });

  test('AppException dari sumber diteruskan apa adanya', () async {
    await expectLater(
      repository.getLatest(sourceId: 'app', page: 1),
      appError(AppErrorType.timeout),
    );
  });

  test('error tak terduga menjadi unknown tanpa membocorkan detail', () async {
    try {
      await repository.getLatest(sourceId: 'rusak', page: 1);
      fail('seharusnya melempar AppException');
    } on AppException catch (e) {
      expect(e.type, AppErrorType.unknown);
      expect(e.userMessage.contains('rahasia-internal'), isFalse);
      expect(e.debugMessage, contains('rahasia-internal'));
    }
  });

  test('supports membaca kemampuan sumber', () {
    expect(repository.supports('a', SourceCapability.latest), isTrue);
    expect(repository.supports('a', SourceCapability.popular), isFalse);
    expect(repository.supports('hantu', SourceCapability.latest), isFalse);
  });
}
