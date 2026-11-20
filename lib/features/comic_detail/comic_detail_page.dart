import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/format_date.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/comic.dart';
import '../../shared/widgets/comic_cover.dart';
import 'comic_detail_providers.dart';

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

  ComicKey get _key => (sourceId: widget.sourceId, comicId: widget.comicId);

  void _open(Chapter chapter) {
    context.push(AppRoutes.reader(chapter.sourceId, chapter.remoteId));
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(comicDetailProvider(_key));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.value?.comic.title ?? 'Detail komik',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(comicDetailProvider(_key)),
        ),
        data: (data) => _buildContent(context, data),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ComicDetailData data) {
    final chapters = _newestFirst
        ? data.chapters.reversed.toList()
        : data.chapters;
    final first = data.chapters.isEmpty ? null : data.chapters.first;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(comicDetailProvider(_key).future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(comic: data.comic)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: first == null ? null : () => _open(first),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Mulai membaca'),
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
            SliverList.separated(
              itemCount: chapters.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final published = chapter.publishedAt;
                return ListTile(
                  title: Text(chapter.title),
                  subtitle: published == null
                      ? null
                      : Text(formatShortDate(published)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(chapter),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.comic});

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                height: 165,
                child: ComicCover(url: comic.coverUrl),
              ),
              const SizedBox(width: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : 4,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Sembunyikan' : 'Selengkapnya'),
          ),
      ],
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
