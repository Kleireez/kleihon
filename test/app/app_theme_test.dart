import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/app.dart';
import 'package:kleihon/app/router.dart';
import 'package:kleihon/app/theme/app_theme.dart';
import 'package:kleihon/features/reader/reader_settings_providers.dart';
import 'package:kleihon/features/settings/app_settings.dart';
import 'package:kleihon/features/settings/app_settings_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_app_settings_store.dart';
import '../helpers/fake_reader_services.dart';

Widget buildApp(AppSettings settings) {
  return ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(
        GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (c, s) => const Scaffold(body: Text('HOME')),
            ),
          ],
        ),
      ),
      initialAppSettingsProvider.overrideWithValue(settings),
      appSettingsStoreProvider.overrideWithValue(
        InMemoryAppSettingsStore(settings),
      ),
      readerSettingsStoreProvider.overrideWithValue(
        InMemoryReaderSettingsStore(),
      ),
    ],
    child: const KleiHonApp(),
  );
}

ThemeMode themeModeOf(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  test('tema terang dan gelap punya kecerahan yang benar', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  testWidgets('aplikasi memakai tema dari pengaturan', (tester) async {
    for (final entry in {
      AppThemeMode.dark: ThemeMode.dark,
      AppThemeMode.light: ThemeMode.light,
      AppThemeMode.system: ThemeMode.system,
    }.entries) {
      await tester.pumpWidget(buildApp(AppSettings(themeMode: entry.key)));
      await tester.pumpAndSettle();

      expect(themeModeOf(tester), entry.value, reason: entry.key.name);
    }
  });

  testWidgets('mengubah pengaturan tema langsung mengubah tampilan', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(AppSettings.defaults));
    await tester.pumpAndSettle();
    expect(themeModeOf(tester), ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('HOME'))).brightness,
      Brightness.dark,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.text('HOME')),
    );
    await container
        .read(appSettingsProvider.notifier)
        .update(const AppSettings(themeMode: AppThemeMode.light));
    await tester.pumpAndSettle();

    expect(themeModeOf(tester), ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('HOME'))).brightness,
      Brightness.light,
    );
  });
}
