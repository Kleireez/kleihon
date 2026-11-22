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
import 'package:kleihon/data/repositories/reading_progress_repository_impl.dart';
import 'package:kleihon/domain/entities/reading_progress.dart';
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

  Future<void> openExploreTab(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Explore'),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kleihon_e2e_');
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

  testWidgets('alur lengkap: temukan, cari, buka, baca, simpan, lanjutkan', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    // Home menampilkan komik hasil impor.
    await pumpUntilFound(tester, find.text('Komik Integrasi'));

    // Explore: daftar, pencarian berhasil, pencarian tanpa hasil, hapus kata.
    await openExploreTab(tester);
    expect(find.text('Komik Integrasi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'integrasi');
    await tester.pump(const Duration(milliseconds: 700));
    await pumpUntilFound(tester, find.text('Komik Integrasi'));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 700));
    await pumpUntilFound(tester, find.text('Tidak ada hasil untuk "zzz".'));

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 700));
    await pumpUntilFound(tester, find.text('Komik Integrasi'));

    // Detail komik.
    await tester.tap(find.text('Komik Integrasi'));
    await pumpUntilFound(tester, find.text('2 chapter'));
    expect(find.text('Mulai membaca'), findsOneWidget);

    // Reader: chapter pertama punya 3 halaman.
    await tester.tap(find.text('Mulai membaca'));
    await pumpUntilFound(tester, find.textContaining('/ 3'));

    // Pindah ke halaman terakhir lewat slider, lalu keluar.
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await pumpUntilFound(tester, find.text('3 / 3'));
    await tester.tap(find.byTooltip('Kembali'));

    // Progres tersimpan: tombol berubah menjadi Lanjut membaca.
    await pumpUntilFound(tester, find.text('Lanjut membaca'));
    expect(find.text('Mulai membaca'), findsNothing);

    // Melanjutkan membuka chapter berikutnya (2 halaman) atau posisi
    // tersimpan. Yang pasti reader terbuka untuk komik ini.
    await tester.tap(find.text('Lanjut membaca'));
    await pumpUntilFound(tester, find.byTooltip('Pengaturan reader'));
    // Label halaman baru muncul setelah daftar halaman selesai dimuat.
    await pumpUntilFound(tester, find.textContaining(' / '));
  });

  testWidgets('progres tersimpan terbaca setelah aplikasi dibuka ulang', (
    tester,
  ) async {
    // Menyiapkan progres lewat repository asli, seperti hasil sesi membaca.
    await ReadingProgressRepositoryImpl(db).saveProgress(
      ReadingProgress(
        sourceId: 'local',
        comicRemoteId: batch.comicRemoteId,
        chapterRemoteId: batch.chapters.first.chapterRemoteId,
        pageIndex: 1,
        pageCount: 3,
        scrollOffset: 1,
        aspects: const [1.0, 1.0, 1.0],
        updatedAt: DateTime(2026, 11, 21, 10),
      ),
    );

    await tester.pumpWidget(buildApp());
    await pumpUntilFound(tester, find.text('Komik Integrasi'));
    await openExploreTab(tester);
    await tester.tap(find.text('Komik Integrasi'));

    await pumpUntilFound(tester, find.text('Lanjut membaca'));
    expect(find.textContaining('Halaman 2 / 3'), findsOneWidget);
    expect(find.text('Mulai membaca'), findsNothing);

    await tester.tap(find.text('Lanjut membaca'));
    await pumpUntilFound(tester, find.textContaining('/ 3'));
  });
}
