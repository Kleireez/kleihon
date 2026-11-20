import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../domain/entities/source_capability.dart';
import '../../shared/providers/active_source_provider.dart';
import '../../shared/providers/comic_providers.dart';
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

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _import() {
    _searchFocus.unfocus();
    importLocalComic(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreControllerProvider);
    final controller = ref.read(exploreControllerProvider.notifier);
    final sourceId = ref.watch(activeSourceIdProvider);
    final canSearch = ref
        .watch(comicRepositoryProvider)
        .supports(sourceId, SourceCapability.search);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'Impor CBZ',
            onPressed: _import,
            icon: const Icon(Icons.upload_file),
          ),
        ],
        bottom: canSearch
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onTapOutside: (_) => _searchFocus.unfocus(),
                    onSubmitted: (_) => _searchFocus.unfocus(),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      setState(() {});
                      controller.setQuery(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari judul',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(context, state, controller),
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
        icon: Icons.error_outline,
        text: error.userMessage,
        actionLabel: 'Coba lagi',
        onAction: controller.refresh,
      );
    }

    if (state.items.isEmpty) {
      final hasQuery = state.query.isNotEmpty;
      return _Message(
        icon: hasQuery ? Icons.search_off : Icons.auto_stories_outlined,
        text: hasQuery
            ? 'Tidak ada hasil untuk "${state.query}".'
            : 'Belum ada komik.',
        actionLabel: hasQuery ? null : 'Impor komik',
        onAction: hasQuery ? null : _import,
      );
    }

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
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.56,
                ),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final comic = state.items[index];
                  return ComicGridTile(
                    comic: comic,
                    onTap: () {
                      _searchFocus.unfocus();
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
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
