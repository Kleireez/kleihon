import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/features/settings/app_settings.dart';
import 'package:kleihon/features/settings/app_settings_labels.dart';
import 'package:kleihon/features/settings/app_settings_providers.dart';
import 'package:kleihon/features/settings/app_settings_store.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../helpers/fake_app_settings_store.dart';

/// HANYA UNTUK TEST: penyimpanan selalu gagal.
class _FailingSaveStore implements AppSettingsStore {
  @override
  Future<AppSettings> load() async => AppSettings.defaults;

  @override
  Future<void> save(AppSettings settings) async =>
      throw StateError('gagal simpan');
}

ProviderContainer makeContainer(
  AppSettingsStore store, {
  AppSettings? initial,
}) {
  final container = ProviderContainer(
    overrides: [
      appSettingsStoreProvider.overrideWithValue(store),
      if (initial != null)
        initialAppSettingsProvider.overrideWithValue(initial),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('AppSettings', () {
    test('bawaannya tema gelap', () {
      expect(AppSettings.defaults.themeMode, AppThemeMode.dark);
    });

    test('toJson dan fromJson saling membalik', () {
      for (final mode in AppThemeMode.values) {
        final original = AppSettings(themeMode: mode);
        expect(AppSettings.fromJson(original.toJson()), original);
      }
    });

    test('data rusak atau asing memakai nilai bawaan', () {
      expect(AppSettings.fromJson(null), AppSettings.defaults);
      expect(AppSettings.fromJson('bukan map'), AppSettings.defaults);
      expect(AppSettings.fromJson(<String, Object?>{}), AppSettings.defaults);
      expect(AppSettings.fromJson({'themeMode': 'neon'}), AppSettings.defaults);
    });

    test('label dan pemetaan ke ThemeMode untuk setiap pilihan', () {
      expect(AppThemeMode.dark.themeMode, ThemeMode.dark);
      expect(AppThemeMode.light.themeMode, ThemeMode.light);
      expect(AppThemeMode.system.themeMode, ThemeMode.system);
      for (final mode in AppThemeMode.values) {
        expect(mode.label, isNotEmpty);
      }
    });
  });

  group('AppSettingsController', () {
    test('memakai nilai awal dari initialAppSettingsProvider', () {
      final container = makeContainer(
        InMemoryAppSettingsStore(),
        initial: const AppSettings(themeMode: AppThemeMode.light),
      );

      expect(container.read(appSettingsProvider).themeMode, AppThemeMode.light);
    });

    test('tanpa nilai awal memakai bawaan', () {
      final container = makeContainer(InMemoryAppSettingsStore());

      expect(container.read(appSettingsProvider), AppSettings.defaults);
    });

    test('update menerapkan langsung dan menyimpan', () async {
      final store = InMemoryAppSettingsStore();
      final container = makeContainer(store);

      await container
          .read(appSettingsProvider.notifier)
          .update(const AppSettings(themeMode: AppThemeMode.system));

      expect(
        container.read(appSettingsProvider).themeMode,
        AppThemeMode.system,
      );
      expect(store.saved.last.themeMode, AppThemeMode.system);
    });

    test('gagal menyimpan tidak membatalkan pengaturan yang dipakai', () async {
      final container = makeContainer(_FailingSaveStore());

      await container
          .read(appSettingsProvider.notifier)
          .update(const AppSettings(themeMode: AppThemeMode.light));

      expect(container.read(appSettingsProvider).themeMode, AppThemeMode.light);
    });
  });
}
