import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/reader/reader_settings_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class KleiHonApp extends ConsumerWidget {
  const KleiHonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Memuat pengaturan reader sejak awal supaya reader tidak berkedip.
    ref.listen(readerSettingsProvider, (previous, next) {});

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'KleiHon',
      theme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
