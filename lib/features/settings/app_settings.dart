enum AppThemeMode { dark, light, system }

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Pengaturan umum aplikasi (di luar pengaturan reader).
class AppSettings {
  const AppSettings({this.themeMode = AppThemeMode.dark});

  static const AppSettings defaults = AppSettings();

  final AppThemeMode themeMode;

  AppSettings copyWith({AppThemeMode? themeMode}) {
    return AppSettings(themeMode: themeMode ?? this.themeMode);
  }

  Map<String, Object?> toJson() => {'themeMode': themeMode.name};

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
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.themeMode == themeMode;

  @override
  int get hashCode => themeMode.hashCode;
}
