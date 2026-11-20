import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/routes.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/domain/entities/chapter.dart';
import 'package:kleihon/domain/entities/comic.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/features/comic_detail/comic_detail_page.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_comic_source.dart';
import '../helpers/test_app.dart';

Future<PagedResult<Chapter>> threeChapters(
  String sourceId,
  String comicId,
  int page,
) async => PagedResult(
  items: [
    testChapter(sourceId, comicId, 'c1'),
    testChapter(sourceId, comicId, 'c2'),
    testChapter(sourceId, comicId, 'c3'),
  ],
  page: page,
  hasNext: false,
);

/// HANYA UNTUK TEST: komik dengan metadata lengkap.
class _RichComicSource extends FakeComicSource {
  _RichComicSource()
    : super(
        'local',
        onChapters: (comicId, page) => threeChapters('local', comicId, page),
      );

  @override
  Future<Comic> getComicDetail(String comicId) async => Comic(
    sourceId: id,
    remoteId: comicId,
    title: 'Komik Kaya',
    sourceUrl: 'https://example.invalid/$comicId',
    author: 'Penulis Uji',
    genres: const ['Aksi', 'Drama'],
    synopsis: 'Sinopsis ' * 30,
  );
}

/// HANYA UNTUK TEST: komik yang tidak ditemukan.
class _MissingComicSource extends FakeComicSource {
  _MissingComicSource() : super('local');

  @override
  Future<Comic> getComicDetail(String comicId) async =>
      throw const AppException(AppErrorType.notFound);
}

GoRouter detailRouter({String sourceId = 'local'}) => GoRouter(
  initialLocation: AppRoutes.comic(sourceId, 'k1'),
  routes: [
    GoRoute(
      path: AppRoutes.comicPattern,
      builder: (c, s) => ComicDetailPage(
        sourceId: s.pathParameters['sourceId']!,
        comicId: s.pathParameters['comicId']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.readerPattern,
      builder: (c, s) => marker(
        'READER ${s.pathParameters['sourceId']}/${s.pathParameters['chapterId']}',
      ),
    ),
  ],
);

double top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('menampilkan judul, jumlah chapter, dan terbaru dulu', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          onChapters: (comicId, page) => threeChapters('local', comicId, page),
        ),
        router: detailRouter(),
      ),
    );
    await tester.pumpAndSettle();

    // Judul tampil di AppBar dan di header.
    expect(find.text('Judul k1'), findsNWidgets(2));
    expect(find.text('3 chapter'), findsOneWidget);
    expect(find.text('Terbaru dulu'), findsOneWidget);
    expect(top(tester, 'Chapter c3'), lessThan(top(tester, 'Chapter c1')));
  });

  testWidgets('tombol urutan membalik daftar chapter', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          onChapters: (comicId, page) => threeChapters('local', comicId, page),
        ),
        router: detailRouter(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terbaru dulu'));
    await tester.pumpAndSettle();

    expect(find.text('Terlama dulu'), findsOneWidget);
    expect(top(tester, 'Chapter c1'), lessThan(top(tester, 'Chapter c3')));
  });

  testWidgets('Mulai membaca membuka chapter pertama menurut urutan baca', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          onChapters: (comicId, page) => threeChapters('local', comicId, page),
        ),
        router: detailRouter(),
      ),
    );
    await tester.pumpAndSettle();

    // Daftar sedang terbaru dulu, tetapi yang dibuka tetap chapter pertama.
    await tester.tap(find.text('Mulai membaca'));
    await tester.pumpAndSettle();

    expect(find.text('READER local/c1'), findsOneWidget);
  });

  testWidgets('mengetuk chapter membuka reader chapter itu', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          onChapters: (comicId, page) => threeChapters('local', comicId, page),
        ),
        router: detailRouter(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chapter c2'));
    await tester.pumpAndSettle();

    expect(find.text('READER local/c2'), findsOneWidget);
  });

  testWidgets('tanpa chapter: pesan kosong dan tombol baca nonaktif', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: FakeComicSource('local'), router: detailRouter()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada chapter.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('metadata hanya tampil jika ada, sinopsis bisa diperluas', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: _RichComicSource(), router: detailRouter()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Penulis: Penulis Uji'), findsOneWidget);
    expect(find.text('Aksi'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    // Tidak ada data pengganti untuk yang tidak diisi.
    expect(find.textContaining('Ilustrator'), findsNothing);
    expect(find.textContaining('Rating'), findsNothing);

    expect(find.text('Selengkapnya'), findsOneWidget);
    await tester.tap(find.text('Selengkapnya'));
    await tester.pumpAndSettle();
    expect(find.text('Sembunyikan'), findsOneWidget);
  });

  testWidgets(
    'komik lokal punya menu opsi dan konfirmasi hapus bisa dibatalkan',
    (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        testApp(
          source: FakeComicSource(
            'local',
            onChapters: (comicId, page) =>
                threeChapters('local', comicId, page),
          ),
          router: detailRouter(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opsi komik'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih sampul'), findsOneWidget);

      await tester.tap(find.text('Hapus komik'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus komik?'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus komik?'), findsNothing);
      expect(find.text('3 chapter'), findsOneWidget);
    },
  );

  testWidgets('sumber non-lokal tidak menampilkan opsi hapus', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'other',
          onChapters: (comicId, page) => threeChapters('other', comicId, page),
        ),
        router: detailRouter(sourceId: 'other'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Opsi komik'), findsNothing);
    expect(find.byTooltip('Opsi chapter'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
  });

  testWidgets('komik tidak ditemukan: pesan dan tombol coba lagi', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: _MissingComicSource(), router: detailRouter()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(const AppException(AppErrorType.notFound).userMessage),
      findsOneWidget,
    );
    // Halaman ini tidak punya halaman sebelumnya, jadi tidak bisa kembali.
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('Kembali'), findsNothing);
  });

  testWidgets('komik tidak ditemukan dari halaman lain: tombol Kembali', (
    tester,
  ) async {
    useTallScreen(tester);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => c.push(AppRoutes.comic('local', 'k1')),
                child: const Text('BUKA'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.comicPattern,
          builder: (c, s) => ComicDetailPage(
            sourceId: s.pathParameters['sourceId']!,
            comicId: s.pathParameters['comicId']!,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      testApp(source: _MissingComicSource(), router: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BUKA'));
    await tester.pumpAndSettle();
    expect(find.text('Kembali'), findsOneWidget);

    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('BUKA'), findsOneWidget);
  });
}
