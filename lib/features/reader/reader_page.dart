import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/chapter.dart';
import '../../shared/providers/chapter_pages_provider.dart';
import '../comic_detail/comic_detail_providers.dart';
import 'reader_math.dart';
import 'reader_page_image.dart';
import 'reader_system_ui.dart';

/// Reader mode vertikal bersambung (webtoon).
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.sourceId,
    required this.comicId,
    required this.chapterId,
  });

  final String sourceId;
  final String comicId;
  final String chapterId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final ScrollController _scroll = ScrollController();

  /// Tinggi dibagi lebar tiap halaman yang sudah termuat.
  final Map<int, double> _aspects = {};

  late final ReaderSystemUi _systemUi;
  bool _controlsVisible = true;
  int _currentIndex = 0;
  double _pageWidth = 0;
  int _pageCount = 0;

  ComicKey get _comicKey =>
      (sourceId: widget.sourceId, comicId: widget.comicId);

  ChapterKey get _chapterKey =>
      (sourceId: widget.sourceId, chapterId: widget.chapterId);

  @override
  void initState() {
    super.initState();
    _systemUi = ref.read(readerSystemUiProvider);
    unawaited(_systemUi.enterReader());
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    unawaited(_systemUi.leaveReader());
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _pageCount == 0 || _pageWidth == 0) return;
    final index = pageIndexAt(
      offset: _scroll.offset,
      viewportHeight: _scroll.position.viewportDimension,
      pageWidth: _pageWidth,
      pageCount: _pageCount,
      aspectOf: (i) => _aspects[i],
    );
    if (index != _currentIndex) setState(() => _currentIndex = index);
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (ref.read(readerToggleSystemBarsProvider)) {
      unawaited(_controlsVisible ? _systemUi.showBars() : _systemUi.hideBars());
    }
  }

  void _goTo(Chapter chapter) {
    context.pushReplacement(
      AppRoutes.reader(widget.sourceId, widget.comicId, chapter.remoteId),
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.comic(widget.sourceId, widget.comicId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(comicDetailProvider(_comicKey));
    final pages = ref.watch(chapterPagesProvider(_chapterKey));
    final neighbors = resolveChapterNeighbors(
      detail.value?.chapters ?? const <Chapter>[],
      widget.chapterId,
    );
    final pageCount = pages.value?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: pages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _Message(
                text: error is AppException
                    ? error.userMessage
                    : 'Gagal memuat chapter.',
                actionLabel: 'Coba lagi',
                onAction: () =>
                    ref.invalidate(chapterPagesProvider(_chapterKey)),
              ),
              data: (list) => list.isEmpty
                  ? const _Message(text: 'Chapter ini kosong.')
                  : _buildPages(context, list, neighbors),
            ),
          ),
          if (_controlsVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                comicTitle: detail.value?.comic.title ?? '',
                chapterTitle: neighbors.current?.title ?? '',
                onBack: _back,
              ),
            ),
          if (_controlsVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomBar(
                label: pageCount == 0
                    ? '-'
                    : '${_currentIndex + 1} / $pageCount',
                onPrevious: neighbors.previous == null
                    ? null
                    : () => _goTo(neighbors.previous!),
                onNext: neighbors.next == null
                    ? null
                    : () => _goTo(neighbors.next!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPages(
    BuildContext context,
    List<ChapterPage> pages,
    ChapterNeighbors neighbors,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final decodeWidth = (width * dpr).round();
        _pageWidth = width;
        _pageCount = pages.length;
        final viewport = Size(width, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Hanya ketukan di zona tengah yang mengubah kontrol.
          onTapUp: (details) {
            if (isCenterTap(position: details.localPosition, size: viewport)) {
              _toggleControls();
            }
          },
          child: ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.zero,
            scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
            itemCount: pages.length + 1,
            itemBuilder: (context, index) {
              if (index == pages.length) {
                return _EndOfChapter(
                  next: neighbors.next,
                  onNext: neighbors.next == null
                      ? null
                      : () => _goTo(neighbors.next!),
                  onBack: _back,
                );
              }
              final page = pages[index];
              return ReaderPageImage(
                key: ValueKey(page.imageUrl),
                url: page.imageUrl,
                number: index + 1,
                width: width,
                decodeWidth: decodeWidth,
                knownAspect: _aspects[index],
                onAspect: (aspect) => _aspects[index] = aspect,
              );
            },
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.comicTitle,
    required this.chapterTitle,
    required this.onBack,
  });

  final String comicTitle;
  final String chapterTitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Kembali',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comicTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      chapterTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Chapter sebelumnya',
                onPressed: onPrevious,
                icon: const Icon(Icons.skip_previous),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Chapter berikutnya',
                onPressed: onNext,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndOfChapter extends StatelessWidget {
  const _EndOfChapter({
    required this.next,
    required this.onNext,
    required this.onBack,
  });

  final Chapter? next;
  final VoidCallback? onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final nextChapter = next;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      child: Column(
        children: [
          Text('Akhir chapter', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (nextChapter != null)
            FilledButton(
              onPressed: onNext,
              child: Text('Lanjut: ${nextChapter.title}'),
            )
          else
            const Text('Chapter terakhir.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onBack,
            child: const Text('Kembali ke daftar chapter'),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

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
