import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/theme/app_theme.dart';
import 'package:kleihon/data/downloads/download_service.dart';
import 'package:kleihon/data/repositories/comic_repository_impl.dart';
import 'package:kleihon/data/sources/source_providers.dart';
import 'package:kleihon/data/sources/source_registry.dart';
import 'package:kleihon/domain/entities/chapter.dart';
import 'package:kleihon/domain/repositories/comic_repository.dart';
import 'package:kleihon/features/reader/reader_settings_providers.dart';
import 'package:kleihon/features/reader/reader_system_ui.dart';
import 'package:kleihon/features/reader/screen_awake.dart';
import 'package:kleihon/features/settings/app_settings.dart';
import 'package:kleihon/features/settings/app_settings_providers.dart';
import 'package:kleihon/shared/providers/bookmark_providers.dart';
import 'package:kleihon/shared/providers/comic_providers.dart';
import 'package:kleihon/shared/providers/download_providers.dart';
import 'package:kleihon/shared/providers/history_providers.dart';
import 'package:kleihon/shared/providers/reading_progress_providers.dart';
import 'package:kleihon/shared/providers/search_history_providers.dart';
import 'package:kleihon/shared/providers/storage_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_app_settings_store.dart';
import 'fake_bookmark_repository.dart';
import 'fake_comic_source.dart';
import 'fake_history_repository.dart';
import 'fake_reader_services.dart';
import 'fake_reading_progress_repository.dart';
import 'fake_search_history_repository.dart';
import 'fake_storage_service.dart';

/// Layar tinggi supaya daftar tidak terpotong di test.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// HANYA UNTUK TEST: tidak menyentuh bilah sistem.
class NoopReaderSystemUi implements ReaderSystemUi {
  const NoopReaderSystemUi();

  @override
  Future<void> enterReader() async {}

  @override
  Future<void> leaveReader() async {}

  @override
  Future<void> hideBars() async {}

  @override
  Future<void> showBars() async {}
}

/// HANYA UNTUK TEST: layanan unduhan kosong tanpa menyentuh database.
class NoopDownloadService implements DownloadService {
  const NoopDownloadService();

  @override
  ComicRepository get repository => throw UnimplementedError();

  @override
  Future<Directory> Function() get downloadsRoot => throw UnimplementedError();

  @override
  Stream<Map<String, DownloadTaskInfo>> watchComicDownloads({
    required String sourceId,
    required String comicRemoteId,
  }) => Stream.value(const {});

  @override
  Future<List<ChapterPage>?> getDownloadedPages({
    required String sourceId,
    required String chapterRemoteId,
  }) async => null;

  @override
  Future<void> enqueue({
    required String sourceId,
    required String comicRemoteId,
    required String chapterRemoteId,
  }) async {}

  @override
  Future<void> deleteDownload({
    required String sourceId,
    required String comicRemoteId,
    required String chapterRemoteId,
  }) async {}
}

/// Membungkus layar dengan sumber palsu. Isi [home] atau [router].
/// Semua penyimpanan diganti versi memori. [theme] mengatur tema yang
/// dipakai (bawaan gelap).
Widget testApp({
  required FakeComicSource source,
  Widget? home,
  GoRouter? router,
  FakeReadingProgressRepository? progress,
  FakeBookmarkRepository? bookmarks,
  FakeHistoryRepository? history,
  FakeSearchHistoryRepository? searchHistory,
  InMemoryReaderSettingsStore? settingsStore,
  InMemoryAppSettingsStore? appSettingsStore,
  AppSettings? appSettings,
  FakeStorageService? storage,
  FakeScreenAwake? screenAwake,
  DateTime Function()? clock,
  ThemeData? theme,
}) {
  assert(
    (home == null) != (router == null),
    'Isi tepat satu: home atau router',
  );
  final appTheme = theme ?? AppTheme.dark;
  return ProviderScope(
    // Tanpa pengulangan otomatis, seperti di aplikasi.
    retry: (retryCount, error) => null,
    overrides: [
      sourceRegistryProvider.overrideWithValue(SourceRegistry([source])),
      comicRepositoryProvider.overrideWith(
        (ref) => ComicRepositoryImpl(ref.watch(sourceRegistryProvider)),
      ),
      downloadServiceProvider.overrideWithValue(const NoopDownloadService()),
      readerSystemUiProvider.overrideWithValue(const NoopReaderSystemUi()),
      readingProgressRepositoryProvider.overrideWithValue(
        progress ?? FakeReadingProgressRepository(),
      ),
      bookmarkRepositoryProvider.overrideWithValue(
        bookmarks ?? FakeBookmarkRepository(),
      ),
      historyRepositoryProvider.overrideWithValue(
        history ?? FakeHistoryRepository(),
      ),
      searchHistoryRepositoryProvider.overrideWithValue(
        searchHistory ?? FakeSearchHistoryRepository(),
      ),
      historyClockProvider.overrideWithValue(clock ?? DateTime.now),
      readerSettingsStoreProvider.overrideWithValue(
        settingsStore ?? InMemoryReaderSettingsStore(),
      ),
      appSettingsStoreProvider.overrideWithValue(
        appSettingsStore ?? InMemoryAppSettingsStore(),
      ),
      initialAppSettingsProvider.overrideWithValue(
        appSettings ?? AppSettings.defaults,
      ),
      storageServiceProvider.overrideWithValue(storage ?? FakeStorageService()),
      readerScreenAwakeProvider.overrideWithValue(
        screenAwake ?? FakeScreenAwake(),
      ),
    ],
    child: router != null
        ? MaterialApp.router(theme: appTheme, routerConfig: router)
        : MaterialApp(theme: appTheme, home: home),
  );
}

/// Halaman penanda untuk menguji tujuan navigasi.
Widget marker(String text) => Scaffold(body: Center(child: Text(text)));
