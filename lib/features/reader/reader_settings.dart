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

/// Cara halaman ditampilkan dan digeser.
enum ReadingMode { vertical, horizontalLtr, horizontalRtl }

extension ReadingModeInfo on ReadingMode {
  String get label => switch (this) {
    ReadingMode.vertical => 'Vertikal',
    ReadingMode.horizontalLtr => 'Kiri → Kanan',
    ReadingMode.horizontalRtl => 'Kanan → Kiri',
  };

  bool get isHorizontal => this != ReadingMode.vertical;

  /// Halaman berikutnya berada di sebelah kiri (gaya manga Jepang).
  bool get isRtl => this == ReadingMode.horizontalRtl;
}

/// Penyesuaian halaman pada mode horizontal.
enum PageFit { width, height }

extension PageFitInfo on PageFit {
  String get label => switch (this) {
    PageFit.width => 'Lebar',
    PageFit.height => 'Tinggi',
  };
}

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

class ReaderSettings {
  const ReaderSettings({
    this.background = ReaderBackground.black,
    this.keepScreenOn = true,
    this.readingMode = ReadingMode.vertical,
    this.pageFit = PageFit.height,
  });

  static const ReaderSettings defaults = ReaderSettings();

  final ReaderBackground background;
  final bool keepScreenOn;
  final ReadingMode readingMode;

  /// Hanya berlaku pada mode horizontal.
  final PageFit pageFit;

  ReaderSettings copyWith({
    ReaderBackground? background,
    bool? keepScreenOn,
    ReadingMode? readingMode,
    PageFit? pageFit,
  }) {
    return ReaderSettings(
      background: background ?? this.background,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      readingMode: readingMode ?? this.readingMode,
      pageFit: pageFit ?? this.pageFit,
    );
  }

  Map<String, Object?> toJson() => {
    'background': background.name,
    'keepScreenOn': keepScreenOn,
    'readingMode': readingMode.name,
    'pageFit': pageFit.name,
  };

  /// Toleran terhadap data rusak atau dari versi lain: bagian yang tidak
  /// dikenali memakai nilai bawaan, bagian yang valid tetap dipakai.
  factory ReaderSettings.fromJson(Object? json) {
    if (json is! Map) return defaults;

    final keep = json['keepScreenOn'];

    return ReaderSettings(
      background: _byName(
        ReaderBackground.values,
        json['background'],
        defaults.background,
      ),
      keepScreenOn: keep is bool ? keep : defaults.keepScreenOn,
      readingMode: _byName(
        ReadingMode.values,
        json['readingMode'],
        defaults.readingMode,
      ),
      pageFit: _byName(PageFit.values, json['pageFit'], defaults.pageFit),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.background == background &&
      other.keepScreenOn == keepScreenOn &&
      other.readingMode == readingMode &&
      other.pageFit == pageFit;

  @override
  int get hashCode =>
      Object.hash(background, keepScreenOn, readingMode, pageFit);
}
