import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kleihon/app/app.dart';
import 'package:kleihon/data/database/app_database.dart';
import 'package:kleihon/data/database/database_providers.dart';
import 'package:kleihon/data/local/local_library.dart';
import 'package:kleihon/data/local/local_library_layout.dart';
import 'package:kleihon/data/local/local_providers.dart';
import 'package:kleihon/data/repositories/bookmark_repository_impl.dart';
import 'package:kleihon/data/repositories/reading_progress_repository_impl.dart';
import 'package:kleihon/data/repositories/search_history_repository_impl.dart';
import 'package:kleihon/domain/entities/reading_progress.dart';
import 'package:kleihon/domain/entities/reading_status.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../test/helpers/zip_builder.dart';

/// PNG 1x1 piksel. Jika ternyata tidak valid, reader menampilkan halaman
/// gagal-dimuat dan tes tetap berjalan (yang diperiksa hanya jumlah halaman).
const String _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

/// Menunggu (waktu nyata) sampai [finder] ditemukan.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'Tidak ditemukan dalam ${timeout.inSeconds} detik: $finder',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late AppDatabase db;
  late LocalLibraryLayout layout;
  late ImportedBatch batch;

  Widget buildApp() => ProviderScope(
    // Tanpa pengulangan otomatis, seperti di aplikasi.
    retry: (retryCount, error) => null,
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      localLibraryLayoutProvider.overrideWithValue(layout),
    ],
    child: const KleiHonApp(),
  );

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Meniru menutup lalu membuka kembali aplikasi dengan database yang sama.
  Future<void> reopenApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(buildApp());
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kleihon_e2e_library_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    layout = LocalLibraryLayout(
      () async => Directory(p.join(root.path, 'library')),
    );

    final png = base64Decode(_tinyPng);
    final zip = makeTestZip(
      Directory(p.join(root.path, 'zips')),
      'Komik Integrasi.cbz',
      {
        'K/Chapter 1/1.png': png,
        'K/Chapter 1/2.png': png,
        'K/Chapter 1/3.png': png,
        'K/Chapter 2/1.png': png,
        'K/Chapter 2/2.png': png,
      },
    );
    batch = await LocalLibrary(
      database: db,
      layout: layout,
    ).importCbz(file: zip, comicTitle: 'Komik Integrasi', splitByFolder: true);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  testWidgets(
    'bookmark, status otomatis, Library, dan History lewat alur pengguna',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await pumpUntilFound(tester, find.text('Komik Integrasi'));

      // Buka detail dari Explore dan tambahkan ke Library.
      await openTab(tester, 'Explore');
      await pumpUntilFound(tester, find.text('Komik Integrasi'));
      await tester.tap(find.text('Komik Integrasi'));
      await pumpUntilFound(tester, find.text('2 chapter'));

      await tester.tap(find.byTooltip('Tambah ke Library'));
      await pumpUntilFound(tester, find.text('Status: Belum dibaca'));

      // Library menampilkan komik dengan status awal.
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 300));
      await openTab(tester, 'Library');
      await pumpUntilFound(tester, find.text('Komik Integrasi'));
      expect(find.text('Belum dibaca'), findsWidgets);
      expect(find.text('Semua 1'), findsOneWidget);

      // Baca chapter pertama lalu keluar dari reader.
      await tester.tap(find.text('Komik Integrasi'));
      await pumpUntilFound(tester, find.text('Mulai membaca'));
      await tester.tap(find.text('Mulai membaca'));
      await pumpUntilFound(tester, find.textContaining(' / '));
      await tester.tap(find.byTooltip('Kembali'));

      // Mulai membaca mengubah status secara otomatis.
      await pumpUntilFound(tester, find.text('Status: Sedang dibaca'));

      // Library mencerminkan status baru dan chapter terakhir dibaca.
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 300));
      await pumpUntilFound(
        tester,
        find.text('Sedang dibaca • Terakhir: Chapter 1'),
      );
      expect(find.text('Sedang dibaca 1'), findsOneWidget);

      // History mencatat komik yang barusan dibaca.
      await openTab(tester, 'History');
      await pumpUntilFound(tester, find.text('Hari ini'));
      expect(find.text('Komik Integrasi'), findsOneWidget);
      expect(find.textContaining('Chapter 1 • Halaman'), findsOneWidget);
    },
  );

  testWidgets(
    'bookmark, riwayat, dan riwayat pencarian terbaca setelah dibuka ulang',
    (tester) async {
      // Menyiapkan data lewat repository asli, seperti hasil sesi sebelumnya.
      final bookmarks = BookmarkRepositoryImpl(
        db,
        (sourceId, stored) async => stored,
      );
      await bookmarks.addBookmark(
        sourceId: 'local',
        comicRemoteId: batch.comicRemoteId,
        status: ReadingStatus.reading,
      );
      await bookmarks.setFollowUpdates(
        sourceId: 'local',
        comicRemoteId: batch.comicRemoteId,
        follow: true,
      );
      await ReadingProgressRepositoryImpl(db).saveProgress(
        ReadingProgress(
          sourceId: 'local',
          comicRemoteId: batch.comicRemoteId,
          chapterRemoteId: batch.chapters.first.chapterRemoteId,
          pageIndex: 1,
          pageCount: 3,
          scrollOffset: 1,
          aspects: const [1.0, 1.0, 1.0],
          updatedAt: DateTime.now(),
        ),
      );
      await SearchHistoryRepositoryImpl(db).add('integrasi');

      Future<void> verifyEverything() async {
        await pumpUntilFound(tester, find.text('Komik Integrasi'));

        // Library: bookmark, status, ikuti update, dan chapter terakhir.
        await openTab(tester, 'Library');
        await pumpUntilFound(tester, find.text('Sedang dibaca'));
        expect(find.text('Terakhir: Chapter 1'), findsOneWidget);
        expect(find.text('Diikuti 1'), findsOneWidget);

        // History: komik dan halaman terakhir.
        await openTab(tester, 'History');
        await pumpUntilFound(tester, find.text('Hari ini'));
        expect(
          find.textContaining('Chapter 1 • Halaman 2 / 3'),
          findsOneWidget,
        );

        // Explore: saran pencarian tersimpan.
        await openTab(tester, 'Explore');
        await tester.tap(find.byType(TextField));
        await pumpUntilFound(tester, find.text('Pencarian terakhir'));
        expect(find.text('integrasi'), findsOneWidget);
      }

      await tester.pumpWidget(buildApp());
      await verifyEverything();

      // Tutup lalu buka aplikasi lagi: semuanya harus tetap ada.
      await reopenApp(tester);
      await verifyEverything();
    },
  );

  testWidgets(
    'menyimpan pencarian lewat tombol cari lalu muncul sebagai saran',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await pumpUntilFound(tester, find.text('Komik Integrasi'));
      await openTab(tester, 'Explore');

      await tester.enterText(find.byType(TextField), 'integrasi');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 500));

      // Kosongkan kolom, lalu fokuskan lagi: kata kunci tadi menjadi saran.
      await tester.tap(find.byTooltip('Hapus'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(TextField));
      await pumpUntilFound(tester, find.text('Pencarian terakhir'));
      expect(find.text('integrasi'), findsOneWidget);
    },
  );
}
