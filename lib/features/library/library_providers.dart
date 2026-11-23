import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/bookmark.dart';
import '../../domain/usecases/library_logic.dart';
import '../../shared/providers/bookmark_providers.dart';
import '../comic_detail/comic_detail_providers.dart';

/// Bookmark sebuah komik. Null jika tidak di-bookmark.
final bookmarkProvider = StreamProvider.autoDispose.family<Bookmark?, ComicKey>(
  (ref, key) {
    return ref
        .watch(bookmarkRepositoryProvider)
        .watchBookmark(sourceId: key.sourceId, comicRemoteId: key.comicId);
  },
);

/// Semua komik ber-bookmark, tanpa penyaringan.
final libraryEntriesProvider = StreamProvider.autoDispose<List<LibraryEntry>>((
  ref,
) {
  return ref.watch(bookmarkRepositoryProvider).watchLibrary();
});

class LibraryViewState {
  const LibraryViewState({
    this.category = LibraryCategory.all,
    this.query = '',
    this.sort = LibrarySort.recent,
  });

  final LibraryCategory category;
  final String query;
  final LibrarySort sort;

  LibraryViewState copyWith({
    LibraryCategory? category,
    String? query,
    LibrarySort? sort,
  }) {
    return LibraryViewState(
      category: category ?? this.category,
      query: query ?? this.query,
      sort: sort ?? this.sort,
    );
  }
}

class LibraryViewController extends Notifier<LibraryViewState> {
  @override
  LibraryViewState build() => const LibraryViewState();

  void setCategory(LibraryCategory category) =>
      state = state.copyWith(category: category);

  void setQuery(String query) => state = state.copyWith(query: query);

  void setSort(LibrarySort sort) => state = state.copyWith(sort: sort);
}

final libraryViewProvider =
    NotifierProvider<LibraryViewController, LibraryViewState>(
      LibraryViewController.new,
    );

/// Library yang sudah disaring dan diurutkan sesuai pilihan pengguna.
final visibleLibraryProvider =
    Provider.autoDispose<AsyncValue<List<LibraryEntry>>>((ref) {
      final entries = ref.watch(libraryEntriesProvider);
      final view = ref.watch(libraryViewProvider);
      return entries.whenData(
        (list) => sortLibrary(
          filterLibrary(list, category: view.category, query: view.query),
          view.sort,
        ),
      );
    });
