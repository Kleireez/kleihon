import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/source_capability.dart';
import '../../shared/providers/active_source_provider.dart';
import '../../shared/providers/comic_providers.dart';
import '../../shared/providers/search_history_providers.dart';
import '../../shared/widgets/comic_grid_tile.dart';
import '../local_import/local_import_flow.dart';
import 'explore_controller.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Kolom pencarian dan daftar saran satu kelompok ketukan: mengetuk saran
  /// tidak dianggap mengetuk di luar kolom (yang akan menutup fokus).
  final Object _regionGroup = Object();

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _import() {
    _searchFocus.unfocus();
    importLocalComic(context, ref);
  }

  /// Menyimpan kata kunci ke riwayat. Kegagalan tidak mengganggu pencarian.
  Future<void> _remember(String query) async {
    try {
      await ref.read(searchHistoryRepositoryProvider).add(query);
    } catch (e, s) {
      appLogger.w('Gagal menyimpan riwayat pencarian', error: e, stackTrace: s);
    }
  }

  Future<void> _forget(String query) async {
    try {
      await ref.read(searchHistoryRepositoryProvider).remove(query);
    } catch (e, s) {
      appLogger.w('Gagal menghapus riwayat pencarian', error: e, stackTrace: s);
    }
  }

  Future<void> _forgetAll() async {
    try {
      await ref.read(searchHistoryRepositoryProvider).clearAll();
    } catch (e, s) {
      appLogger.w(
        'Gagal membersihkan riwayat pencarian',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Tombol cari di keyboard: cari seketika dan simpan ke riwayat.
  void _submit(String value) {
    ref.read(exploreControllerProvider.notifier).searchNow(value);
    final query = value.trim();
    if (query.isNotEmpty) unawaited(_remember(query));
    _searchFocus.unfocus();
  }

  /// Memilih saran: isi kolom, cari, dan pindahkan ke paling atas riwayat.
  void _pick(String query) {
    _search.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() {});
    _submit(query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreControllerProvider);
    final controller = ref.read(exploreControllerProvider.notifier);
    final sourceId = ref.watch(activeSourceIdProvider);
    final canSearch = ref
        .watch(comicRepositoryProvider)
        .supports(sourceId, SourceCapability.search);
    final recent = ref.watch(recentSearchesProvider).value ?? const <String>[];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Saran hanya muncul saat kolom difokuskan dan masih kosong.
    final showRecent =
        canSearch &&
        _searchFocus.hasFocus &&
        _search.text.isEmpty &&
        recent.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Explore', style: theme.textTheme.headlineSmall),
            const SizedBox(width: 8),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Katalog',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _import,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.hairlineOf(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.upload_file_outlined,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Impor CBZ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: canSearch
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    groupId: _regionGroup,
                    onTapOutside: (_) => _searchFocus.unfocus(),
                    onSubmitted: _submit,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      setState(() {});
                      controller.setQuery(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari judul',
                      isDense: true,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: scheme.primary,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                                controller.setQuery('');
                              },
                            ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: showRecent
          ? TapRegion(
              groupId: _regionGroup,
              child: _RecentSearches(
                items: recent,
                onPick: _pick,
                onRemove: _forget,
                onClear: _forgetAll,
              ),
            )
          : _buildBody(context, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ExploreState state,
    ExploreController controller,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = state.error;
    if (error != null && state.items.isEmpty) {
      return _Message(
        icon: Icons.error_outline_rounded,
        text: error.userMessage,
        actionLabel: 'Coba lagi',
        onAction: controller.refresh,
      );
    }

    if (state.items.isEmpty) {
      final hasQuery = state.query.isNotEmpty;
      return _Message(
        icon: hasQuery ? Icons.search_off_rounded : Icons.auto_stories_outlined,
        text: hasQuery
            ? 'Tidak ada hasil untuk "${state.query}".'
            : 'Belum ada komik.',
        actionLabel: hasQuery ? null : 'Impor komik',
        onAction: hasQuery ? null : _import,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filtered = state.filteredItems;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 600) controller.loadMore();
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: _FilterBar(
                state: state,
                onSelectType: controller.setTypeFilter,
                onOpenAdvanced: () => _openFilterSheet(context, controller),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Text(
                      state.query.isEmpty
                          ? 'Koleksi Tersedia'
                          : 'Hasil Pencarian',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${filtered.length} judul',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Message(
                  icon: Icons.filter_alt_off_outlined,
                  text: 'Tidak ada komik yang cocok dengan filter.',
                  actionLabel: 'Reset filter',
                  onAction: controller.clearFilters,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.54,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final comic = filtered[index];
                    return ComicGridTile(
                      comic: comic,
                      onTap: () {
                        _searchFocus.unfocus();
                        // Membuka hasil pencarian berarti pencarian itu berguna.
                        if (state.query.isNotEmpty) {
                          unawaited(_remember(state.query));
                        }
                        context.push(
                          AppRoutes.comic(comic.sourceId, comic.remoteId),
                        );
                      },
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: _Footer(state: state, controller: controller),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilterSheet(BuildContext context, ExploreController controller) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ExploreFilterSheet(controller: controller),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.state,
    required this.onSelectType,
    required this.onOpenAdvanced,
  });

  static const List<String> _types = ['Manga', 'Manhwa', 'Manhua'];

  final ExploreState state;
  final ValueChanged<String?> onSelectType;
  final VoidCallback onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    final filter = state.filter;
    final advanced = filter.advancedCount;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                showCheckmark: false,
                label: const Text('Semua'),
                selected: filter.type == null,
                onSelected: (_) => onSelectType(null),
              ),
            ),
            for (final type in _types)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text(type),
                  selected: filter.type == type,
                  onSelected: (_) =>
                      onSelectType(filter.type == type ? null : type),
                ),
              ),
            ActionChip(
              avatar: Icon(
                Icons.tune_rounded,
                size: 16,
                color: advanced > 0 ? scheme.primary : scheme.onSurfaceVariant,
              ),
              label: Text(advanced > 0 ? 'Filter ($advanced)' : 'Filter'),
              side: BorderSide(
                color: advanced > 0
                    ? scheme.primary
                    : AppTheme.hairlineOf(context),
              ),
              onPressed: onOpenAdvanced,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreFilterSheet extends ConsumerWidget {
  const _ExploreFilterSheet({required this.controller});

  final ExploreController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exploreControllerProvider);
    final filter = state.filter;
    final apiGenres = ref.watch(exploreGenresProvider).value ?? const [];
    final localGenres = state.availableGenres;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Text('Filter Katalog', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (!filter.isEmpty)
                  TextButton(
                    onPressed: controller.clearFilters,
                    child: const Text('Reset'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Status', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in ExploreStatusFilter.values)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(status.label),
                    selected: filter.status == status,
                    onSelected: (_) => controller.setStatusFilter(
                      filter.status == status ? null : status,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Genre', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            if (apiGenres.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final genre in apiGenres)
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(genre.name),
                      selected: filter.apiGenre?.id == genre.id,
                      onSelected: (_) => controller.setApiGenreFilter(
                        filter.apiGenre?.id == genre.id ? null : genre,
                      ),
                    ),
                ],
              )
            else if (localGenres.isEmpty)
              Text(
                'Belum ada metadata genre pada koleksi saat ini.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final genre in localGenres)
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(genre),
                      selected: filter.genre == genre,
                      onSelected: (_) => controller.setGenreFilter(
                        filter.genre == genre ? null : genre,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.items,
    required this.onPick,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> items;
  final void Function(String query) onPick;
  final void Function(String query) onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Material(
          color: scheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.hairlineOf(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.manage_search_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pencarian terakhir',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: onClear,
                      child: const Text('Hapus semua'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (var i = 0; i < items.length; i++) ...[
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.history_rounded,
                    size: 19,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    items[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Hapus dari riwayat pencarian',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => onRemove(items[i]),
                  ),
                  onTap: () => onPick(items[i]),
                ),
                if (i < items.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.controller});

  final ExploreState state;
  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final moreError = state.moreError;
    if (moreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(moreError.userMessage, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: controller.retryLoadMore,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.hairlineOf(context)),
              ),
              child: Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
