import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/routes.dart';
import 'package:kleihon/domain/entities/bookmark.dart';
import 'package:kleihon/domain/entities/reading_status.dart';
import 'package:kleihon/features/library/library_page.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_bookmark_repository.dart';
import '../helpers/fake_comic_source.dart';
import '../helpers/test_app.dart';

void seedEntry(
  FakeBookmarkRepository repo,
  String title, {
  ReadingStatus status = ReadingStatus.unread,
  bool follow = false,
  DateTime? readAt,
  String? chapterTitle,
}) {
  final id = title.toLowerCase();
  repo.seed(
    Bookmark(
      sourceId: 'local',
      comicRemoteId: id,
      status: status,
      followUpdates: follow,
      createdAt: DateTime(2026, 11, 1),
    ),
    comic: testComic('local', id, title),
    lastRead: readAt == null
        ? null
        : LastRead(
            chapterRemoteId: 'c',
            readAt: readAt,
            chapterTitle: chapterTitle,
          ),
  );
}

Future<void> pumpLibrary(
  WidgetTester tester,
  FakeBookmarkRepository repo, {
  GoRouter? router,
}) async {
  useTallScreen(tester);
  await tester.pumpWidget(
    router == null
        ? testApp(
            source: FakeComicSource('local'),
            home: const LibraryPage(),
            bookmarks: repo,
          )
        : testApp(
            source: FakeComicSource('local'),
            router: router,
            bookmarks: repo,
          ),
  );
  await tester.pumpAndSettle();
}

double top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('menampilkan komik, status, dan chapter terakhir dibaca', (
    tester,
  ) async {
    final repo = FakeBookmarkRepository();
    seedEntry(
      repo,
      'Alpha',
      status: ReadingStatus.reading,
      readAt: DateTime(2026, 11, 10),
      chapterTitle: 'Chapter 14',
    );
    seedEntry(repo, 'Beta');
    await pumpLibrary(tester, repo);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Sedang dibaca • Terakhir: Chapter 14'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Belum dibaca'), findsOneWidget);
  });

  testWidgets('urutan bawaan: yang terakhir dibaca di atas', (tester) async {
    final repo = FakeBookmarkRepository();
    seedEntry(repo, 'Alpha');
    seedEntry(repo, 'Beta', readAt: DateTime(2026, 11, 10));
    await pumpLibrary(tester, repo);

    expect(top(tester, 'Beta'), lessThan(top(tester, 'Alpha')));
  });

  testWidgets('menu urutan mengubah ke judul A-Z', (tester) async {
    final repo = FakeBookmarkRepository();
    seedEntry(repo, 'Alpha');
    seedEntry(repo, 'Beta', readAt: DateTime(2026, 11, 10));
    await pumpLibrary(tester, repo);

    await tester.tap(find.byTooltip('Urutkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Judul A-Z'));
    await tester.pumpAndSettle();

    expect(top(tester, 'Alpha'), lessThan(top(tester, 'Beta')));
  });

  testWidgets('kategori menampilkan jumlah dan menyaring daftar', (
    tester,
  ) async {
    final repo = FakeBookmarkRepository();
    seedEntry(repo, 'Alpha', status: ReadingStatus.reading);
    seedEntry(repo, 'Beta');
    seedEntry(repo, 'Gamma', status: ReadingStatus.completed, follow: true);
    await pumpLibrary(tester, repo);

    expect(find.text('Semua 3'), findsOneWidget);
    expect(find.text('Sedang dibaca 1'), findsOneWidget);
    expect(find.text('Belum dibaca 1'), findsOneWidget);
    expect(find.text('Selesai 1'), findsOneWidget);
    expect(find.text('Diikuti 1'), findsOneWidget);

    await tester.tap(find.text('Selesai 1'));
    await tester.pumpAndSettle();

    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets('pencarian menyaring dan menampilkan pesan jika tidak cocok', (
    tester,
  ) async {
    final repo = FakeBookmarkRepository();
    seedEntry(repo, 'Alpha');
    seedEntry(repo, 'Beta');
    await pumpLibrary(tester, repo);

    await tester.enterText(find.byType(TextField), 'alp');
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada komik yang cocok.'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('Library kosong menawarkan menjelajah', (tester) async {
    await pumpLibrary(tester, FakeBookmarkRepository());

    expect(find.textContaining('Library masih kosong'), findsOneWidget);
    expect(find.text('Jelajahi komik'), findsOneWidget);
  });

  testWidgets('menu baris mengubah status baca', (tester) async {
    final repo = FakeBookmarkRepository();
    seedEntry(repo, 'Alpha');
    await pumpLibrary(tester, repo);

    await tester.tap(find.byType(PopupMenuButton<Object>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tandai: Selesai'));
    await tester.pumpAndSettle();

    final bookmark = await repo.getBookmark(
      sourceId: 'local',
      comicRemoteId: 'alpha',
    );
    expect(bookmark?.status, ReadingStatus.completed);
    expect(find.text('Selesai'), findsOneWidget);
  });

  testWidgets('hapus dari Library bisa diurungkan', (tester) async {
    final repo = FakeBookmarkRepository();
    seedEntry(repo, 'Alpha', status: ReadingStatus.reading, follow: true);
    await pumpLibrary(tester, repo);

    await tester.tap(find.byType(PopupMenuButton<Object>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus dari Library'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsNothing);
    expect(find.textContaining('dihapus dari Library'), findsOneWidget);

    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    final restored = await repo.getBookmark(
      sourceId: 'local',
      comicRemoteId: 'alpha',
    );
    expect(restored?.status, ReadingStatus.reading);
    expect(restored?.followUpdates, isTrue);
  });

  testWidgets('mengetuk komik membuka halaman detail', (tester) async {
    final repo = FakeBookmarkRepository();
    seedEntry(repo, 'Alpha');
    final router = GoRouter(
      initialLocation: AppRoutes.library,
      routes: [
        GoRoute(
          path: AppRoutes.library,
          builder: (c, s) => const LibraryPage(),
        ),
        GoRoute(
          path: AppRoutes.comicPattern,
          builder: (c, s) => marker(
            'DETAIL ${s.pathParameters['sourceId']}/${s.pathParameters['comicId']}',
          ),
        ),
      ],
    );
    await pumpLibrary(tester, repo, router: router);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('DETAIL local/alpha'), findsOneWidget);
  });
}
