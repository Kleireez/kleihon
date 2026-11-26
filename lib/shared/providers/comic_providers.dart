import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/comic_repository_impl.dart';
import '../../data/sources/source_providers.dart';
import '../../domain/repositories/comic_repository.dart';
import '../../domain/usecases/comic_usecases.dart';

final comicRepositoryProvider = Provider<ComicRepository>((ref) {
  return ComicRepositoryImpl(ref.watch(sourceRegistryProvider));
});

final getLatestComicsProvider = Provider<GetLatestComics>(
  (ref) => GetLatestComics(ref.watch(comicRepositoryProvider)),
);

final getPopularComicsProvider = Provider<GetPopularComics>(
  (ref) => GetPopularComics(ref.watch(comicRepositoryProvider)),
);

final searchComicsProvider = Provider<SearchComics>(
  (ref) => SearchComics(ref.watch(comicRepositoryProvider)),
);

final getComicDetailProvider = Provider<GetComicDetail>(
  (ref) => GetComicDetail(ref.watch(comicRepositoryProvider)),
);

final getAllChaptersProvider = Provider<GetAllChapters>(
  (ref) => GetAllChapters(ref.watch(comicRepositoryProvider)),
);

final getChapterPagesProvider = Provider<GetChapterPages>(
  (ref) => GetChapterPages(ref.watch(comicRepositoryProvider)),
);
