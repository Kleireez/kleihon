import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/routes.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/domain/entities/chapter.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/features/reader/reader_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kleihon/features/reader/reader_page_image.dart';

import '../helpers/fake_comic_source.dart';
import '../helpers/test_app.dart';

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
}
