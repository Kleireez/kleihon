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
import 'reader_settings.dart';
import 'reader_settings_providers.dart';
import 'reader_settings_sheet.dart';
import 'reader_system_ui.dart';
import 'screen_awake.dart';

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
  late final ScreenAwake _screenAwake;
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

  /// Nilai slider selama digeser. Null jika tidak sedang digeser.
  double? _dragValue;
  int? _lastSeekIndex;

  /// Halaman tujuan lompatan slider. Selama diisi, posisinya dikoreksi tiap
  /// kali gambar di atasnya selesai dimuat dan mengubah tinggi.
  int? _anchorIndex;
  Timer? _anchorTimer;
  bool _anchorScheduled = false;

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
    _screenAwake = ref.read(readerScreenAwakeProvider);
    unawaited(_systemUi.enterReader());

    // Layar menyala mengikuti pengaturan, termasuk saat diubah di tengah baca.
    ref.listenManual<AsyncValue<ReaderSettings>>(readerSettingsProvider, (
      previous,
      next,
    ) {
      final keepOn = (next.value ?? ReaderSettings.defaults).keepScreenOn;
      unawaited(_screenAwake.set(keepOn));
    }, fireImmediately: true);

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
    _anchorTimer?.cancel();
    // Menyimpan dulu: bagian sinkronnya membaca keadaan sebelum apa pun dibuang.
    unawaited(_saver.flush());
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    unawaited(_screenAwake.set(false));
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

  double _offsetOfPage(int index) => pageOffsetOf(
    index: index,
    pageWidth: _pageWidth,
    aspectOf: (i) => _aspects[i],
  );

  /// Slider digeser: pindah ke halaman terdekat dan jaga posisinya.
  void _seekTo(double value) {
    final controller = _scrollController;
    if (controller == null ||
        !controller.hasClients ||
        _pageCount == 0 ||
        _pageWidth == 0) {
      return;
    }

    final last = (_pageCount - 1).toDouble();
    final clamped = value < 0 ? 0.0 : (value > last ? last : value);
    setState(() => _dragValue = clamped);

    final index = clamped.round();
    if (index == _lastSeekIndex) return;
    _lastSeekIndex = index;

    _anchorIndex = index;
    _anchorTimer?.cancel();
    _anchorTimer = Timer(const Duration(milliseconds: 1500), () {
      _anchorIndex = null;
    });
    controller.jumpTo(_offsetOfPage(index));
  }

  void _endSeek() {
    setState(() {
      _dragValue = null;
      _lastSeekIndex = null;
    });
  }

  /// Dipanggil tiap kali gambar sebuah halaman selesai dimuat.
  void _onPageAspect(int index, double aspect) {
    final previous = _aspects[index];
    _aspects[index] = aspect;

    final anchor = _anchorIndex;
    if (anchor == null || index > anchor || previous == aspect) return;
    if (_anchorScheduled) return;
    _anchorScheduled = true;

    // Tinggi halaman di atas tujuan berubah: kembalikan halaman tujuan ke atas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchorScheduled = false;
      final target = _anchorIndex;
      final controller = _scrollController;
      if (!mounted ||
          target == null ||
          controller == null ||
          !controller.hasClients) {
        return;
      }
      final offset = _offsetOfPage(target);
      if ((controller.offset - offset).abs() > 0.5) controller.jumpTo(offset);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (ref.read(readerToggleSystemBarsProvider)) {
      unawaited(_controlsVisible ? _systemUi.showBars() : _systemUi.hideBars());
    }
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const ReaderSettingsSheet(),
    );
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
    final settings =
        ref.watch(readerSettingsProvider).value ?? ReaderSettings.defaults;
    final background = settings.background;

    final saved = ref.watch(savedProgressProvider(_readerKey));
    if (!_progressResolved) {
      if (saved.isLoading) {
        return Scaffold(
          backgroundColor: background.color,
          body: const Center(child: CircularProgressIndicator()),
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

    var sliderValue = 0.0;
    var displayIndex = 0;
    if (pageCount > 0) {
      final last = (pageCount - 1).toDouble();
      final raw = _dragValue ?? _currentIndex.toDouble();
      sliderValue = raw < 0 ? 0.0 : (raw > last ? last : raw);
      displayIndex = sliderValue.round();
    }

    return Scaffold(
      backgroundColor: background.color,
      body: Stack(
        children: [
          Positioned.fill(
            child: DefaultTextStyle.merge(
              // Teks di area baca mengikuti warna latar.
              style: TextStyle(color: background.foreground),
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
                    : _buildPages(context, list, neighbors, settings),
              ),
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
                onSettings: _openSettings,
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
                    : '${displayIndex + 1} / $pageCount',
                pageCount: pageCount,
                sliderValue: sliderValue,
                onSeek: _seekTo,
                onSeekEnd: _endSeek,
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
    ReaderSettings settings,
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
          child: NotificationListener<ScrollStartNotification>(
            // Pengguna menggulir sendiri: lepaskan penjagaan posisi.
            onNotification: (notification) {
              if (notification.dragDetails != null) _anchorIndex = null;
              return false;
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
                  onAspect: (aspect) => _onPageAspect(index, aspect),
                  placeholderColor: settings.background.placeholderColor,
                  placeholderTextColor:
                      settings.background.placeholderTextColor,
                );
              },
            ),
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
    required this.onSettings,
  });

  final String comicTitle;
  final String chapterTitle;
  final VoidCallback onBack;
  final VoidCallback onSettings;

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
              IconButton(
                tooltip: 'Pengaturan reader',
                onPressed: onSettings,
                icon: const Icon(Icons.tune),
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
    required this.pageCount,
    required this.sliderValue,
    required this.onSeek,
    required this.onSeekEnd,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final int pageCount;
  final double sliderValue;
  final ValueChanged<double> onSeek;
  final VoidCallback onSeekEnd;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    // Slider hanya berguna jika ada lebih dari satu halaman.
    final enabled = pageCount > 1;
    final max = enabled ? (pageCount - 1).toDouble() : 1.0;

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
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              Expanded(
                child: Slider(
                  value: enabled ? sliderValue : 0,
                  min: 0,
                  max: max,
                  onChanged: enabled ? onSeek : null,
                  onChangeEnd: enabled ? (_) => onSeekEnd() : null,
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
    // Warna teks mengikuti latar reader (diatur lewat DefaultTextStyle).
    final textColor = DefaultTextStyle.of(context).style.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      child: Column(
        children: [
          Text(
            'Akhir chapter',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: textColor),
          ),
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
