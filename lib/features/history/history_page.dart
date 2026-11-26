import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/format_date.dart';
import '../../domain/entities/history.dart';
import '../../shared/providers/history_providers.dart';
import '../../shared/widgets/comic_cover.dart';
import 'history_logic.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    HistoryEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final repository = ref.read(historyRepositoryProvider);

    final HistoryRestorePoint? point;
    try {
      point = await repository.removeComic(
        sourceId: entry.comic.sourceId,
        comicRemoteId: entry.comic.remoteId,
      );
    } catch (e, s) {
      appLogger.e('Gagal menghapus riwayat', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus riwayat.')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('"${entry.comic.title}" dihapus dari riwayat.'),
        action: point == null
            ? null
            : SnackBarAction(
                label: 'Urungkan',
                onPressed: () async {
                  try {
                    await repository.restore(point!);
                  } catch (e, s) {
                    appLogger.e(
                      'Gagal mengurungkan penghapusan riwayat',
                      error: e,
                      stackTrace: s,
                    );
                  }
                },
              ),
      ),
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Hapus semua riwayat?'),
          content: const Text(
            'Seluruh riwayat dan progres baca akan dihapus. Komik di Library '
            'dan statusnya tidak terpengaruh. Tindakan ini tidak bisa '
            'dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus semua'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      await ref.read(historyRepositoryProvider).clearAll();
      messenger.showSnackBar(
        const SnackBar(content: Text('Riwayat dibersihkan.')),
      );
    } catch (e, s) {
      appLogger.e('Gagal membersihkan riwayat', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal membersihkan riwayat.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyEntriesProvider);
    final now = ref.watch(historyClockProvider)();
    final allEntries = entries.value ?? const <HistoryEntry>[];
    final hasEntries = allEntries.isNotEmpty;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('History', style: theme.textTheme.headlineSmall),
            if (hasEntries)
              Text(
                '${allEntries.length} komik dalam riwayat',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (hasEntries)
            IconButton(
              tooltip: 'Hapus semua riwayat',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clearAll(context, ref),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Gagal memuat riwayat.')),
        data: (list) {
          if (list.isEmpty) {
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
                      child: Icon(
                        Icons.history,
                        size: 32,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Belum ada riwayat baca.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.explore),
                      child: const Text('Jelajahi komik'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Satu daftar datar berisi label hari dan baris riwayat.
          final groups = groupHistoryByDay(list, now);
          final rows = <Object>[];
          for (final group in groups) {
            rows.add(group);
            rows.addAll(group.entries);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            itemCount: rows.length + 1,
            itemBuilder: (context, index) {
              if (index == rows.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Arsip membaca terjaga',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                );
              }
              final row = rows[index];
              if (row is HistoryGroup) {
                return _DayHeader(
                  label: row.label,
                  count: row.entries.length,
                );
              }
              final entry = row as HistoryEntry;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryCard(
                  entry: entry,
                  onOpen: () => context.push(
                    AppRoutes.reader(
                      entry.comic.sourceId,
                      entry.comic.remoteId,
                      entry.chapterRemoteId,
                    ),
                  ),
                  onRemove: () => _remove(context, ref, entry),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
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
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '$count entri',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.onOpen,
    required this.onRemove,
  });

  final HistoryEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final completed = entry.isCompleted;

    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.hairlineOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 76,
                child: ComicCover(url: entry.comic.coverUrl, borderRadius: 8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: completed
                                ? scheme.secondaryContainer.withValues(
                                    alpha: 0.45,
                                  )
                                : scheme.primaryContainer.withValues(
                                    alpha: 0.16,
                                  ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            completed ? 'Tamat' : 'Dibaca',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: completed
                                  ? scheme.secondary
                                  : scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTimeOfDay(entry.readAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.comic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      historySubtitle(entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opsi riwayat',
                onSelected: (_) => onRemove(),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Hapus dari riwayat'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
