import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/reading_progress.dart';
import '../../shared/providers/chapter_pages_provider.dart';
import '../../shared/providers/reading_progress_providers.dart';
import '../comic_detail/comic_detail_providers.dart';
import 'reader_math.dart';
import 'reader_page_image.dart';
import 'reader_progress_saver.dart';
import 'reader_providers.dart';
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

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  /// Dibuat saat lebar layar sudah diketahui, supaya bisa langsung dimulai
  /// dari posisi tersimpan tanpa melompat.
  ScrollController? _scrollController;

  /// Tinggi dibagi lebar tiap halaman yang sudah termuat.
  final Map<int, double> _aspects = {};

  late final ReaderSystemUi _systemUi;
  late final ReaderProgressSaver _saver;

  bool _controlsVisible = true;
  int _currentIndex = 0;
  double _pageWidth = 0;
  int _pageCount = 0;

  /// Posisi gulir terakhir dalam piksel. Disimpan sendiri karena saat
  /// dispose() controller sudah lepas dari daftar.
  double _lastOffset = 0;

  bool _progressResolved = false;
  ReadingProgress? _initialProgress;
  bool _firstOpenRegistered = false;

  ComicKey get _comicKey =>
      (sourceId: widget.sourceId, comicId: widget.comicId);

  ChapterKey get _chapterKey =>
      (sourceId: widget.sourceId, chapterId: widget.chapterId);

  ReaderKey get _readerKey => (
    sourceId: widget.sourceId,
    comicId: widget.comicId,
    chapterId: widget.chapterId,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _systemUi = ref.read(readerSystemUiProvider);
    unawaited(_systemUi.enterReader());
    _saver = ReaderProgressSaver(
      repository: ref.read(readingProgressRepositoryProvider),
      sourceId: widget.sourceId,
      comicRemoteId: widget.comicId,
      chapterRemoteId: widget.chapterId,
      snapshot: _snapshot,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Menyimpan dulu: bagian sinkronnya membaca keadaan sebelum apa pun dibuang.
    unawaited(_saver.flush());
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    unawaited(_systemUi.leaveReader());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(_saver.flush());
  }

  ReaderSnapshot? _snapshot() {
    if (_pageWidth == 0 || _pageCount == 0) return null;
    return (
      pageIndex: _currentIndex,
      scrollOffset: _lastOffset / _pageWidth,
      pageCount: _pageCount,
      aspects: [for (var i = 0; i < _pageCount; i++) _aspects[i]],
    );
  }

  /// Dipanggil sekali, saat progres tersimpan sudah terbaca.
  void _adoptInitialProgress(ReadingProgress? progress) {
    _initialProgress = progress;
    if (progress == null || progress.isCompleted) return;
    for (var i = 0; i < progress.aspects.length; i++) {
      final aspect = progress.aspects[i];
      if (aspect != null) _aspects[i] = aspect;
    }
    _currentIndex = progress.pageIndex < 0 ? 0 : progress.pageIndex;
  }

  ScrollController _controllerFor(double width) {
    final existing = _scrollController;
    if (existing != null) return existing;

    final saved = _initialProgress;
    final resume = saved != null && !saved.isCompleted;
    final offset = resume ? saved.scrollOffset * width : 0.0;
    _lastOffset = offset;

    final controller = ScrollController(initialScrollOffset: offset)
      ..addListener(_onScroll);
    _scrollController = controller;
    return controller;
  }

  void _onScroll() {
    final controller = _scrollController;
    if (controller == null ||
        !controller.hasClients ||
        _pageCount == 0 ||
        _pageWidth == 0) {
      return;
    }
    _lastOffset = controller.offset;
    final index = pageIndexAt(
      offset: controller.offset,
      viewportHeight: controller.position.viewportDimension,
      pageWidth: _pageWidth,
      pageCount: _pageCount,
      aspectOf: (i) => _aspects[i],
    );
    if (index != _currentIndex) setState(() => _currentIndex = index);
    _saver.schedule();
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
    final saved = ref.watch(savedProgressProvider(_readerKey));
    if (!_progressResolved) {
      if (saved.isLoading) {
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()),
        );
      }
      _progressResolved = true;
      // Gagal membaca progres diperlakukan sebagai belum ada progres.
      _adoptInitialProgress(saved.value);
    }

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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _SlidingBar(
              visible: _controlsVisible,
              fromTop: true,
              child: _TopBar(
                comicTitle: detail.value?.comic.title ?? '',
                chapterTitle: neighbors.current?.title ?? '',
                onBack: _back,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _SlidingBar(
              visible: _controlsVisible,
              fromTop: false,
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
        final controller = _controllerFor(width);

        // Chapter yang belum pernah dibaca langsung tercatat di riwayat.
        if (_initialProgress == null && !_firstOpenRegistered) {
          _firstOpenRegistered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _saver.schedule();
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Hanya ketukan di zona tengah yang mengubah kontrol.
          onTapUp: (details) {
            if (isCenterTap(position: details.localPosition, size: viewport)) {
              _toggleControls();
            }
          },
          child: ListView.builder(
            controller: controller,
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

/// Lama animasi muncul dan hilangnya kontrol reader.
const Duration _barAnimation = Duration(milliseconds: 220);

/// Bilah yang meluncur dari tepi layar sambil memudar. Saat tersembunyi,
/// bilah benar-benar dilepas dari layar (tidak menangkap ketukan).
class _SlidingBar extends StatelessWidget {
  const _SlidingBar({
    required this.visible,
    required this.fromTop,
    required this.child,
  });

  final bool visible;
  final bool fromTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hiddenOffset = Offset(0, fromTop ? -1 : 1);

    return AnimatedSwitcher(
      duration: _barAnimation,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: hiddenOffset,
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: visible
          ? KeyedSubtree(key: const ValueKey('shown'), child: child)
          : const SizedBox.shrink(key: ValueKey('hidden')),
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
