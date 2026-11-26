import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/reading_status.dart';
import '../../domain/usecases/library_logic.dart';
import '../../shared/providers/bookmark_providers.dart';
import '../../shared/widgets/comic_cover.dart';
import 'library_labels.dart';
import 'library_providers.dart';

const String _removeAction = 'remove';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  late final TextEditingController _search;
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(libraryViewProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _open(LibraryEntry entry) {
    _searchFocus.unfocus();
    context.push(AppRoutes.comic(entry.comic.sourceId, entry.comic.remoteId));
  }

  Future<void> _changeStatus(LibraryEntry entry, ReadingStatus status) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      await ref
          .read(bookmarkRepositoryProvider)
          .setReadingStatus(
            sourceId: entry.bookmark.sourceId,
            comicRemoteId: entry.bookmark.comicRemoteId,
            status: status,
          );
    } catch (e, s) {
      appLogger.e('Gagal mengubah status baca', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mengubah status baca.')),
      );
    }
  }

  Future<void> _remove(LibraryEntry entry) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    final repository = ref.read(bookmarkRepositoryProvider);
    final previous = entry.bookmark;

    try {
      await repository.removeBookmark(
        sourceId: previous.sourceId,
        comicRemoteId: previous.comicRemoteId,
      );
    } catch (e, s) {
      appLogger.e('Gagal menghapus dari Library', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus dari Library.')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('"${entry.comic.title}" dihapus dari Library.'),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () async {
            try {
              await repository.addBookmark(
                sourceId: previous.sourceId,
                comicRemoteId: previous.comicRemoteId,
                status: previous.status,
              );
              if (previous.followUpdates) {
                await repository.setFollowUpdates(
                  sourceId: previous.sourceId,
                  comicRemoteId: previous.comicRemoteId,
                  follow: true,
                );
              }
            } catch (e, s) {
              appLogger.e(
                'Gagal mengembalikan ke Library',
                error: e,
                stackTrace: s,
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final all = ref.watch(libraryEntriesProvider);
    final visible = ref.watch(visibleLibraryProvider);
    final allEntries = all.value ?? const <LibraryEntry>[];
    final counts = countByCategory(allEntries);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Library', style: theme.textTheme.headlineSmall),
            if (allEntries.isNotEmpty)
              Text(
                '${allEntries.length} Komik tersimpan',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<LibrarySort>(
            tooltip: 'Urutkan',
            icon: Icon(Icons.swap_vert_rounded, color: scheme.onSurface),
            initialValue: view.sort,
            onSelected: controller.setSort,
            itemBuilder: (context) => [
              for (final sort in LibrarySort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
                hintText: 'Cari di Library',
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                          controller.setQuery('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final category in LibraryCategory.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(
                          '${category.label} ${counts[category] ?? 0}',
                        ),
                        selected: view.category == category,
                        onSelected: (_) => controller.setCategory(category),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: visible.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  const Center(child: Text('Gagal memuat Library.')),
              data: (entries) {
                if (entries.isEmpty) {
                  final libraryEmpty = allEntries.isEmpty;
                  return _EmptyMessage(
                    text: libraryEmpty
                        ? 'Library masih kosong.\nKetuk ikon bookmark di '
                              'halaman komik untuk menambahkannya.'
                        : 'Tidak ada komik yang cocok.',
                    actionLabel: libraryEmpty ? 'Jelajahi komik' : null,
                    onAction: libraryEmpty
                        ? () => context.go(AppRoutes.explore)
                        : null,
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.51,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _LibraryGridCard(
                      entry: entry,
                      onOpen: () => _open(entry),
                      onStatus: (status) => _changeStatus(entry, status),
                      onRemove: () => _remove(entry),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryGridCard extends StatelessWidget {
  const _LibraryGridCard({
    required this.entry,
    required this.onOpen,
    required this.onStatus,
    required this.onRemove,
  });

  final LibraryEntry entry;
  final VoidCallback onOpen;
  final void Function(ReadingStatus status) onStatus;
  final VoidCallback onRemove;

  String get _subtitle {
    final last = entry.lastRead;
    if (last != null) {
      return 'Terakhir: ${last.chapterTitle ?? 'chapter terakhir'}';
    }
    return entry.bookmark.status.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = entry.bookmark.status;

    final Color badgeBg;
    final Color badgeFg;
    switch (status) {
      case ReadingStatus.reading:
        badgeBg = const Color(0xCC111318);
        badgeFg = const Color(0xFFF4CA7E);
      case ReadingStatus.completed:
        badgeBg = const Color(0xCC1B3B2B);
        badgeFg = const Color(0xFFA7F3D0);
      case ReadingStatus.unread:
        badgeBg = const Color(0xCC892132);
        badgeFg = const Color(0xFFFFDADB);
    }

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ComicCover(url: entry.comic.coverUrl, borderRadius: 10),
                Positioned(
                  top: 6,
                  left: 6,
                  right: 34,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        status.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xCC111318),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: PopupMenuButton<Object>(
                      tooltip: 'Opsi',
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                      ),
                      onSelected: (value) {
                        if (value is ReadingStatus) {
                          onStatus(value);
                        } else {
                          onRemove();
                        }
                      },
                      itemBuilder: (context) => [
                        for (final item in ReadingStatus.values)
                          PopupMenuItem<Object>(
                            value: item,
                            child: Text('Tandai: ${item.label}'),
                          ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<Object>(
                          value: _removeAction,
                          child: Text('Hapus dari Library'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.comic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.text, this.actionLabel, this.onAction});

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
              child: Icon(
                Icons.collections_bookmark_outlined,
                size: 32,
                color: scheme.onSurfaceVariant,
              ),
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
