import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/routes.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/domain/entities/comic.dart';
import 'package:kleihon/domain/entities/history.dart';
import 'package:kleihon/domain/entities/source_capability.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/features/home/home_page.dart';

import '../helpers/fake_comic_source.dart';
import '../helpers/fake_history_repository.dart';
import '../helpers/test_app.dart';

PagedResult<Comic> comics(List<String> ids, int page) => PagedResult(
  items: [for (final id in ids) testComic('local', id)],
  page: page,
  hasNext: false,
);

GoRouter homeRouter() => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(path: AppRoutes.home, builder: (c, s) => const HomePage()),
    GoRoute(path: AppRoutes.explore, builder: (c, s) => marker('EXPLORE')),
    GoRoute(path: AppRoutes.library, builder: (c, s) => marker('LIBRARY')),
    GoRoute(
      path: AppRoutes.comicPattern,
      builder: (c, s) => marker(
        'DETAIL ${s.pathParameters['sourceId']}/${s.pathParameters['comicId']}',
      ),
    ),
    GoRoute(
      path: AppRoutes.readerPattern,
      builder: (c, s) => marker(
        'READER ${s.pathParameters['sourceId']}/${s.pathParameters['comicId']}/${s.pathParameters['chapterId']}',
      ),
    ),
  ],
);

void main() {
  testWidgets('menampilkan terbaru dan menandai bagian yang tidak tersedia', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          capabilities: {SourceCapability.latest},
          onLatest: (page) async => comics(['a', 'b'], page),
        ),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terbaru'), findsOneWidget);
    expect(find.text('Judul a'), findsOneWidget);
    expect(find.text('Judul b'), findsOneWidget);

    // Populer dan Rekomendasi tidak didukung: tampil sebagai tidak tersedia,
    // tanpa data pengganti.
    expect(find.text('Populer'), findsOneWidget);
    expect(find.text('Rekomendasi'), findsOneWidget);
    expect(find.text('Tidak tersedia di sumber ini.'), findsNWidgets(2));
  });

  testWidgets('sumber tanpa daftar terbaru menampilkan tidak tersedia', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(source: FakeComicSource('local'), home: const HomePage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tidak tersedia di sumber ini.'), findsNWidgets(3));
  });

  testWidgets('daftar terbaru kosong menawarkan impor', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          capabilities: {SourceCapability.latest},
          onLatest: (page) async => comics([], page),
        ),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada komik.'), findsOneWidget);
    expect(find.text('Impor komik'), findsOneWidget);
  });

  testWidgets('error memuat terbaru bisa dicoba lagi', (tester) async {
    useTallScreen(tester);
    var fail = true;
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          capabilities: {SourceCapability.latest},
          onLatest: (page) async {
            if (fail) throw const AppException(AppErrorType.server);
            return comics(['a'], page);
          },
        ),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(const AppException(AppErrorType.server).userMessage),
      findsOneWidget,
    );

    fail = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Judul a'), findsOneWidget);
  });

  testWidgets('pintasan dan komik membuka tujuan yang benar', (tester) async {
    useTallScreen(tester);
    final source = FakeComicSource(
      'local',
      capabilities: {SourceCapability.latest},
      onLatest: (page) async => comics(['a'], page),
    );

    await tester.pumpWidget(testApp(source: source, router: homeRouter()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cari komik'));
    await tester.pumpAndSettle();
    expect(find.text('EXPLORE'), findsOneWidget);

    await tester.pumpWidget(testApp(source: source, router: homeRouter()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('LIBRARY'), findsOneWidget);

    await tester.pumpWidget(testApp(source: source, router: homeRouter()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Judul a'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL local/a'), findsOneWidget);
  });

  testWidgets('menampilkan kartu terakhir dibaca dan tombol Lanjut', (
    tester,
  ) async {
    useTallScreen(tester);
    final history = FakeHistoryRepository()
      ..seed(
        HistoryEntry(
          comic: testComic('local', 'v1', 'Vagabond'),
          chapterRemoteId: 'ch142',
          chapterTitle: 'Ch. 142',
          pageIndex: 17,
          pageCount: 32,
          readAt: DateTime(2026, 11, 20),
        ),
      );
    final source = FakeComicSource(
      'local',
      capabilities: {SourceCapability.latest},
      onLatest: (page) async => comics(['a'], page),
    );

    await tester.pumpWidget(
      testApp(source: source, router: homeRouter(), history: history),
    );
    await tester.pumpAndSettle();

    expect(find.text('TERAKHIR DIBACA'), findsOneWidget);
    expect(find.text('Vagabond'), findsOneWidget);
    expect(find.text('Ch. 142 • Hal 18 / 32'), findsOneWidget);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('READER local/v1/ch142'), findsOneWidget);
  });
}
