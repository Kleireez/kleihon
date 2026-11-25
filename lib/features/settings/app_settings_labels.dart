import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';

extension AppThemeModeInfo on AppThemeMode {
  String get label => switch (this) {
    AppThemeMode.dark => 'Gelap',
    AppThemeMode.light => 'Terang',
    AppThemeMode.system => 'Sistem',
  };

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.system => ThemeMode.system,
  };
}
