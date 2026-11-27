import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../data/database/enums.dart';
import '../../data/downloads/download_service.dart';
import '../../data/local/local_library_layout.dart';
import '../../data/local/local_providers.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/usecases/continue_reading.dart';
import '../../shared/providers/bookmark_providers.dart';
import '../../shared/providers/download_providers.dart';
import '../../shared/providers/library_revision_provider.dart';
import '../../shared/widgets/comic_cover.dart';
import '../library/bookmark_sheet.dart';
import '../library/library_labels.dart';
import '../library/library_providers.dart';
import 'comic_detail_providers.dart';
import 'progress_labels.dart';

enum _ComicAction { cover, delete }

class ComicDetailPage extends ConsumerStatefulWidget {
  const ComicDetailPage({
    super.key,
    required this.sourceId,
    required this.comicId,
  });

  final String sourceId;
  final String comicId;

  @override
  ConsumerState<ComicDetailPage> createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends ConsumerState<ComicDetailPage> {
  bool _newestFirst = true;

  /// Setelah komik dihapus, layar dikosongkan supaya tidak sempat
  /// menampilkan error "tidak ditemukan" saat transisi kembali.
  bool _deleted = false;

  ComicKey get _key => (sourceId: widget.sourceId, comicId: widget.comicId);

  bool get _isLocal => widget.sourceId == localSourceId;

  void _open(Chapter chapter) {
    context.push(
      AppRoutes.reader(
        chapter.sourceId,
        chapter.comicRemoteId,
        chapter.remoteId,
      ),
    );
  }

  Future<void> _toggleBookmark(Bookmark? current) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(bookmarkRepositoryProvider);
    messenger.clearSnackBars();

    try {
      if (current == null) {
        await repository.addBookmark(
          sourceId: widget.sourceId,
          comicRemoteId: widget.comicId,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Ditambahkan ke Library.')),
        );
        return;
      }

      await repository.removeBookmark(
        sourceId: widget.sourceId,
        comicRemoteId: widget.comicId,
      );
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Dihapus dari Library.'),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () async {
              await repository.addBookmark(
                sourceId: widget.sourceId,
                comicRemoteId: widget.comicId,
                status: current.status,
              );
              if (current.followUpdates) {
                await repository.setFollowUpdates(
                  sourceId: widget.sourceId,
                  comicRemoteId: widget.comicId,
                  follow: true,
                );
              }
            },
          ),
        ),
      );
    } catch (e, s) {
      appLogger.e('Gagal memperbarui Library', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui Library.')),
      );
    }
  }

  void _openBookmarkSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => BookmarkSheet(comicKey: _key),
    );
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
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
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _deleteComic(ComicDetailData data) async {
    final confirmed = await _confirmDelete(
      title: 'Hapus komik?',
      message:
          '"${data.comic.title}" beserta ${data.chapters.length} chapter dan '
          'semua gambarnya akan dihapus dari perangkat. Bookmark dan progres '
          'bacanya juga ikut terhapus. Tindakan ini tidak bisa dibatalkan.',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final revision = ref.read(libraryRevisionProvider.notifier);
    final library = ref.read(localLibraryProvider);

    try {
      await library.deleteComic(widget.comicId);
    } catch (e, s) {
      appLogger.e('Gagal menghapus komik', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus komik.')),
      );
      return;
    }

    if (mounted) setState(() => _deleted = true);
    revision.bump();
    if (mounted) context.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Komik dihapus.')));
  }

  Future<void> _deleteChapter(Chapter chapter) async {
    final confirmed = await _confirmDelete(
      title: 'Hapus chapter?',
      message:
          '"${chapter.title}" dan semua gambarnya akan dihapus dari '
          'perangkat. Tindakan ini tidak bisa dibatalkan.',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final revision = ref.read(libraryRevisionProvider.notifier);
    final library = ref.read(localLibraryProvider);

    try {
      await library.deleteChapter(
        comicRemoteId: widget.comicId,
        chapterRemoteId: chapter.remoteId,
      );
    } catch (e, s) {
      appLogger.e('Gagal menghapus chapter', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus chapter.')),
      );
      return;
    }

    revision.bump();
    messenger.showSnackBar(const SnackBar(content: Text('Chapter dihapus.')));
  }

  Future<void> _downloadChapter(Chapter chapter) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      await ref
          .read(downloadServiceProvider)
          .enqueue(
            sourceId: widget.sourceId,
            comicRemoteId: widget.comicId,
            chapterRemoteId: chapter.remoteId,
          );
    } catch (e, s) {
      appLogger.e('Gagal mengantrekan unduhan', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal memulai unduhan chapter.')),
      );
    }
  }

  Future<void> _deleteDownload(Chapter chapter) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      await ref
          .read(downloadServiceProvider)
          .deleteDownload(
            sourceId: widget.sourceId,
            comicRemoteId: widget.comicId,
            chapterRemoteId: chapter.remoteId,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Unduhan chapter dihapus.')),
      );
    } catch (e, s) {
      appLogger.e('Gagal menghapus unduhan', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus unduhan chapter.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const Scaffold();

    final detail = ref.watch(comicDetailProvider(_key));
    final data = detail.value;
    final bookmark = ref.watch(bookmarkProvider(_key)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          data?.comic.title ?? 'Detail komik',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (data != null)
            IconButton(
              tooltip: bookmark != null
                  ? 'Hapus dari Library'
                  : 'Tambah ke Library',
              icon: Icon(
                bookmark != null ? Icons.bookmark : Icons.bookmark_border,
              ),
              onPressed: () => _toggleBookmark(bookmark),
            ),
          if (_isLocal && data != null)
            PopupMenuButton<_ComicAction>(
              tooltip: 'Opsi komik',
              onSelected: (action) {
                switch (action) {
                  case _ComicAction.cover:
                    context.push(
                      AppRoutes.coverPicker(widget.sourceId, widget.comicId),
                    );
                  case _ComicAction.delete:
                    _deleteComic(data);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ComicAction.cover,
                  child: Text('Pilih sampul'),
                ),
                PopupMenuItem(
                  value: _ComicAction.delete,
                  child: Text('Hapus komik'),
                ),
              ],
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(comicDetailProvider(_key)),
        ),
        data: (data) => _buildContent(context, data, bookmark),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ComicDetailData data,
    Bookmark? bookmark,
  ) {
    final progress =
        ref.watch(comicProgressProvider(_key)).value ??
        const <String, ReadingProgress>{};
    final downloads = _isLocal
        ? const <String, DownloadTaskInfo>{}
        : (ref.watch(comicDownloadsProvider(_key)).value ??
              const <String, DownloadTaskInfo>{});
    final target = resolveContinueTarget(
      chapters: data.chapters,
      progress: progress,
    );
    final chapters = _newestFirst
        ? data.chapters.reversed.toList()
        : data.chapters;
    final first = data.chapters.isEmpty ? null : data.chapters.first;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(comicDetailProvider(_key).future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(comic: data.comic)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ReadButton(target: target, first: first, onOpen: _open),
            ),
          ),
          if (bookmark != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openBookmarkSheet,
                    icon: const Icon(Icons.bookmark),
                    label: Text('Status: ${bookmark.status.label}'),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${data.chapters.length} chapter',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _newestFirst = !_newestFirst),
                    icon: const Icon(Icons.swap_vert),
                    label: Text(_newestFirst ? 'Terbaru dulu' : 'Terlama dulu'),
                  ),
                ],
              ),
            ),
          ),
          if (chapters.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada chapter.'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: chapters.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final entry = progress[chapter.remoteId];
                  final subtitle = chapterSubtitle(
                    published: chapter.publishedAt,
                    progress: entry,
                  );
                  final scheme = Theme.of(context).colorScheme;
                  return Material(
                    color: scheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.hairlineOf(context)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      title: Text(
                        chapter.title,
                        style: entry?.isCompleted == true
                            ? TextStyle(color: muted)
                            : null,
                      ),
                      subtitle: subtitle == null ? null : Text(subtitle),
                      trailing: _isLocal
                          ? PopupMenuButton<String>(
                              tooltip: 'Opsi chapter',
                              onSelected: (_) => _deleteChapter(chapter),
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus chapter'),
                                ),
                              ],
                            )
                          : _DownloadChapterAction(
                              task: downloads[chapter.remoteId],
                              onDownload: () => _downloadChapter(chapter),
                              onDelete: () => _deleteDownload(chapter),
                            ),
                      onTap: () => _open(chapter),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DownloadChapterAction extends StatelessWidget {
  const _DownloadChapterAction({
    required this.task,
    required this.onDownload,
    required this.onDelete,
  });

  final DownloadTaskInfo? task;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = task?.status;

    switch (status) {
      case DownloadStatus.queued:
        return IconButton(
          tooltip: 'Dalam antrean',
          onPressed: onDelete,
          icon: Icon(Icons.schedule_rounded, color: scheme.onSurfaceVariant),
        );
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      case DownloadStatus.completed:
        return PopupMenuButton<String>(
          tooltip: 'Unduhan selesai',
          icon: Icon(Icons.download_done_rounded, color: scheme.primary),
          onSelected: (_) => onDelete(),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'delete',
              child: Text('Hapus unduhan'),
            ),
          ],
        );
      case DownloadStatus.failed:
        return IconButton(
          tooltip: 'Unduh ulang',
          onPressed: onDownload,
          icon: Icon(Icons.error_outline_rounded, color: scheme.error),
        );
      case DownloadStatus.cancelled:
      case null:
        return IconButton(
          tooltip: 'Unduh chapter',
          onPressed: onDownload,
          icon: Icon(Icons.download_outlined, color: scheme.onSurfaceVariant),
        );
    }
  }
}

/// Tombol baca utama: mulai, lanjut, atau baca ulang.
class _ReadButton extends StatelessWidget {
  const _ReadButton({
    required this.target,
    required this.first,
    required this.onOpen,
  });

  final ContinueTarget? target;
  final Chapter? first;
  final void Function(Chapter chapter) onOpen;

  @override
  Widget build(BuildContext context) {
    final start = first;
    if (start == null) {
      return FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Mulai membaca'),
      );
    }

    final current = target;
    if (current == null) {
      return FilledButton.icon(
        onPressed: () => onOpen(start),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Mulai membaca'),
      );
    }

    if (current.finished) {
      return FilledButton.tonalIcon(
        onPressed: () => onOpen(start),
        icon: const Icon(Icons.replay),
        label: const Text('Baca ulang dari awal'),
      );
    }

    final saved = current.progress;
    final caption = (saved != null && saved.pageCount > 0)
        ? '${current.chapter.title} • halaman ${saved.pageIndex + 1} '
              'dari ${saved.pageCount}'
        : current.chapter.title;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => onOpen(current.chapter),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Lanjut membaca'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.comic});

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    String? clean(String? value) {
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    final meta = <(String, String)>[
      if (clean(comic.author) != null) ('Penulis', clean(comic.author)!),
      if (clean(comic.artist) != null) ('Ilustrator', clean(comic.artist)!),
      if (clean(comic.status) != null) ('Status', clean(comic.status)!),
      if (clean(comic.type) != null) ('Tipe', clean(comic.type)!),
      if (comic.rating != null) ('Rating', comic.rating!.toStringAsFixed(1)),
    ];
    final synopsis = clean(comic.synopsis);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.hairlineOf(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 108,
                  height: 162,
                  child: ComicCover(url: comic.coverUrl, borderRadius: 10),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comic.title, style: theme.textTheme.titleLarge),
                      if (comic.alternativeTitles.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          comic.alternativeTitles.join(' / '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      for (final (label, value) in meta)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$label: ',
                                  style: TextStyle(color: muted),
                                ),
                                TextSpan(text: value),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (comic.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final genre in comic.genres)
                  Chip(
                    label: Text(genre, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (synopsis != null) ...[
            const SizedBox(height: 12),
            _Synopsis(text: synopsis),
          ],
        ],
      ),
    );
  }
}

class _Synopsis extends StatefulWidget {
  const _Synopsis({required this.text});

  final String text;

  @override
  State<_Synopsis> createState() => _SynopsisState();
}

class _SynopsisState extends State<_Synopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 160;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.hairlineOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sinopsis', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            widget.text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (long)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
              ),
              child: Text(_expanded ? 'Sembunyikan' : 'Selengkapnya'),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final appError = error is AppException ? error as AppException : null;
    final gone = appError?.type == AppErrorType.notFound;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              appError?.userMessage ?? 'Gagal memuat komik.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (gone && context.canPop())
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Kembali'),
              )
            else
              FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
