import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/core/network/dio_client.dart';
import 'package:kleihon/data/sources/comic_source.dart';
import 'package:kleihon/data/sources/mangadex_source.dart';

typedef _Responder =
    ResponseBody Function(RequestOptions options);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final _Responder handler;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }
}

ResponseBody _json(Object body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

void main() {
  test('kapabilitas MangaDex mencakup latest, popular, dan search', () {
    final source = MangaDexSource();
    expect(source.id, mangaDexSourceId);
    expect(source.supports(SourceCapability.latest), isTrue);
    expect(source.supports(SourceCapability.popular), isTrue);
    expect(source.supports(SourceCapability.search), isTrue);
  });

  test('getLatest dan getPopular memetakan manhwa, sampul, dan genre', () async {
    final client = DioClient(baseUrl: 'https://api.mangadex.org');
    final adapter = _FakeAdapter((options) {
      return _json({
        'total': 25,
        'data': [
          {
            'id': 'm1',
            'attributes': {
              'title': {'en': 'Solo Leveling'},
              'altTitles': [
                {'ko-ro': 'Na Honjaman Level Up'},
              ],
              'description': {
                'id':
                    '**Sinopsis** Indonesia oleh [Resmi](https://example.org)\n---\nLinks: https://example.org',
              },
              'originalLanguage': 'ko',
              'status': 'completed',
              'updatedAt': '2026-11-20T10:00:00+00:00',
              'tags': [
                {
                  'attributes': {
                    'name': {'en': 'Action'},
                  },
                },
              ],
            },
            'relationships': [
              {
                'type': 'cover_art',
                'attributes': {'fileName': 'cover.jpg'},
              },
              {
                'type': 'author',
                'attributes': {'name': 'Chugong'},
              },
            ],
          },
        ],
      });
    });
    client.dio.httpClientAdapter = adapter;

    final source = MangaDexSource(client: client);
    final latest = await source.getLatest(1);
    expect(latest.hasNext, isTrue);
    expect(latest.items, hasLength(1));

    final comic = latest.items.single;
    expect(comic.title, 'Solo Leveling');
    expect(comic.type, 'Manhwa');
    expect(comic.status, 'Tamat');
    expect(comic.author, 'Chugong');
    expect(comic.genres, ['Action']);
    expect(comic.synopsis, 'Sinopsis Indonesia oleh Resmi');
    expect(
      comic.coverUrl,
      'https://uploads.mangadex.org/covers/m1/cover.jpg.512.jpg',
    );
    expect(
      adapter.requests.single.headers['User-Agent'],
      startsWith('KleiHon/'),
    );

    final popular = await source.getPopular(1);
    expect(popular.items.single.remoteId, 'm1');
    expect(
      adapter.requests.last.queryParameters['order[followedCount]'],
      'desc',
    );
  });

  test('getChapters menyertakan kredit grup dan menyaring chapter eksternal', () async {
    final client = DioClient(baseUrl: 'https://api.mangadex.org');
    client.dio.httpClientAdapter = _FakeAdapter((options) {
      return _json({
        'total': 2,
        'data': [
          {
            'id': 'c1',
            'attributes': {
              'chapter': '1',
              'title': 'Awal',
              'translatedLanguage': 'id',
              'pages': 18,
              'publishAt': '2026-11-20T00:00:00+00:00',
            },
            'relationships': [
              {
                'type': 'scanlation_group',
                'attributes': {'name': 'Grup Nusantara'},
              },
            ],
          },
          {
            'id': 'c2',
            'attributes': {
              'chapter': '2',
              'translatedLanguage': 'en',
              'pages': 0,
              'externalUrl': 'https://example.invalid/ch2',
            },
          },
        ],
      });
    });

    final source = MangaDexSource(client: client);
    final chapters = await source.getChapters('m1', 1);
    expect(chapters.hasNext, isFalse);
    expect(chapters.items, hasLength(1));
    expect(
      chapters.items.single.title,
      'Ch. 1 - Awal [ID] • Grup Nusantara',
    );
    expect(chapters.items.single.chapterNumber, 1);
  });

  test('getChapterPages membangun URL data dan fallback data-saver', () async {
    final client = DioClient(baseUrl: 'https://api.mangadex.org');
    var useSaver = false;
    client.dio.httpClientAdapter = _FakeAdapter((options) {
      return _json({
        'baseUrl': 'https://cdn.example.org/',
        'chapter': {
          'hash': 'abc123',
          'data': useSaver ? [] : ['1.jpg', '2.jpg'],
          'dataSaver': ['s1.jpg'],
        },
      });
    });

    final source = MangaDexSource(client: client);
    final pages = await source.getChapterPages('c1');
    expect(pages.map((p) => p.imageUrl), [
      'https://cdn.example.org/data/abc123/1.jpg',
      'https://cdn.example.org/data/abc123/2.jpg',
    ]);

    useSaver = true;
    final saverPages = await source.getChapterPages('c1');
    expect(saverPages.map((p) => p.imageUrl), [
      'https://cdn.example.org/data-saver/abc123/s1.jpg',
    ]);
  });

  test('respons 429 dipetakan ke accessDenied', () async {
    final client = DioClient(baseUrl: 'https://api.mangadex.org');
    client.dio.httpClientAdapter = _FakeAdapter(
      (options) => _json({'result': 'error'}, status: 429),
    );

    final source = MangaDexSource(client: client);
    await expectLater(
      source.getLatest(1),
      throwsA(
        isA<AppException>().having(
          (e) => e.type,
          'type',
          AppErrorType.accessDenied,
        ),
      ),
    );
  });
}
