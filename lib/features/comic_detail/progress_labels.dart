import '../../core/utils/format_date.dart';
import '../../domain/entities/reading_progress.dart';

/// "Selesai" atau "Halaman 4 / 10". Null jika tidak ada yang perlu ditampilkan.
String? progressLabel(ReadingProgress? progress) {
  if (progress == null) return null;
  if (progress.isCompleted) return 'Selesai';
  if (progress.pageCount <= 0) return null;
  return 'Halaman ${progress.pageIndex + 1} / ${progress.pageCount}';
}

/// Teks kecil di bawah judul chapter: tanggal terbit dan progres.
String? chapterSubtitle({DateTime? published, ReadingProgress? progress}) {
  final parts = <String>[
    if (published != null) formatShortDate(published),
    ?progressLabel(progress),
  ];
  return parts.isEmpty ? null : parts.join(' • ');
}
