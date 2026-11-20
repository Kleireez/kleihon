import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/routes.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/domain/entities/comic.dart';
import 'package:kleihon/domain/entities/source_capability.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/features/explore/explore_page.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_comic_source.dart';
import '../helpers/test_app.dart';

const _caps = {SourceCapability.latest, SourceCapability.search};

PagedResult<Comic> comics(List<String> ids, int page, {bool hasNext = false}) =>
    PagedResult(
      items: [for (final id in ids) testComic('local', id)],
      page: page,
      hasNext: hasNext,
    );

void main() {
  testWidgets('menampilkan komik terbaru dalam grid', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          capabilities: _caps,
          onLatest: (page) async => comics(['a', 'b'], page),
        ),
        home: const ExplorePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Judul a'), findsOneWidget);
    expect(find.text('Judul b'), findsOneWidget);
  });

  testWidgets('keadaan kosong menawarkan impor', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          capabilities: _caps,
          onLatest: (page) async => comics([], page),
        ),
        home: const ExplorePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada komik.'), findsOneWidget);
    expect(find.text('Impor komik'), findsOneWidget);
  });

  testWidgets('error halaman pertama bisa dipulihkan dengan Coba lagi', (
    tester,
  ) async {
    useTallScreen(tester);
    var fail = true;
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          capabilities: _caps,
          onLatest: (page) async {
            if (fail) throw const AppException(AppErrorType.timeout);
            return comics(['a'], page);
          },
        ),
        home: const ExplorePage(),
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

    expect(find.text('Judul a'), findsOneWidget);
  });

  testWidgets(
    'pencarian menampilkan hasil dan tombol hapus mengembalikan daftar',
    (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        testApp(
          source: FakeComicSource(
            'local',
            capabilities: _caps,
            onLatest: (page) async => comics(['a'], page),
            onSearch: (query, page) async => PagedResult(
              items: [testComic('local', 'x', 'Hasil $query')],
              page: page,
              hasNext: false,
            ),
          ),
          home: const ExplorePage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Hasil abc'), findsOneWidget);
      expect(find.text('Judul a'), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Judul a'), findsOneWidget);
      expect(find.text('Hasil abc'), findsNothing);
    },
  );

  testWidgets('pencarian tanpa hasil menampilkan pesan', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          capabilities: _caps,
          onLatest: (page) async => comics(['a'], page),
          onSearch: (query, page) async => comics([], page),
        ),
        home: const ExplorePage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada hasil untuk "zzz".'), findsOneWidget);
  });

  testWidgets('kolom pencarian disembunyikan jika sumber tidak mendukung', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          capabilities: {SourceCapability.latest},
          onLatest: (page) async => comics(['a'], page),
        ),
        home: const ExplorePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Judul a'), findsOneWidget);
  });

  testWidgets('mengetuk komik membuka halaman detail', (tester) async {
    useTallScreen(tester);
    final router = GoRouter(
      initialLocation: AppRoutes.explore,
      routes: [
        GoRoute(
          path: AppRoutes.explore,
          builder: (c, s) => const ExplorePage(),
        ),
        GoRoute(
          path: AppRoutes.comicPattern,
          builder: (c, s) => marker(
            'DETAIL ${s.pathParameters['sourceId']}/${s.pathParameters['comicId']}',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource(
          'local',
          capabilities: _caps,
          onLatest: (page) async => comics(['a'], page),
        ),
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Judul a'));
    await tester.pumpAndSettle();

    expect(find.text('DETAIL local/a'), findsOneWidget);
  });
}
