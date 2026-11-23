import '../../core/utils/format_date.dart';
import '../../domain/entities/history.dart';

class HistoryGroup {
  const HistoryGroup(this.label, this.entries);

  final String label;
  final List<HistoryEntry> entries;
}

/// Mengelompokkan riwayat per hari, terbaru dulu. Label: "Hari ini",
/// "Kemarin", lalu tanggal.
List<HistoryGroup> groupHistoryByDay(List<HistoryEntry> entries, DateTime now) {
  final sorted = [...entries]..sort((a, b) => b.readAt.compareTo(a.readAt));
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  final groups = <HistoryGroup>[];
  DateTime? currentDay;
  for (final entry in sorted) {
    final local = entry.readAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (currentDay == null || day != currentDay) {
      currentDay = day;
      final label = day == today
          ? 'Hari ini'
          : day == yesterday
          ? 'Kemarin'
          : formatShortDate(day);
      groups.add(HistoryGroup(label, []));
    }
    groups.last.entries.add(entry);
  }
  return groups;
}

/// "Chapter 14 • Halaman 4 / 10", "Chapter 14 • Selesai", atau hanya judul
/// chapter jika halamannya tidak diketahui.
String historySubtitle(HistoryEntry entry) {
  final chapter = entry.chapterTitle ?? 'Chapter terakhir';
  if (entry.isCompleted) return '$chapter • Selesai';
  if (entry.pageCount > 0) {
    return '$chapter • Halaman ${entry.pageIndex + 1} / ${entry.pageCount}';
  }
  return chapter;
}
