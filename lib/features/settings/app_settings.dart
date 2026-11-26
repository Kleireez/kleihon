import '../../data/local/local_library_layout.dart';

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
    this.activeSourceId = localSourceId,
  });

  static const AppSettings defaults = AppSettings();

  final AppThemeMode themeMode;
  final AppColorPalette palette;
  final String activeSourceId;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppColorPalette? palette,
    String? activeSourceId,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
      activeSourceId: activeSourceId ?? this.activeSourceId,
    );
  }

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'palette': palette.name,
    'activeSourceId': activeSourceId,
  };

  /// Toleran terhadap data rusak atau dari versi lain: bagian yang tidak
  /// dikenali memakai nilai bawaan.
  factory AppSettings.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final rawSource = json['activeSourceId'];
    final sourceId = (rawSource is String && rawSource.isNotEmpty)
        ? rawSource
        : defaults.activeSourceId;
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
      activeSourceId: sourceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.palette == palette &&
      other.activeSourceId == activeSourceId;

  @override
  int get hashCode => Object.hash(themeMode, palette, activeSourceId);
}
