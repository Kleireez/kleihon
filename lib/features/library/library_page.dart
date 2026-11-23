import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
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
    final messenger = ScaffoldMessenger.of(context);
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
    final messenger = ScaffoldMessenger.of(context);
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
    final counts = countByCategory(all.value ?? const <LibraryEntry>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          PopupMenuButton<LibrarySort>(
            tooltip: 'Urutkan',
            icon: const Icon(Icons.sort),
            initialValue: view.sort,
            onSelected: controller.setSort,
            itemBuilder: (context) => [
              for (final sort in LibrarySort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final category in LibraryCategory.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('${category.label} ${counts[category] ?? 0}'),
                      selected: view.category == category,
                      onSelected: (_) => controller.setCategory(category),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: visible.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  const Center(child: Text('Gagal memuat Library.')),
              data: (entries) {
                if (entries.isEmpty) {
                  final libraryEmpty = (all.value ?? const []).isEmpty;
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
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _LibraryTile(
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

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
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
    final parts = <String>[entry.bookmark.status.label];
    final last = entry.lastRead;
    if (last != null) {
      parts.add('Terakhir: ${last.chapterTitle ?? 'chapter terakhir'}');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
      subtitle: Text(_subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<Object>(
        tooltip: 'Opsi',
        onSelected: (value) {
          if (value is ReadingStatus) {
            onStatus(value);
          } else {
            onRemove();
          }
        },
        itemBuilder: (context) => [
          for (final status in ReadingStatus.values)
            PopupMenuItem<Object>(
              value: status,
              child: Text('Tandai: ${status.label}'),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem<Object>(
            value: _removeAction,
            child: Text('Hapus dari Library'),
          ),
        ],
      ),
      onTap: onOpen,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.collections_bookmark_outlined, size: 48),
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
