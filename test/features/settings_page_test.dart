import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/domain/entities/history.dart';
import 'package:kleihon/features/reader/reader_settings.dart';
import 'package:kleihon/features/settings/app_settings.dart';
import 'package:kleihon/features/settings/app_settings_providers.dart';
import 'package:kleihon/features/settings/settings_page.dart';

import '../helpers/fake_app_settings_store.dart';
import '../helpers/fake_comic_source.dart';
import '../helpers/fake_history_repository.dart';
import '../helpers/fake_reader_services.dart';
import '../helpers/fake_search_history_repository.dart';
import '../helpers/test_app.dart';

Future<void> pumpSettings(
  WidgetTester tester, {
  InMemoryAppSettingsStore? appSettingsStore,
  InMemoryReaderSettingsStore? readerStore,
  FakeHistoryRepository? history,
  FakeSearchHistoryRepository? searchHistory,
}) async {
  useTallScreen(tester);
  await tester.pumpWidget(
    testApp(
      source: FakeComicSource('local'),
      home: const SettingsPage(),
      appSettingsStore: appSettingsStore,
      settingsStore: readerStore,
      history: history,
      searchHistory: searchHistory,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan bagian-bagian Settings', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Tampilan'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Mode baca'), findsOneWidget);
    expect(find.text('Data pribadi'), findsOneWidget);
    expect(find.text('Hapus riwayat baca'), findsOneWidget);
    expect(find.text('Hapus riwayat pencarian'), findsOneWidget);
  });

  testWidgets('mengganti tema menerapkan dan menyimpan pilihan', (
    tester,
  ) async {
    final store = InMemoryAppSettingsStore();
    await pumpSettings(tester, appSettingsStore: store);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(appSettingsProvider).themeMode, AppThemeMode.dark);

    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).themeMode, AppThemeMode.light);
    expect(store.saved.last.themeMode, AppThemeMode.light);

    await tester.tap(find.text('Sistem'));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).themeMode, AppThemeMode.system);
    expect(store.saved.last.themeMode, AppThemeMode.system);
  });

  testWidgets('pengaturan reader bisa diubah dari Settings', (tester) async {
    final readerStore = InMemoryReaderSettingsStore();
    await pumpSettings(tester, readerStore: readerStore);

    await tester.tap(find.text('Putih'));
    await tester.pumpAndSettle();
    expect(readerStore.saved.last.background, ReaderBackground.white);

    await tester.tap(find.text('Kanan → Kiri'));
    await tester.pumpAndSettle();
    expect(readerStore.saved.last.readingMode, ReadingMode.horizontalRtl);
    // Pilihan penyesuaian halaman muncul untuk mode horizontal.
    expect(find.text('Sesuaikan halaman'), findsOneWidget);
  });

  testWidgets(
    'hapus riwayat baca: batal tidak menghapus, konfirmasi menghapus',
    (tester) async {
      final history = FakeHistoryRepository()
        ..seed(
          HistoryEntry(
            comic: testComic('local', 'a'),
            chapterRemoteId: 'c',
            readAt: DateTime(2026, 11, 22),
          ),
        );
      await pumpSettings(tester, history: history);

      await tester.tap(find.text('Hapus riwayat baca'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus riwayat baca?'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(history.clearCalls, 0);

      await tester.tap(find.text('Hapus riwayat baca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(history.clearCalls, 1);
      expect(find.text('Riwayat baca dihapus.'), findsOneWidget);
    },
  );

  testWidgets('hapus riwayat pencarian dengan konfirmasi', (tester) async {
    final searchHistory = FakeSearchHistoryRepository(['alpha', 'beta']);
    await pumpSettings(tester, searchHistory: searchHistory);

    await tester.tap(find.text('Hapus riwayat pencarian'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus riwayat pencarian?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(searchHistory.clearCalls, 0);
    expect(searchHistory.items, ['alpha', 'beta']);

    await tester.tap(find.text('Hapus riwayat pencarian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(searchHistory.clearCalls, 1);
    expect(searchHistory.items, isEmpty);
    expect(find.text('Riwayat pencarian dihapus.'), findsOneWidget);
  });
}
