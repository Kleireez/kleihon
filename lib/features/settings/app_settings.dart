enum AppThemeMode { dark, light, system }

enum AppColorPalette { brass, periwinkle, crimson, jade }

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Pengaturan umum aplikasi (di luar pengaturan reader).
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.palette = AppColorPalette.brass,
  });

  static const AppSettings defaults = AppSettings();

  final AppThemeMode themeMode;
  final AppColorPalette palette;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppColorPalette? palette,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
    );
  }

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'palette': palette.name,
  };

  /// Toleran terhadap data rusak atau dari versi lain: bagian yang tidak
  /// dikenali memakai nilai bawaan.
  factory AppSettings.fromJson(Object? json) {
    if (json is! Map) return defaults;
    return AppSettings(
      themeMode: _byName(
        AppThemeMode.values,
        json['themeMode'],
        defaults.themeMode,
      ),
      palette: _byName(
        AppColorPalette.values,
        json['palette'],
        defaults.palette,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.palette == palette;

  @override
  int get hashCode => Object.hash(themeMode, palette);
}
