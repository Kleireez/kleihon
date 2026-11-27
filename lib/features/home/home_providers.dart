import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comic.dart';
import '../../domain/entities/source_capability.dart';
import '../../shared/providers/active_source_provider.dart';
import '../../shared/providers/comic_providers.dart';
import '../../shared/providers/library_revision_provider.dart';

/// Jumlah maksimal komik per bagian di Home.
const int homeSectionLimit = 12;

/// Komik terbaru untuk Home. Bernilai null jika sumber aktif tidak
/// menyediakan daftar terbaru (UI menampilkan "tidak tersedia").
final homeLatestProvider = FutureProvider.autoDispose<List<Comic>?>((
  ref,
) async {
  ref.watch(libraryRevisionProvider);
  final sourceId = ref.watch(activeSourceIdProvider);
  final repository = ref.watch(comicRepositoryProvider);

  if (!repository.supports(sourceId, SourceCapability.latest)) return null;

  final result = await ref.watch(getLatestComicsProvider)(
    sourceId: sourceId,
    page: 1,
  );
  return result.items.take(homeSectionLimit).toList();
});

/// Komik populer untuk Home. Bernilai null jika sumber aktif tidak mendukung.
final homePopularProvider = FutureProvider.autoDispose<List<Comic>?>((
  ref,
) async {
  final sourceId = ref.watch(activeSourceIdProvider);
  final repository = ref.watch(comicRepositoryProvider);

  if (!repository.supports(sourceId, SourceCapability.popular)) return null;

  final result = await ref.watch(getPopularComicsProvider)(
    sourceId: sourceId,
    page: 1,
  );
  return result.items.take(homeSectionLimit).toList();
});

/// Rekomendasi untuk Home. Bernilai null jika sumber aktif tidak mendukung.
final homeRecommendedProvider = FutureProvider.autoDispose<List<Comic>?>((
  ref,
) async {
  final sourceId = ref.watch(activeSourceIdProvider);
  final repository = ref.watch(comicRepositoryProvider);

  if (!repository.supports(sourceId, SourceCapability.home)) return null;

  final data = await ref.watch(getHomeDataProvider)(sourceId: sourceId);
  return data.recommended?.take(homeSectionLimit).toList();
});
