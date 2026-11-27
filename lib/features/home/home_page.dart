import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../data/sources/source_providers.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/source_capability.dart';
import '../../shared/providers/active_source_provider.dart';
import '../../shared/providers/comic_providers.dart';
import '../../shared/providers/history_providers.dart';
import '../../shared/widgets/comic_cover.dart';
import '../../shared/widgets/comic_grid_tile.dart';
import '../local_import/local_import_flow.dart';
import '../settings/app_settings_providers.dart';
import 'home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _openSourcePicker(BuildContext context, WidgetRef ref) {
    final sources = ref.read(sourceRegistryProvider).all;
    final activeId = ref.read(activeSourceIdProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
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
              Text('Pilih sumber komik', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Material(
                color: scheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppTheme.hairlineOf(context)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < sources.length; i++) ...[
                      ListTile(
                        leading: Icon(
                          sources[i].id == 'local'
                              ? Icons.folder_outlined
                              : Icons.public_rounded,
                          color: sources[i].id == activeId
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        title: Text(
                          sources[i].name,
                          style: sources[i].id == activeId
                              ? TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                )
                              : null,
                        ),
                        trailing: sources[i].id == activeId
                            ? Icon(Icons.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () {
                          final current = ref.read(appSettingsProvider);
                          ref
                              .read(appSettingsProvider.notifier)
                              .update(
                                current.copyWith(activeSourceId: sources[i].id),
                              );
                          Navigator.pop(context);
                        },
                      ),
                      if (i < sources.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceId = ref.watch(activeSourceIdProvider);
    final registry = ref.watch(sourceRegistryProvider);
    final hasMultipleSources = registry.all.length > 1;
    final repository = ref.watch(comicRepositoryProvider);
    final latest = ref.watch(homeLatestProvider);
    final popular = ref.watch(homePopularProvider);
    final recommended = ref.watch(homeRecommendedProvider);
    final history = ref.watch(historyEntriesProvider).value;
    final lastRead = (history != null && history.isNotEmpty)
        ? history.first
        : null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.hairlineOf(context)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/logo_light.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'KleiHon',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Impor CBZ',
            onPressed: () => importLocalComic(context, ref),
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: 'Cari',
            onPressed: () => context.go(AppRoutes.explore),
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          final tasks = <Future<Object?>>[
            ref.refresh(homeLatestProvider.future),
            if (repository.supports(sourceId, SourceCapability.popular))
              ref.refresh(homePopularProvider.future),
            if (repository.supports(sourceId, SourceCapability.home))
              ref.refresh(homeRecommendedProvider.future),
          ];
          return Future.wait(tasks);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: hasMultipleSources
                          ? () => _openSourcePicker(context, ref)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                sourceId == 'local'
                                    ? 'ARSIP MANDIRI AKTIF'
                                    : 'SUMBER: ${sourceId.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.0,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (hasMultipleSources) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: scheme.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => importLocalComic(context, ref),
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
                            size: 15,
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
                ],
              ),
            ),
            if (lastRead != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _ContinueReadingCard(
                  entry: lastRead,
                  onOpenComic: () => context.push(
                    AppRoutes.comic(
                      lastRead.comic.sourceId,
                      lastRead.comic.remoteId,
                    ),
                  ),
                  onContinue: () {
                    final target = lastRead.chapterTitle != null
                        ? AppRoutes.reader(
                            lastRead.comic.sourceId,
                            lastRead.comic.remoteId,
                            lastRead.chapterRemoteId,
                          )
                        : AppRoutes.comic(
                            lastRead.comic.sourceId,
                            lastRead.comic.remoteId,
                          );
                    context.push(target);
                  },
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.search_rounded,
                      label: 'Cari komik',
                      onTap: () => context.go(AppRoutes.explore),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.collections_bookmark_outlined,
                      label: 'Library',
                      onTap: () => context.go(AppRoutes.library),
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
              onImport: () => importLocalComic(context, ref),
              onOpen: (comic) =>
                  context.push(AppRoutes.comic(comic.sourceId, comic.remoteId)),
            ),
            // Bagian berikut hanya menampilkan "tidak tersedia". Jika sebuah
            // sumber mendukungnya, isinya dibuat di langkah tersendiri.
            if (repository.supports(sourceId, SourceCapability.popular)) ...[
              _SectionHeader(
                title: 'Populer',
                onSeeAll: () => context.go(AppRoutes.explore),
              ),
              _LatestSection(
                value: popular,
                onRetry: () => ref.invalidate(homePopularProvider),
                onImport: () => importLocalComic(context, ref),
                onOpen: (comic) => context.push(
                  AppRoutes.comic(comic.sourceId, comic.remoteId),
                ),
              ),
            ] else
              const _UnavailableSection(title: 'Populer'),
            if (repository.supports(sourceId, SourceCapability.home)) ...[
              _SectionHeader(
                title: 'Rekomendasi',
                onSeeAll: () => context.go(AppRoutes.explore),
              ),
              _LatestSection(
                value: recommended,
                onRetry: () => ref.invalidate(homeRecommendedProvider),
                onImport: () => importLocalComic(context, ref),
                onOpen: (comic) => context.push(
                  AppRoutes.comic(comic.sourceId, comic.remoteId),
                ),
              ),
            ] else
              const _UnavailableSection(title: 'Rekomendasi'),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.entry,
    required this.onOpenComic,
    required this.onContinue,
  });

  final HistoryEntry entry;
  final VoidCallback onOpenComic;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPages = entry.pageCount > 0;
    final progress = hasPages
        ? ((entry.pageIndex + 1) / entry.pageCount).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progress * 100).round();
    final chapterText = entry.chapterTitle ?? 'Chapter terakhir';
    final metaText = hasPages
        ? '$chapterText • Hal ${entry.pageIndex + 1} / ${entry.pageCount}'
        : chapterText;

    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.hairlineOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenComic,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                height: 120,
                child: ComicCover(url: entry.comic.coverUrl, borderRadius: 10),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: scheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'TERAKHIR DIBACA',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w600,
                            color: scheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.comic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metaText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (hasPages) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasPages
                                ? (entry.isCompleted
                                      ? 'Selesai'
                                      : '$percent% Selesai')
                                : 'Siap dilanjutkan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: onContinue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 17),
                          label: const Text('Lanjut'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.hairlineOf(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: scheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 13.5),
                ),
              ),
            ],
          ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 12, 10),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: theme.textTheme.titleMedium),
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
        height: 216,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => _InlineCardMessage(
        icon: Icons.error_outline_rounded,
        text: error is AppException
            ? error.userMessage
            : 'Gagal memuat daftar komik.',
        actionLabel: 'Coba lagi',
        onAction: onRetry,
      ),
      data: (items) {
        if (items == null) {
          return const _InlineCardMessage(
            icon: Icons.cloud_off_outlined,
            text: 'Tidak tersedia di sumber ini.',
          );
        }
        if (items.isEmpty) {
          return _InlineCardMessage(
            icon: Icons.auto_stories_outlined,
            text: 'Belum ada komik.',
            actionLabel: 'Impor komik',
            onAction: onImport,
          );
        }
        return SizedBox(
          height: 216,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final comic = items[index];
              return SizedBox(
                width: 116,
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
        const _InlineCardMessage(
          icon: Icons.cloud_off_outlined,
          text: 'Tidak tersedia di sumber ini.',
        ),
      ],
    );
  }
}

class _InlineCardMessage extends StatelessWidget {
  const _InlineCardMessage({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.hairlineOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
