import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/routes.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/domain/entities/chapter.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/features/reader/reader_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kleihon/features/reader/reader_page_image.dart';
import 'package:kleihon/features/reader/reader_settings.dart';

import '../helpers/fake_reader_services.dart';
import '../helpers/fake_comic_source.dart';
import '../helpers/test_app.dart';

import 'package:kleihon/domain/entities/reading_progress.dart';

import '../helpers/fake_reading_progress_repository.dart';

Future<PagedResult<Chapter>> threeChapters(String comicId, int page) async =>
    PagedResult(
      items: [
        testChapter('local', comicId, 'c1'),
        testChapter('local', comicId, 'c2'),
        testChapter('local', comicId, 'c3'),
      ],
      page: page,
      hasNext: false,
    );

Future<List<ChapterPage>> threePages(String chapterId) async => [
  for (var i = 0; i < 3; i++)
    ChapterPage(
      index: i,
      imageUrl: 'file:///tmp/kleihon_test_$chapterId$i.jpg',
    ),
];

FakeComicSource source({
  Future<List<ChapterPage>> Function(String chapterId)? onPages,
}) => FakeComicSource(
  'local',
  onChapters: threeChapters,
  onPages: onPages ?? threePages,
);

GoRouter readerRouter(String chapterId) => GoRouter(
  initialLocation: AppRoutes.reader('local', 'k1', chapterId),
  routes: [
    GoRoute(
      path: AppRoutes.readerPattern,
      builder: (c, s) => ReaderPage(
        sourceId: s.pathParameters['sourceId']!,
        comicId: s.pathParameters['comicId']!,
        chapterId: s.pathParameters['chapterId']!,
      ),
    ),
    GoRoute(path: AppRoutes.comicPattern, builder: (c, s) => marker('DETAIL')),
  ],
);

Finder iconButtonWithTooltip(String message) => find.ancestor(
  of: find.byTooltip(message),
  matching: find.byType(IconButton),
);

void main() {
  testWidgets('menampilkan judul komik, judul chapter, dan penunjuk halaman', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Judul k1'), findsOneWidget);
    expect(find.text('Chapter c2'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('mengetuk layar menyembunyikan dan menampilkan kontrol', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListView));
    await tester.pumpAndSettle();
    expect(find.text('Judul k1'), findsNothing);
    expect(find.text('1 / 3'), findsNothing);

    await tester.tap(find.byType(ListView));
    await tester.pumpAndSettle();
    expect(find.text('Judul k1'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('ketukan di tepi layar tidak mengubah kontrol', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2')),
    );
    await tester.pumpAndSettle();

    // Tepi kiri dan dekat bagian atas berada di luar zona tengah.
    await tester.tapAt(const Offset(20, 800));
    await tester.pumpAndSettle();
    expect(find.text('Judul k1'), findsOneWidget);

    await tester.tapAt(const Offset(400, 150));
    await tester.pumpAndSettle();
    expect(find.text('Judul k1'), findsOneWidget);

    // Tengah layar tetap bekerja.
    await tester.tapAt(const Offset(400, 800));
    await tester.pumpAndSettle();
    expect(find.text('Judul k1'), findsNothing);
  });

  testWidgets('kontrol hilang dengan animasi, bukan seketika', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListView));
    await tester.pump(const Duration(milliseconds: 60));
    // Animasi baru berjalan: kontrol masih ada di layar.
    expect(find.text('Judul k1'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Judul k1'), findsNothing);
  });

  testWidgets('tinggi bilah sistem tidak menggeser isi halaman', (
    tester,
  ) async {
    useTallScreen(tester);
    // Meniru status bar dan navigation bar setinggi 50.
    tester.view.padding = const FakeViewPadding(top: 50, bottom: 50);
    tester.view.viewPadding = const FakeViewPadding(top: 50, bottom: 50);

    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2')),
    );
    await tester.pumpAndSettle();

    // Halaman pertama harus tetap menempel di atas layar.
    expect(tester.getTopLeft(find.byType(ReaderPageImage).first).dy, 0);
  });

  testWidgets('chapter pertama tidak punya tombol sebelumnya', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c1')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(iconButtonWithTooltip('Chapter sebelumnya'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(iconButtonWithTooltip('Chapter berikutnya'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('tombol berikutnya membuka chapter berikutnya', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Chapter berikutnya'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter c3'), findsOneWidget);
    expect(find.text('Chapter c2'), findsNothing);
  });

  testWidgets('tombol sebelumnya membuka chapter sebelumnya', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Chapter sebelumnya'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter c1'), findsOneWidget);
  });

  testWidgets('akhir chapter menawarkan lanjut ke chapter berikutnya', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Lanjut: Chapter c3'),
      500,
      scrollable: find.byType(Scrollable),
    );
    // Geser lagi supaya tombol tidak tertutup bottom bar.
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut: Chapter c3'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter c3'), findsOneWidget);
  });

  testWidgets('chapter terakhir menampilkan penanda akhir', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c3')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Chapter terakhir.'),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Chapter terakhir.'), findsOneWidget);
    expect(find.text('Kembali ke daftar chapter'), findsOneWidget);
  });

  testWidgets('gagal memuat halaman chapter bisa dicoba lagi', (tester) async {
    useTallScreen(tester);
    var fail = true;
    await tester.pumpWidget(
      testApp(
        source: source(
          onPages: (chapterId) async {
            if (fail) throw const AppException(AppErrorType.timeout);
            return threePages(chapterId);
          },
        ),
        router: readerRouter('c2'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(const AppException(AppErrorType.timeout).userMessage),
      findsOneWidget,
    );

    fail = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Halaman 1'), findsOneWidget);
  });

  testWidgets('chapter tanpa halaman menampilkan pesan kosong', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: source(onPages: (chapterId) async => const []),
        router: readerRouter('c2'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chapter ini kosong.'), findsOneWidget);
  });

  ReadingProgress saved({
    required int page,
    required double offset,
    int count = 3,
  }) => ReadingProgress(
    sourceId: 'local',
    comicRemoteId: 'k1',
    chapterRemoteId: 'c2',
    pageIndex: page,
    pageCount: count,
    scrollOffset: offset,
    aspects: const [1.0, 1.0, 1.0],
    updatedAt: DateTime(2026, 11, 21, 10),
  );

  double scrollPixels(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  testWidgets('melanjutkan dari posisi tersimpan tanpa melompat', (
    tester,
  ) async {
    useTallScreen(tester);
    final repo = FakeReadingProgressRepository()
      ..seed(saved(page: 1, offset: 0.5));
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2'), progress: repo),
    );
    await tester.pumpAndSettle();

    // 0,5 lebar layar (800) = 400 piksel.
    expect(scrollPixels(tester), closeTo(400, 0.5));
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('geser slider memindahkan halaman', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(scrollPixels(tester), 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(700, 0));
    await tester.pump();

    // Selama digeser, label mengikuti slider dan isi layar langsung pindah.
    expect(find.text('3 / 3'), findsOneWidget);
    expect(scrollPixels(tester), greaterThan(0));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('slider nonaktif jika chapter hanya satu halaman', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: source(
          onPages: (chapterId) async => [
            ChapterPage(
              index: 0,
              imageUrl: 'file:///tmp/kleihon_test_satu.jpg',
            ),
          ],
        ),
        router: readerRouter('c2'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });

  testWidgets('chapter yang sudah selesai dibuka dari awal', (tester) async {
    useTallScreen(tester);
    final repo = FakeReadingProgressRepository()
      ..seed(saved(page: 2, offset: 1.5));
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2'), progress: repo),
    );
    await tester.pumpAndSettle();

    expect(scrollPixels(tester), 0);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('chapter baru tercatat saat reader ditutup', (tester) async {
    useTallScreen(tester);
    final repo = FakeReadingProgressRepository();
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2'), progress: repo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.chapterRemoteId, 'c2');
    expect(repo.saved.single.pageIndex, 0);
    expect(repo.saved.single.pageCount, 3);
    expect(repo.saved.single.aspects, hasLength(3));
  });

  testWidgets('membuka chapter lama tanpa menggulir tidak menimpa progres', (
    tester,
  ) async {
    useTallScreen(tester);
    final repo = FakeReadingProgressRepository()
      ..seed(saved(page: 1, offset: 0.5));
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2'), progress: repo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    expect(repo.saved, isEmpty);
  });

  testWidgets('menggulir lalu menutup reader menyimpan posisi baru', (
    tester,
  ) async {
    useTallScreen(tester);
    final repo = FakeReadingProgressRepository();
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2'), progress: repo),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    expect(repo.saved, isNotEmpty);
    final last = repo.saved.last;
    expect(last.scrollOffset, greaterThan(0.5));
    expect(last.pageIndex, greaterThan(0));
  });
  testWidgets('layar tetap menyala selama membaca dan dilepas saat keluar', (
    tester,
  ) async {
    useTallScreen(tester);
    final awake = FakeScreenAwake();
    await tester.pumpWidget(
      testApp(source: source(), router: readerRouter('c2'), screenAwake: awake),
    );
    await tester.pumpAndSettle();
    expect(awake.calls.last, isTrue);

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(awake.calls.last, isFalse);
  });

  testWidgets('pengaturan reader: ganti warna latar dan layar menyala', (
    tester,
  ) async {
    useTallScreen(tester);
    final store = InMemoryReaderSettingsStore();
    final awake = FakeScreenAwake();
    await tester.pumpWidget(
      testApp(
        source: source(),
        router: readerRouter('c2'),
        settingsStore: store,
        screenAwake: awake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pengaturan reader'));
    await tester.pumpAndSettle();
    expect(find.text('Warna latar'), findsOneWidget);

    await tester.tap(find.text('Putih'));
    await tester.pumpAndSettle();
    expect(store.saved.last.background, ReaderBackground.white);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      ReaderBackground.white.color,
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(store.saved.last.keepScreenOn, isFalse);
    expect(awake.calls.last, isFalse);
  });

  testWidgets('pengaturan tersimpan diterapkan saat reader dibuka', (
    tester,
  ) async {
    useTallScreen(tester);
    final store = InMemoryReaderSettingsStore(
      const ReaderSettings(
        background: ReaderBackground.sepia,
        keepScreenOn: false,
      ),
    );
    final awake = FakeScreenAwake();
    await tester.pumpWidget(
      testApp(
        source: source(),
        router: readerRouter('c2'),
        settingsStore: store,
        screenAwake: awake,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      ReaderBackground.sepia.color,
    );
    expect(awake.calls.last, isFalse);
  });
}
