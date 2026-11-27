import 'package:dio/dio.dart';

import '../../core/constants/app_info.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/source_results.dart';
import 'comic_source.dart';

const String mangaDexSourceId = 'mangadex';

/// Sumber komik online resmi menggunakan MangaDex API v5 (https://api.mangadex.org).
class MangaDexSource extends ComicSource {
  MangaDexSource({DioClient? client})
    : _client = client ?? DioClient(baseUrl: _apiBaseUrl);

  static const String _apiBaseUrl = 'https://api.mangadex.org';
  static const String _coverBaseUrl = 'https://uploads.mangadex.org/covers';
  static const int _comicPageSize = 20;
  static const int _chapterPageSize = 100;

  final DioClient _client;

  Options get _requestOptions => Options(
    headers: const {'User-Agent': 'KleiHon/$appVersion'},
  );

  @override
  String get id => mangaDexSourceId;

  @override
  String get name => 'MangaDex';

  @override
  Set<SourceCapability> get capabilities => const {
    SourceCapability.home,
    SourceCapability.latest,
    SourceCapability.popular,
    SourceCapability.search,
    SourceCapability.genres,
  };

  @override
  Future<HomeData> getHome() async {
    final recommended = await _fetchMangaList(
      page: 1,
      queryParameters: const {
        'order[rating]': 'desc',
        'hasAvailableChapters': 'true',
      },
    );
    return HomeData(recommended: recommended.items);
  }

  @override
  Future<List<Genre>> getGenres() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/manga/tag',
      options: _requestOptions,
    );
    final body = response.data;
    final rawList = body?['data'];
    if (body == null || rawList is! List) {
      throw const AppException(
        AppErrorType.parsing,
        debugMessage: 'Respons tag MangaDex tidak valid',
      );
    }

    final genres = <Genre>[];
    for (final entry in rawList) {
      if (entry is! Map<String, dynamic>) continue;
      final tagId = entry['id'] as String?;
      final attrs = entry['attributes'] as Map<String, dynamic>?;
      final name = _pickLocalizedText(attrs?['name']);
      if (tagId != null && tagId.isNotEmpty && name != null) {
        genres.add(Genre(id: tagId, name: name));
      }
    }
    genres.sort((a, b) => a.name.compareTo(b.name));
    return genres;
  }

  @override
  Future<PagedResult<Comic>> getComicsByGenre(String genreId, int page) =>
      _fetchMangaList(
        page: page,
        queryParameters: {
          'includedTags[]': [genreId],
          'order[followedCount]': 'desc',
          'hasAvailableChapters': 'true',
        },
      );

  @override
  Future<PagedResult<Comic>> getLatest(int page) => _fetchMangaList(
    page: page,
    queryParameters: {
      'order[latestUploadedChapter]': 'desc',
      'hasAvailableChapters': 'true',
    },
  );

  @override
  Future<PagedResult<Comic>> getPopular(int page) => _fetchMangaList(
    page: page,
    queryParameters: {
      'order[followedCount]': 'desc',
      'hasAvailableChapters': 'true',
    },
  );

  @override
  Future<PagedResult<Comic>> search(String query, int page) => _fetchMangaList(
    page: page,
    queryParameters: {
      'title': query,
      'order[relevance]': 'desc',
    },
  );

  @override
  Future<Comic> getComicDetail(String comicId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/manga/$comicId',
      queryParameters: const {
        'includes[]': ['cover_art', 'author', 'artist'],
      },
      options: _requestOptions,
    );
    final body = response.data;
    final data = body?['data'];
    if (data is! Map<String, dynamic>) {
      throw const AppException(
        AppErrorType.parsing,
        debugMessage: 'Respons detail MangaDex tidak valid',
      );
    }
    return _toComic(data);
  }

  @override
  Future<PagedResult<Chapter>> getChapters(String comicId, int page) async {
    final offset = (page - 1) * _chapterPageSize;
    final response = await _client.get<Map<String, dynamic>>(
      '/manga/$comicId/feed',
      queryParameters: {
        'limit': _chapterPageSize,
        'offset': offset,
        'translatedLanguage[]': const ['id', 'en'],
        'order[volume]': 'asc',
        'order[chapter]': 'asc',
        'includes[]': const ['scanlation_group'],
        'contentRating[]': const ['safe', 'suggestive', 'erotica'],
        'includeEmptyPages': 0,
      },
      options: _requestOptions,
    );
    final body = response.data;
    final rawList = body?['data'];
    if (body == null || rawList is! List) {
      throw const AppException(
        AppErrorType.parsing,
        debugMessage: 'Respons feed chapter MangaDex tidak valid',
      );
    }

    final items = <Chapter>[];
    for (final entry in rawList) {
      if (entry is! Map<String, dynamic>) continue;
      final chapter = _toChapter(comicId, entry);
      if (chapter != null) items.add(chapter);
    }

    final total = (body['total'] as num?)?.toInt() ?? items.length;
    return PagedResult(
      items: items,
      page: page,
      hasNext: offset + _chapterPageSize < total,
    );
  }

  @override
  Future<List<ChapterPage>> getChapterPages(String chapterId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/at-home/server/$chapterId',
      options: _requestOptions,
    );
    final body = response.data;
    final baseUrl = body?['baseUrl'] as String?;
    final chapter = body?['chapter'];
    if (baseUrl == null || chapter is! Map<String, dynamic>) {
      throw const AppException(
        AppErrorType.parsing,
        debugMessage: 'Respons at-home MangaDex tidak valid',
      );
    }

    final hash = chapter['hash'] as String?;
    if (hash == null || hash.isEmpty) {
      throw const AppException(
        AppErrorType.parsing,
        debugMessage: 'Hash chapter MangaDex kosong',
      );
    }

    final rawData = chapter['data'];
    final rawSaver = chapter['dataSaver'];
    final useSaver = rawData is! List || rawData.isEmpty;
    final files = useSaver ? rawSaver : rawData;
    if (files is! List) {
      throw const AppException(
        AppErrorType.parsing,
        debugMessage: 'Daftar halaman MangaDex tidak valid',
      );
    }

    final quality = useSaver ? 'data-saver' : 'data';
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    return [
      for (var i = 0; i < files.length; i++)
        ChapterPage(
          index: i,
          imageUrl: '$cleanBase/$quality/$hash/${files[i]}',
        ),
    ];
  }

  Future<PagedResult<Comic>> _fetchMangaList({
    required int page,
    required Map<String, dynamic> queryParameters,
  }) async {
    final offset = (page - 1) * _comicPageSize;
    final response = await _client.get<Map<String, dynamic>>(
      '/manga',
      queryParameters: {
        'limit': _comicPageSize,
        'offset': offset,
        'includes[]': const ['cover_art', 'author', 'artist'],
        'availableTranslatedLanguage[]': const ['id', 'en'],
        'contentRating[]': const ['safe', 'suggestive'],
        ...queryParameters,
      },
      options: _requestOptions,
    );

    final body = response.data;
    final rawList = body?['data'];
    if (body == null || rawList is! List) {
      throw const AppException(
        AppErrorType.parsing,
        debugMessage: 'Respons daftar manga MangaDex tidak valid',
      );
    }

    final items = [
      for (final entry in rawList)
        if (entry is Map<String, dynamic>) _toComic(entry),
    ];
    final total = (body['total'] as num?)?.toInt() ?? items.length;
    return PagedResult(
      items: items,
      page: page,
      hasNext: offset + _comicPageSize < total,
    );
  }

  Comic _toComic(Map<String, dynamic> item) {
    final remoteId = item['id'] as String? ?? '';
    final attributes =
        item['attributes'] as Map<String, dynamic>? ?? const {};
    final relationships = item['relationships'] as List? ?? const [];

    String? coverFile;
    String? author;
    String? artist;
    for (final rel in relationships) {
      if (rel is! Map<String, dynamic>) continue;
      final type = rel['type'] as String?;
      final relAttrs = rel['attributes'] as Map<String, dynamic>?;
      if (relAttrs == null) continue;
      if (type == 'cover_art') {
        coverFile ??= relAttrs['fileName'] as String?;
      } else if (type == 'author') {
        author ??= relAttrs['name'] as String?;
      } else if (type == 'artist') {
        artist ??= relAttrs['name'] as String?;
      }
    }

    final title = _pickLocalizedText(attributes['title']) ?? 'Tanpa Judul';
    final rawSynopsis = _pickLocalizedText(attributes['description']);
    final synopsis = rawSynopsis == null ? null : _cleanSynopsis(rawSynopsis);

    final altTitles = <String>[];
    final rawAlts = attributes['altTitles'];
    if (rawAlts is List) {
      for (final alt in rawAlts) {
        final picked = _pickLocalizedText(alt);
        if (picked != null && picked != title && !altTitles.contains(picked)) {
          altTitles.add(picked);
        }
      }
    }

    final genres = <String>[];
    final rawTags = attributes['tags'];
    if (rawTags is List) {
      for (final tag in rawTags) {
        if (tag is! Map<String, dynamic>) continue;
        final tagAttrs = tag['attributes'] as Map<String, dynamic>?;
        final name = _pickLocalizedText(tagAttrs?['name']);
        if (name != null) genres.add(name);
      }
    }

    return Comic(
      sourceId: id,
      remoteId: remoteId,
      title: title,
      alternativeTitles: altTitles,
      sourceUrl: 'https://mangadex.org/title/$remoteId',
      coverUrl: coverFile == null
          ? null
          : '$_coverBaseUrl/$remoteId/$coverFile.512.jpg',
      synopsis: synopsis,
      author: author,
      artist: artist,
      status: _mapStatus(attributes['status'] as String?),
      type: _mapType(attributes['originalLanguage'] as String?),
      genres: genres,
      updatedAt: DateTime.tryParse(attributes['updatedAt'] as String? ?? ''),
    );
  }

  Chapter? _toChapter(String comicId, Map<String, dynamic> item) {
    final remoteId = item['id'] as String?;
    final attributes = item['attributes'] as Map<String, dynamic>?;
    if (remoteId == null || attributes == null) return null;

    final pageCount = (attributes['pages'] as num?)?.toInt() ?? 0;
    final externalUrl = attributes['externalUrl'] as String?;
    if (externalUrl != null && pageCount == 0) return null;

    final chapterRaw = attributes['chapter']?.toString().trim();
    final chapterTitle = (attributes['title'] as String?)?.trim();
    final lang = (attributes['translatedLanguage'] as String?)?.toUpperCase();

    String? groupName;
    final relationships = item['relationships'] as List? ?? const [];
    for (final rel in relationships) {
      if (rel is! Map<String, dynamic>) continue;
      if (rel['type'] == 'scanlation_group') {
        final relAttrs = rel['attributes'] as Map<String, dynamic>?;
        groupName = (relAttrs?['name'] as String?)?.trim();
        if (groupName != null && groupName.isNotEmpty) break;
      }
    }

    final buffer = StringBuffer();
    if (chapterRaw != null && chapterRaw.isNotEmpty) {
      buffer.write('Ch. $chapterRaw');
    } else {
      buffer.write('Oneshot');
    }
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      buffer.write(' - $chapterTitle');
    }
    if (lang != null && lang.isNotEmpty) {
      buffer.write(' [$lang]');
    }
    if (groupName != null && groupName.isNotEmpty) {
      buffer.write(' • $groupName');
    }

    return Chapter(
      sourceId: id,
      comicRemoteId: comicId,
      remoteId: remoteId,
      title: buffer.toString(),
      chapterUrl: 'https://mangadex.org/chapter/$remoteId',
      chapterNumber: chapterRaw == null ? null : double.tryParse(chapterRaw),
      publishedAt: DateTime.tryParse(attributes['publishAt'] as String? ?? ''),
    );
  }

  static String? _cleanSynopsis(String raw) {
    // Ubah link markdown [teks](url) menjadi teks saja, hapus URL mentah & format markdown.
    var text = raw.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'https?:\/\/\S+'), '');
    text = text.replaceAll(RegExp(r'\*\*|__'), '');
    // Potong catatan kaki tautan resmi di bawah garis pemisah "---" bila ada.
    final divider = text.indexOf('\n---');
    if (divider > 0) {
      text = text.substring(0, divider);
    }
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text.isEmpty ? null : text;
  }

  static String? _pickLocalizedText(Object? raw) {
    if (raw is! Map) return null;
    for (final key in const ['id', 'en', 'ja-ro', 'ko-ro']) {
      final value = raw[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    for (final value in raw.values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String? _mapStatus(String? raw) {
    switch (raw) {
      case 'ongoing':
        return 'Berjalan';
      case 'completed':
        return 'Tamat';
      case 'hiatus':
        return 'Hiatus';
      case 'cancelled':
        return 'Dihentikan';
      default:
        return null;
    }
  }

  static String? _mapType(String? originalLanguage) {
    switch (originalLanguage) {
      case 'ko':
        return 'Manhwa';
      case 'zh':
      case 'zh-hk':
        return 'Manhua';
      case 'ja':
        return 'Manga';
      default:
        return null;
    }
  }
}
