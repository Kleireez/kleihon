import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_providers.dart';
import '../../data/local/local_library_layout.dart';
import '../../data/local/local_providers.dart';
import '../../data/repositories/bookmark_repository_impl.dart';
import '../../data/repositories/comic_row_mapper.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../domain/usecases/bookmark_usecases.dart';

/// Sampul sumber lokal tersimpan sebagai path relatif, dan diubah menjadi
/// URI file:// saat dibaca. Sumber lain dipakai apa adanya.
final coverResolverProvider = Provider<CoverResolver>((ref) {
  final layout = ref.watch(localLibraryLayoutProvider);
  return (sourceId, stored) async {
    if (stored == null) return null;
    if (sourceId != localSourceId) return stored;
    return (await layout.resolveFile(stored)).uri.toString();
  };
});

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(coverResolverProvider),
  );
});

final toggleBookmarkProvider = Provider<ToggleBookmark>(
  (ref) => ToggleBookmark(ref.watch(bookmarkRepositoryProvider)),
);
