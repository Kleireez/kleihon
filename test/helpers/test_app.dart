import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kleihon/app/theme/app_theme.dart';
import 'package:kleihon/data/sources/source_providers.dart';
import 'package:kleihon/data/sources/source_registry.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_comic_source.dart';

/// Layar tinggi supaya daftar tidak terpotong di test.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Membungkus layar dengan sumber palsu. Isi [home] atau [router].
Widget testApp({
  required FakeComicSource source,
  Widget? home,
  GoRouter? router,
}) {
  assert(
    (home == null) != (router == null),
    'Isi tepat satu: home atau router',
  );
  return ProviderScope(
    // Tanpa pengulangan otomatis, seperti di aplikasi.
    retry: (retryCount, error) => null,
    overrides: [
      sourceRegistryProvider.overrideWithValue(SourceRegistry([source])),
    ],
    child: router != null
        ? MaterialApp.router(theme: AppTheme.dark, routerConfig: router)
        : MaterialApp(theme: AppTheme.dark, home: home),
  );
}

/// Halaman penanda untuk menguji tujuan navigasi.
Widget marker(String text) => Scaffold(body: Center(child: Text(text)));
