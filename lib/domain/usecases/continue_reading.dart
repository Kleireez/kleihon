import '../entities/chapter.dart';
import '../entities/reading_progress.dart';

class ContinueTarget {
  const ContinueTarget({
    required this.chapter,
    this.progress,
    this.finished = false,
  });

  final Chapter chapter;

  /// Diisi jika membaca dilanjutkan dari posisi yang tersimpan.
  final ReadingProgress? progress;

  /// True jika semua chapter sudah selesai dibaca. [chapter] adalah yang
  /// terakhir dan akan dibaca ulang dari awal.
  final bool finished;
}

/// Menentukan chapter yang dibuka tombol "Lanjut membaca".
/// [chapters] berurutan baca (terlama dulu). Mengembalikan null jika belum
/// pernah ada progres.
ContinueTarget? resolveContinueTarget({
  required List<Chapter> chapters,
  required Map<String, ReadingProgress> progress,
}) {
  ReadingProgress? last;
  var lastIndex = -1;
  for (var i = 0; i < chapters.length; i++) {
    final entry = progress[chapters[i].remoteId];
    if (entry == null) continue;
    if (last == null || entry.updatedAt.isAfter(last.updatedAt)) {
      last = entry;
      lastIndex = i;
    }
  }

  if (last == null) return null;
  if (!last.isCompleted) {
    return ContinueTarget(chapter: chapters[lastIndex], progress: last);
  }
  if (lastIndex < chapters.length - 1) {
    return ContinueTarget(chapter: chapters[lastIndex + 1]);
  }
  return ContinueTarget(chapter: chapters[lastIndex], finished: true);
}
