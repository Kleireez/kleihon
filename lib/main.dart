import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'features/settings/app_settings.dart';
import 'features/settings/app_settings_providers.dart';
import 'features/settings/app_settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tema dimuat sebelum aplikasi digambar, supaya tidak berkedip.
  AppSettings initial;
  try {
    initial = await PrefsAppSettingsStore().load();
  } catch (_) {
    initial = AppSettings.defaults;
  }

  runApp(
    ProviderScope(
      // Kegagalan langsung ditampilkan. Pengguna yang memutuskan mencoba lagi.
      retry: (retryCount, error) => null,
      overrides: [initialAppSettingsProvider.overrideWithValue(initial)],
      child: const KleiHonApp(),
    ),
  );
}
