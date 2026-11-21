/// Posisi baca terakhir pada satu chapter.
class ReadingProgress {
  const ReadingProgress({
    required this.sourceId,
    required this.comicRemoteId,
    required this.chapterRemoteId,
    required this.pageIndex,
    required this.pageCount,
    required this.scrollOffset,
    required this.aspects,
    required this.updatedAt,
  });

  final String sourceId;
  final String comicRemoteId;
  final String chapterRemoteId;

  /// Halaman di tengah layar, mulai dari 0.
  final int pageIndex;

  /// Jumlah halaman chapter saat disimpan (0 = tidak diketahui).
  final int pageCount;

  /// Posisi gulir dalam satuan lebar layar (offset dibagi lebar).
  final double scrollOffset;

  /// Rasio tinggi/lebar tiap halaman. Null = belum pernah dimuat.
  final List<double?> aspects;

  final DateTime updatedAt;

  /// Selesai jika halaman terakhir sudah tercapai.
  bool get isCompleted => pageCount > 0 && pageIndex >= pageCount - 1;
}
