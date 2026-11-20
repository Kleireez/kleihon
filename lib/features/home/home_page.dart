import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/source_capability.dart';
import '../../shared/providers/active_source_provider.dart';
import '../../shared/providers/comic_providers.dart';
import '../../shared/widgets/comic_grid_tile.dart';
import 'home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceId = ref.watch(activeSourceIdProvider);
    final repository = ref.watch(comicRepositoryProvider);
    final latest = ref.watch(homeLatestProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KleiHon',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Perpustakaan lokal',
            onPressed: () => context.push(AppRoutes.localImport),
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: 'Cari',
            onPressed: () => context.go(AppRoutes.explore),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeLatestProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.go(AppRoutes.explore),
                      icon: const Icon(Icons.search),
                      label: const Text('Cari komik'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.go(AppRoutes.library),
                      icon: const Icon(Icons.collections_bookmark_outlined),
                      label: const Text('Library'),
                    ),
                  ),
                ],
              ),
            ),
            _SectionHeader(
              title: 'Terbaru',
              onSeeAll: () => context.go(AppRoutes.explore),
            ),
            _LatestSection(
              value: latest,
              onRetry: () => ref.invalidate(homeLatestProvider),
              onImport: () => context.push(AppRoutes.localImport),
              onOpen: (comic) =>
                  context.push(AppRoutes.comic(comic.sourceId, comic.remoteId)),
            ),
            // Bagian berikut hanya menampilkan "tidak tersedia". Jika sebuah
            // sumber mendukungnya, isinya dibuat di langkah tersendiri.
            if (!repository.supports(sourceId, SourceCapability.popular))
              const _UnavailableSection(title: 'Populer'),
            if (!repository.supports(sourceId, SourceCapability.home))
              const _UnavailableSection(title: 'Rekomendasi'),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('Lihat semua')),
        ],
      ),
    );
  }
}

class _LatestSection extends StatelessWidget {
  const _LatestSection({
    required this.value,
    required this.onRetry,
    required this.onImport,
    required this.onOpen,
  });

  final AsyncValue<List<Comic>?> value;
  final VoidCallback onRetry;
  final VoidCallback onImport;
  final void Function(Comic comic) onOpen;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const SizedBox(
        height: 210,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => _InlineMessage(
        text: error is AppException
            ? error.userMessage
            : 'Gagal memuat daftar komik.',
        actionLabel: 'Coba lagi',
        onAction: onRetry,
      ),
      data: (items) {
        if (items == null) {
          return const _InlineMessage(text: 'Tidak tersedia di sumber ini.');
        }
        if (items.isEmpty) {
          return _InlineMessage(
            text: 'Belum ada komik.',
            actionLabel: 'Impor komik',
            onAction: onImport,
          );
        }
        return SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final comic = items[index];
              return SizedBox(
                width: 112,
                child: ComicGridTile(comic: comic, onTap: () => onOpen(comic)),
              );
            },
          ),
        );
      },
    );
  }
}

class _UnavailableSection extends StatelessWidget {
  const _UnavailableSection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        const _InlineMessage(text: 'Tidak tersedia di sumber ini.'),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(color: muted)),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
