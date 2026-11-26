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

extension AppColorPaletteInfo on AppColorPalette {
  String get label => switch (this) {
    AppColorPalette.brass => 'Antique Brass',
    AppColorPalette.periwinkle => 'Seoul Periwinkle',
    AppColorPalette.crimson => 'Crimson Hanko',
    AppColorPalette.jade => 'Jade Mist',
  };

  Color get previewColor => switch (this) {
    AppColorPalette.brass => const Color(0xFFD6AF66),
    AppColorPalette.periwinkle => const Color(0xFF8B9BFF),
    AppColorPalette.crimson => const Color(0xFFE06C75),
    AppColorPalette.jade => const Color(0xFF57B382),
  };
}
