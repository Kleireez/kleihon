import 'dart:ui';

import '../../domain/entities/chapter.dart';

/// Posisi sebuah chapter di daftar chapter komiknya.
class ChapterNeighbors {
  const ChapterNeighbors({
    required this.index,
    required this.total,
    this.previous,
    this.current,
    this.next,
  });

  /// -1 jika chapter tidak ada di daftar.
  final int index;
  final int total;
  final Chapter? previous;
  final Chapter? current;
  final Chapter? next;

  bool get found => index >= 0;
}

/// [chapters] harus berurutan baca (terlama dulu), sesuai kontrak ComicSource.
ChapterNeighbors resolveChapterNeighbors(
  List<Chapter> chapters,
  String chapterRemoteId,
) {
  final index = chapters.indexWhere((c) => c.remoteId == chapterRemoteId);
  if (index < 0) {
    return ChapterNeighbors(index: -1, total: chapters.length);
  }
  return ChapterNeighbors(
    index: index,
    total: chapters.length,
    previous: index > 0 ? chapters[index - 1] : null,
    current: chapters[index],
    next: index < chapters.length - 1 ? chapters[index + 1] : null,
  );
}

/// Halaman yang berada di tengah layar, dihitung dari posisi gulir dan
/// tinggi halaman. Halaman yang tingginya belum diketahui memakai
/// [defaultAspect] (tinggi dibagi lebar). Nilai bawaan harus sama dengan
/// tinggi placeholder di ReaderPageImage.
int pageIndexAt({
  required double offset,
  required double viewportHeight,
  required double pageWidth,
  required int pageCount,
  required double? Function(int index) aspectOf,
  double defaultAspect = 1.4,
}) {
  if (pageCount <= 0) return 0;
  final target = (offset < 0 ? 0 : offset) + viewportHeight / 2;
  var bottom = 0.0;
  for (var i = 0; i < pageCount; i++) {
    bottom += pageWidth * (aspectOf(i) ?? defaultAspect);
    if (target < bottom) return i;
  }
  return pageCount - 1;
}

/// Posisi gulir tempat tepi atas halaman [index] berada (kebalikan dari
/// [pageIndexAt]). Halaman yang belum diketahui tingginya memakai
/// [defaultAspect].
double pageOffsetOf({
  required int index,
  required double pageWidth,
  required double? Function(int index) aspectOf,
  double defaultAspect = 1.4,
}) {
  var offset = 0.0;
  for (var i = 0; i < index; i++) {
    offset += pageWidth * (aspectOf(i) ?? defaultAspect);
  }
  return offset;
}

/// True jika [position] berada di zona tengah layar: [widthFraction] dari
/// lebar dan [heightFraction] dari tinggi, dipusatkan. Batas termasuk zona.
bool isCenterTap({
  required Offset position,
  required Size size,
  double widthFraction = 0.6,
  double heightFraction = 0.5,
}) {
  final marginX = size.width * (1 - widthFraction) / 2;
  final marginY = size.height * (1 - heightFraction) / 2;
  return position.dx >= marginX &&
      position.dx <= size.width - marginX &&
      position.dy >= marginY &&
      position.dy <= size.height - marginY;
}
