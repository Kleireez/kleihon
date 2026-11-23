import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
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

    final messenger = ScaffoldMessenger.of(context);
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
    final hasEntries = (entries.value ?? const <HistoryEntry>[]).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (hasEntries)
            IconButton(
              tooltip: 'Hapus semua riwayat',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clearAll(context, ref),
            ),
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
                    const Icon(Icons.history, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada riwayat baca.',
                      textAlign: TextAlign.center,
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
          final rows = <Object>[];
          for (final group in groupHistoryByDay(list, now)) {
            rows.add(group.label);
            rows.addAll(group.entries);
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row is String) return _DayHeader(label: row);
              final entry = row as HistoryEntry;
              return _HistoryTile(
                entry: entry,
                onOpen: () => context.push(
                  AppRoutes.reader(
                    entry.comic.sourceId,
                    entry.comic.remoteId,
                    entry.chapterRemoteId,
                  ),
                ),
                onRemove: () => _remove(context, ref, entry),
              );
            },
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onOpen,
    required this.onRemove,
  });

  final HistoryEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      isThreeLine: true,
      leading: SizedBox(
        width: 48,
        height: 68,
        child: ComicCover(url: entry.comic.coverUrl, borderRadius: 4),
      ),
      title: Text(
        entry.comic.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${historySubtitle(entry)}\n${formatTimeOfDay(entry.readAt)}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opsi riwayat',
        onSelected: (_) => onRemove(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'remove', child: Text('Hapus dari riwayat')),
        ],
      ),
      onTap: onOpen,
    );
  }
}
