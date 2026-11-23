import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/routes.dart';
import 'package:kleihon/domain/entities/history.dart';
import 'package:kleihon/features/history/history_page.dart';

import '../helpers/fake_comic_source.dart';
import '../helpers/fake_history_repository.dart';
import '../helpers/test_app.dart';

final DateTime _now = DateTime(2026, 11, 22, 12);

void seed(
  FakeHistoryRepository repo,
  String id, {
  required DateTime readAt,
  String chapterTitle = 'Chapter 14',
  int page = 3,
  int count = 10,
}) {
  repo.seed(
    HistoryEntry(
      comic: testComic('local', id, 'Judul $id'),
      chapterRemoteId: 'ch-$id',
      chapterTitle: chapterTitle,
      readAt: readAt,
      pageIndex: page,
      pageCount: count,
    ),
  );
}

Future<void> pumpHistory(
  WidgetTester tester,
  FakeHistoryRepository repo, {
  GoRouter? router,
}) async {
  useTallScreen(tester);
  final source = FakeComicSource('local');
  await tester.pumpWidget(
    router == null
        ? testApp(
            source: source,
            home: const HistoryPage(),
            history: repo,
            clock: () => _now,
          )
        : testApp(
            source: source,
            router: router,
            history: repo,
            clock: () => _now,
          ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan riwayat per hari dengan halaman dan jam', (
    tester,
  ) async {
    final repo = FakeHistoryRepository();
    seed(repo, 'a', readAt: DateTime(2026, 11, 22, 10, 5));
    seed(repo, 'b', readAt: DateTime(2026, 11, 21, 23, 30), page: 9);
    seed(repo, 'c', readAt: DateTime(2026, 11, 10, 9));
    await pumpHistory(tester, repo);

    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Kemarin'), findsOneWidget);
    expect(find.text('10/11/2026'), findsOneWidget);

    expect(find.text('Judul a'), findsOneWidget);
    expect(
      find.textContaining('Chapter 14 • Halaman 4 / 10'),
      findsNWidgets(2),
    );
    expect(find.textContaining('10:05'), findsOneWidget);
    expect(find.textContaining('Chapter 14 • Selesai'), findsOneWidget);
  });

  testWidgets('yang terbaru dibaca berada di paling atas', (tester) async {
    final repo = FakeHistoryRepository();
    seed(repo, 'lama', readAt: DateTime(2026, 11, 22, 8));
    seed(repo, 'baru', readAt: DateTime(2026, 11, 22, 11));
    await pumpHistory(tester, repo);

    final newer = tester.getTopLeft(find.text('Judul baru')).dy;
    final older = tester.getTopLeft(find.text('Judul lama')).dy;
    expect(newer, lessThan(older));
  });

  testWidgets(
    'riwayat kosong menawarkan menjelajah dan tanpa tombol hapus semua',
    (tester) async {
      await pumpHistory(tester, FakeHistoryRepository());

      expect(find.text('Belum ada riwayat baca.'), findsOneWidget);
      expect(find.text('Jelajahi komik'), findsOneWidget);
      expect(find.byTooltip('Hapus semua riwayat'), findsNothing);
    },
  );

  testWidgets('mengetuk baris membuka reader di chapter terakhir', (
    tester,
  ) async {
    final repo = FakeHistoryRepository();
    seed(repo, 'a', readAt: DateTime(2026, 11, 22, 10));
    final router = GoRouter(
      initialLocation: AppRoutes.history,
      routes: [
        GoRoute(
          path: AppRoutes.history,
          builder: (c, s) => const HistoryPage(),
        ),
        GoRoute(
          path: AppRoutes.readerPattern,
          builder: (c, s) => marker(
            'READER ${s.pathParameters['sourceId']}/'
            '${s.pathParameters['comicId']}/${s.pathParameters['chapterId']}',
          ),
        ),
      ],
    );
    await pumpHistory(tester, repo, router: router);

    await tester.tap(find.text('Judul a'));
    await tester.pumpAndSettle();

    expect(find.text('READER local/a/ch-a'), findsOneWidget);
  });

  testWidgets('hapus satu riwayat bisa diurungkan', (tester) async {
    final repo = FakeHistoryRepository();
    seed(repo, 'a', readAt: DateTime(2026, 11, 22, 10));
    seed(repo, 'b', readAt: DateTime(2026, 11, 22, 9));
    await pumpHistory(tester, repo);

    await tester.tap(find.byTooltip('Opsi riwayat').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus dari riwayat'));
    await tester.pumpAndSettle();

    expect(find.text('Judul a'), findsNothing);
    expect(find.text('Judul b'), findsOneWidget);
    expect(find.textContaining('dihapus dari riwayat'), findsOneWidget);

    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();

    expect(find.text('Judul a'), findsOneWidget);
    expect(find.text('Judul b'), findsOneWidget);
  });

  testWidgets('hapus semua: batal tidak menghapus, konfirmasi membersihkan', (
    tester,
  ) async {
    final repo = FakeHistoryRepository();
    seed(repo, 'a', readAt: DateTime(2026, 11, 22, 10));
    seed(repo, 'b', readAt: DateTime(2026, 11, 22, 9));
    await pumpHistory(tester, repo);

    await tester.tap(find.byTooltip('Hapus semua riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus semua riwayat?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(repo.clearCalls, 0);
    expect(find.text('Judul a'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus semua riwayat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus semua'));
    await tester.pumpAndSettle();

    expect(repo.clearCalls, 1);
    expect(find.text('Belum ada riwayat baca.'), findsOneWidget);
    expect(find.text('Riwayat dibersihkan.'), findsOneWidget);
  });
}
