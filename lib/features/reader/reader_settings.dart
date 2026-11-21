import 'dart:ui';

enum ReaderBackground { black, dark, sepia, white }

extension ReaderBackgroundStyle on ReaderBackground {
  String get label => switch (this) {
    ReaderBackground.black => 'Hitam',
    ReaderBackground.dark => 'Gelap',
    ReaderBackground.sepia => 'Sepia',
    ReaderBackground.white => 'Putih',
  };

  /// Warna latar reader.
  Color get color => switch (this) {
    ReaderBackground.black => const Color(0xFF000000),
    ReaderBackground.dark => const Color(0xFF1A1A1A),
    ReaderBackground.sepia => const Color(0xFFF2E8D5),
    ReaderBackground.white => const Color(0xFFFFFFFF),
  };

  /// Warna kotak halaman yang belum termuat.
  Color get placeholderColor => switch (this) {
    ReaderBackground.black => const Color(0xFF101010),
    ReaderBackground.dark => const Color(0xFF242424),
    ReaderBackground.sepia => const Color(0xFFE6DAC3),
    ReaderBackground.white => const Color(0xFFF0F0F0),
  };

  Color get placeholderTextColor => switch (this) {
    ReaderBackground.black => const Color(0xFF6B6B6B),
    ReaderBackground.dark => const Color(0xFF7A7A7A),
    ReaderBackground.sepia => const Color(0xFF8A7B5E),
    ReaderBackground.white => const Color(0xFF9A9A9A),
  };

  /// Warna teks yang terbaca di atas [color].
  Color get foreground => switch (this) {
    ReaderBackground.black => const Color(0xFFE6E6E6),
    ReaderBackground.dark => const Color(0xFFE6E6E6),
    ReaderBackground.sepia => const Color(0xFF3B3224),
    ReaderBackground.white => const Color(0xFF1F1F1F),
  };
}

class ReaderSettings {
  const ReaderSettings({
    this.background = ReaderBackground.black,
    this.keepScreenOn = true,
  });

  static const ReaderSettings defaults = ReaderSettings();

  final ReaderBackground background;
  final bool keepScreenOn;

  ReaderSettings copyWith({ReaderBackground? background, bool? keepScreenOn}) {
    return ReaderSettings(
      background: background ?? this.background,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }

  Map<String, Object?> toJson() => {
    'background': background.name,
    'keepScreenOn': keepScreenOn,
  };

  /// Toleran terhadap data rusak atau dari versi lain: bagian yang tidak
  /// dikenali memakai nilai bawaan, bagian yang valid tetap dipakai.
  factory ReaderSettings.fromJson(Object? json) {
    if (json is! Map) return defaults;

    final name = json['background'];
    final background =
        ReaderBackground.values
            .where((value) => value.name == name)
            .firstOrNull ??
        defaults.background;
    final keep = json['keepScreenOn'];

    return ReaderSettings(
      background: background,
      keepScreenOn: keep is bool ? keep : defaults.keepScreenOn,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.background == background &&
      other.keepScreenOn == keepScreenOn;

  @override
  int get hashCode => Object.hash(background, keepScreenOn);
}
