import '../../core/utils/natural_compare.dart';
import '../entities/bookmark.dart';
import '../entities/reading_status.dart';

enum LibraryCategory { all, reading, unread, completed, following }

enum LibrarySort { recent, title }

/// Menyaring Library menurut kategori dan kata kunci (judul dan judul
/// alternatif, tidak peka huruf besar-kecil).
List<LibraryEntry> filterLibrary(
  List<LibraryEntry> entries, {
  LibraryCategory category = LibraryCategory.all,
  String query = '',
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final entry in entries)
      if (_inCategory(entry, category) && _matches(entry, needle)) entry,
  ];
}

bool _inCategory(LibraryEntry entry, LibraryCategory category) {
  switch (category) {
    case LibraryCategory.all:
      return true;
    case LibraryCategory.reading:
      return entry.bookmark.status == ReadingStatus.reading;
    case LibraryCategory.unread:
      return entry.bookmark.status == ReadingStatus.unread;
    case LibraryCategory.completed:
      return entry.bookmark.status == ReadingStatus.completed;
    case LibraryCategory.following:
      return entry.bookmark.followUpdates;
  }
}

bool _matches(LibraryEntry entry, String needle) {
  if (needle.isEmpty) return true;
  final comic = entry.comic;
  if (comic.title.toLowerCase().contains(needle)) return true;
  return comic.alternativeTitles.any(
    (title) => title.toLowerCase().contains(needle),
  );
}

/// Mengurutkan Library. [LibrarySort.recent]: aktivitas terbaru dulu.
/// [LibrarySort.title]: judul A-Z (urutan alami).
List<LibraryEntry> sortLibrary(List<LibraryEntry> entries, LibrarySort sort) {
  final sorted = [...entries];
  int byTitle(LibraryEntry a, LibraryEntry b) =>
      naturalCompare(a.comic.title, b.comic.title);

  switch (sort) {
    case LibrarySort.recent:
      sorted.sort((a, b) {
        final byTime = b.activityAt.compareTo(a.activityAt);
        return byTime != 0 ? byTime : byTitle(a, b);
      });
    case LibrarySort.title:
      sorted.sort(byTitle);
  }
  return sorted;
}

/// Jumlah komik per kategori (tidak memperhitungkan kata kunci).
Map<LibraryCategory, int> countByCategory(List<LibraryEntry> entries) => {
  for (final category in LibraryCategory.values)
    category: filterLibrary(entries, category: category).length,
};
