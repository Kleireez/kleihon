import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/library_revision_provider.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/source_capability.dart';
import '../../domain/entities/source_results.dart';
import '../../shared/providers/active_source_provider.dart';
import '../../shared/providers/comic_providers.dart';

/// Jeda sebelum pencarian dijalankan. Dapat diganti saat test.
final exploreDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 400),
);

/// Daftar genre dari API sumber aktif (kosong jika sumber tidak mendukung).
final exploreGenresProvider = FutureProvider.autoDispose<List<Genre>>((
  ref,
) async {
  final sourceId = ref.watch(activeSourceIdProvider);
  final repository = ref.watch(comicRepositoryProvider);
  if (!repository.supports(sourceId, SourceCapability.genres)) {
    return const <Genre>[];
  }
  return ref.watch(getGenresProvider)(sourceId: sourceId);
});

enum ExploreStatusFilter {
  ongoing('Berjalan'),
  completed('Tamat');

  const ExploreStatusFilter(this.label);
  final String label;

  bool matches(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return false;
    switch (this) {
      case ExploreStatusFilter.ongoing:
        return value == 'ongoing' || value == 'berjalan';
      case ExploreStatusFilter.completed:
        return value == 'completed' || value == 'tamat';
    }
  }
}

class ExploreFilter {
  const ExploreFilter({this.type, this.status, this.genre, this.apiGenre});

  final String? type;
  final ExploreStatusFilter? status;
  final String? genre;
  final Genre? apiGenre;

  bool get isEmpty =>
      type == null && status == null && genre == null && apiGenre == null;

  int get advancedCount =>
      (status != null ? 1 : 0) +
      (genre != null || apiGenre != null ? 1 : 0);

  bool matches(Comic comic) {
    if (type != null &&
        (comic.type ?? '').trim().toLowerCase() != type!.toLowerCase()) {
      return false;
    }
    if (status != null && !status!.matches(comic.status)) {
      return false;
    }
    if (genre != null &&
        !comic.genres.any(
          (g) => g.trim().toLowerCase() == genre!.toLowerCase(),
        )) {
      return false;
    }
    return true;
  }

  ExploreFilter copyWith({
    String? type,
    ExploreStatusFilter? status,
    String? genre,
    Genre? apiGenre,
    bool clearType = false,
    bool clearStatus = false,
    bool clearGenre = false,
    bool clearApiGenre = false,
  }) {
    return ExploreFilter(
      type: clearType ? null : (type ?? this.type),
      status: clearStatus ? null : (status ?? this.status),
      genre: clearGenre ? null : (genre ?? this.genre),
      apiGenre: clearApiGenre ? null : (apiGenre ?? this.apiGenre),
    );
  }
}

class ExploreState {
  const ExploreState({
    this.query = '',
    this.items = const [],
    this.filter = const ExploreFilter(),
    this.page = 0,
    this.hasNext = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.moreError,
  });

  final String query;
  final List<Comic> items;
  final ExploreFilter filter;

  /// Halaman terakhir yang berhasil dimuat (0 = belum ada).
  final int page;
  final bool hasNext;

  /// Memuat halaman pertama (awal, ganti kata kunci, atau refresh).
  final bool loading;
  final bool loadingMore;

  /// Kegagalan memuat halaman pertama.
  final AppException? error;

  /// Kegagalan memuat halaman berikutnya. Daftar yang ada tetap dipertahankan.
  final AppException? moreError;

  List<Comic> get filteredItems =>
      filter.isEmpty ? items : items.where(filter.matches).toList();

  List<String> get availableGenres {
    final seen = <String>{};
    for (final comic in items) {
      for (final g in comic.genres) {
        final trimmed = g.trim();
        if (trimmed.isNotEmpty) seen.add(trimmed);
      }
    }
    final sorted = seen.toList()..sort();
    return sorted;
  }

  ExploreState copyWith({
    String? query,
    List<Comic>? items,
    ExploreFilter? filter,
    int? page,
    bool? hasNext,
    bool? loading,
    bool? loadingMore,
    AppException? error,
    AppException? moreError,
    bool clearError = false,
    bool clearMoreError = false,
  }) {
    return ExploreState(
      query: query ?? this.query,
      items: items ?? this.items,
      filter: filter ?? this.filter,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      moreError: clearMoreError ? null : (moreError ?? this.moreError),
    );
  }
}

final exploreControllerProvider =
    NotifierProvider.autoDispose<ExploreController, ExploreState>(
      ExploreController.new,
    );

class ExploreController extends Notifier<ExploreState> {
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;

  @override
  ExploreState build() {
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });
    ref.watch(activeSourceIdProvider);
    ref.listen<int>(libraryRevisionProvider, (previous, next) => refresh());
    scheduleMicrotask(_loadFirst);
    return const ExploreState(loading: true);
  }

  /// Dipanggil setiap kali teks pencarian berubah. Dijalankan setelah jeda.
  void setQuery(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query == state.query) return;
    _debounce = Timer(
      ref.read(exploreDebounceProvider),
      () => _loadFirst(query: query),
    );
  }

  /// Mencari seketika, tanpa jeda debounce (tombol cari atau memilih saran).
  void searchNow(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query == state.query && state.error == null) return;
    unawaited(_loadFirst(query: query));
  }

  Future<void> refresh() {
    _debounce?.cancel();
    return _loadFirst();
  }

  void setTypeFilter(String? type) {
    state = state.copyWith(
      filter: type == null
          ? state.filter.copyWith(clearType: true)
          : state.filter.copyWith(type: type),
    );
  }

  void setStatusFilter(ExploreStatusFilter? status) {
    state = state.copyWith(
      filter: status == null
          ? state.filter.copyWith(clearStatus: true)
          : state.filter.copyWith(status: status),
    );
  }

  void setGenreFilter(String? genre) {
    state = state.copyWith(
      filter: genre == null
          ? state.filter.copyWith(clearGenre: true)
          : state.filter.copyWith(genre: genre),
    );
  }

  void setApiGenreFilter(Genre? genre) {
    _debounce?.cancel();
    state = state.copyWith(
      filter: genre == null
          ? state.filter.copyWith(clearApiGenre: true)
          : state.filter.copyWith(apiGenre: genre, clearGenre: true),
    );
    unawaited(_loadFirst());
  }

  void clearFilters() {
    final hadApiGenre = state.filter.apiGenre != null;
    state = state.copyWith(filter: const ExploreFilter());
    if (hadApiGenre) {
      unawaited(_loadFirst());
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (_disposed ||
        current.loading ||
        current.loadingMore ||
        !current.hasNext ||
        current.error != null ||
        current.moreError != null) {
      return;
    }

    final generation = _generation;
    state = current.copyWith(loadingMore: true, clearMoreError: true);
    try {
      final result = await _fetch(current.query, current.page + 1);
      if (_disposed || generation != _generation) return;

      final known = {for (final comic in state.items) comic.id};
      final fresh = [
        for (final comic in result.items)
          if (!known.contains(comic.id)) comic,
      ];
      state = state.copyWith(
        items: [...state.items, ...fresh],
        page: current.page + 1,
        hasNext: result.hasNext,
        loadingMore: false,
      );
    } catch (e) {
      if (_disposed || generation != _generation) return;
      state = state.copyWith(loadingMore: false, moreError: _asAppException(e));
    }
  }

  /// Tombol "Coba lagi" di bawah daftar.
  Future<void> retryLoadMore() {
    state = state.copyWith(clearMoreError: true);
    return loadMore();
  }

  Future<void> _loadFirst({String? query}) async {
    if (_disposed) return;
    final generation = ++_generation;
    final effectiveQuery = query ?? state.query;
    final queryChanged = effectiveQuery != state.query;

    state = state.copyWith(
      query: effectiveQuery,
      items: queryChanged ? const <Comic>[] : null,
      loading: true,
      loadingMore: false,
      clearError: true,
      clearMoreError: true,
    );

    try {
      final result = await _fetch(effectiveQuery, 1);
      if (_disposed || generation != _generation) return;
      state = state.copyWith(
        items: result.items,
        page: 1,
        hasNext: result.hasNext,
        loading: false,
      );
    } catch (e) {
      if (_disposed || generation != _generation) return;
      state = state.copyWith(
        items: const <Comic>[],
        page: 0,
        hasNext: false,
        loading: false,
        error: _asAppException(e),
      );
    }
  }

  Future<PagedResult<Comic>> _fetch(String query, int page) {
    final sourceId = ref.read(activeSourceIdProvider);
    final apiGenre = state.filter.apiGenre;
    if (query.isEmpty) {
      if (apiGenre != null) {
        return ref.read(getComicsByGenreProvider)(
          sourceId: sourceId,
          genreId: apiGenre.id,
          page: page,
        );
      }
      return ref.read(getLatestComicsProvider)(sourceId: sourceId, page: page);
    }
    return ref.read(searchComicsProvider)(
      sourceId: sourceId,
      query: query,
      page: page,
    );
  }

  AppException _asAppException(Object e) => e is AppException
      ? e
      : AppException(AppErrorType.unknown, debugMessage: e.toString());
}
