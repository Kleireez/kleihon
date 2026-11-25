import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/routes.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/domain/entities/comic.dart';
import 'package:kleihon/domain/entities/source_capability.dart';
import 'package:kleihon/domain/entities/source_results.dart';
import 'package:kleihon/features/explore/explore_page.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_search_history_repository.dart';
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

  FakeComicSource searchableSource() => FakeComicSource(
    'local',
    capabilities: _caps,
    onLatest: (page) async => comics(['a'], page),
    onSearch: (query, page) async => PagedResult(
      items: [testComic('local', 'x', 'Hasil $query')],
      page: page,
      hasNext: false,
    ),
  );

  Future<void> pumpExplore(
    WidgetTester tester,
    FakeSearchHistoryRepository history,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: searchableSource(),
        home: const ExplorePage(),
        searchHistory: history,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saran pencarian muncul saat kolom difokuskan dan masih kosong', (
    tester,
  ) async {
    final history = FakeSearchHistoryRepository(['alpha', 'beta']);
    await pumpExplore(tester, history);

    expect(find.text('Pencarian terakhir'), findsNothing);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Pencarian terakhir'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    // Hasil biasa tertutup saran.
    expect(find.text('Judul a'), findsNothing);
  });

  testWidgets('saran menghilang saat mulai mengetik', (tester) async {
    final history = FakeSearchHistoryRepository(['alpha']);
    await pumpExplore(tester, history);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Pencarian terakhir'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pumpAndSettle();

    expect(find.text('Pencarian terakhir'), findsNothing);
  });

  testWidgets('tanpa riwayat tidak ada daftar saran', (tester) async {
    await pumpExplore(tester, FakeSearchHistoryRepository());

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Pencarian terakhir'), findsNothing);
    expect(find.text('Judul a'), findsOneWidget);
  });

  testWidgets(
    'memilih saran mencari, mengisi kolom, dan memindahkannya ke atas',
    (tester) async {
      final history = FakeSearchHistoryRepository(['alpha', 'beta']);
      await pumpExplore(tester, history);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('beta'));
      await tester.pumpAndSettle();

      expect(find.text('Hasil beta'), findsOneWidget);
      expect(find.text('Pencarian terakhir'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'beta',
      );
      expect(history.items, ['beta', 'alpha']);
    },
  );

  testWidgets('tombol cari di keyboard menyimpan kata kunci', (tester) async {
    final history = FakeSearchHistoryRepository();
    await pumpExplore(tester, history);

    await tester.enterText(find.byType(TextField), '  naruto  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(history.items, ['naruto']);
    expect(find.text('Hasil naruto'), findsOneWidget);
  });

  testWidgets('hanya mengetik tanpa menekan cari tidak menyimpan', (
    tester,
  ) async {
    final history = FakeSearchHistoryRepository();
    await pumpExplore(tester, history);

    await tester.enterText(find.byType(TextField), 'naruto');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Hasil naruto'), findsOneWidget);
    expect(history.added, isEmpty);
  });

  testWidgets('membuka hasil pencarian menyimpan kata kunci', (tester) async {
    useTallScreen(tester);
    final history = FakeSearchHistoryRepository();
    final router = GoRouter(
      initialLocation: AppRoutes.explore,
      routes: [
        GoRoute(
          path: AppRoutes.explore,
          builder: (c, s) => const ExplorePage(),
        ),
        GoRoute(
          path: AppRoutes.comicPattern,
          builder: (c, s) => marker('DETAIL'),
        ),
      ],
    );
    await tester.pumpWidget(
      testApp(
        source: searchableSource(),
        router: router,
        searchHistory: history,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bleach');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(history.added, isEmpty);

    await tester.tap(find.text('Hasil bleach'));
    await tester.pumpAndSettle();

    expect(history.items, ['bleach']);
    expect(find.text('DETAIL'), findsOneWidget);
  });

  testWidgets(
    'membuka komik dari daftar terbaru (tanpa kata kunci) tidak menyimpan',
    (tester) async {
      useTallScreen(tester);
      final history = FakeSearchHistoryRepository();
      final router = GoRouter(
        initialLocation: AppRoutes.explore,
        routes: [
          GoRoute(
            path: AppRoutes.explore,
            builder: (c, s) => const ExplorePage(),
          ),
          GoRoute(
            path: AppRoutes.comicPattern,
            builder: (c, s) => marker('DETAIL'),
          ),
        ],
      );
      await tester.pumpWidget(
        testApp(
          source: searchableSource(),
          router: router,
          searchHistory: history,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Judul a'));
      await tester.pumpAndSettle();

      expect(history.added, isEmpty);
    },
  );

  testWidgets('hapus satu saran dan hapus semua', (tester) async {
    final history = FakeSearchHistoryRepository(['alpha', 'beta', 'gamma']);
    await pumpExplore(tester, history);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hapus dari riwayat pencarian').first);
    await tester.pumpAndSettle();
    expect(history.items, ['beta', 'gamma']);
    expect(find.text('alpha'), findsNothing);
    // Daftar tetap terbuka setelah menghapus satu.
    expect(find.text('Pencarian terakhir'), findsOneWidget);

    await tester.tap(find.text('Hapus semua'));
    await tester.pumpAndSettle();
    expect(history.clearCalls, 1);
    expect(history.items, isEmpty);
    expect(find.text('Pencarian terakhir'), findsNothing);
  });
}
