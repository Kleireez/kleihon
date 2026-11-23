import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/domain/entities/history.dart';
import 'package:kleihon/features/history/history_logic.dart';

import '../helpers/fake_comic_source.dart';

HistoryEntry entry(
  String id, {
  required DateTime readAt,
  String? chapterTitle = 'Chapter 1',
  int page = 0,
  int count = 0,
}) {
  return HistoryEntry(
    comic: testComic('s', id, 'Judul $id'),
    chapterRemoteId: 'c',
    chapterTitle: chapterTitle,
    readAt: readAt,
    pageIndex: page,
    pageCount: count,
  );
}

List<String> labels(List<HistoryGroup> groups) => [
  for (final group in groups) group.label,
];

void main() {
  final now = DateTime(2026, 11, 22, 12);

  group('groupHistoryByDay', () {
    test('Hari ini, Kemarin, lalu tanggal, terbaru dulu', () {
      final groups = groupHistoryByDay([
        entry('lama', readAt: DateTime(2026, 11, 10, 9)),
        entry('kemarin', readAt: DateTime(2026, 11, 21, 23, 30)),
        entry('pagi', readAt: DateTime(2026, 11, 22, 8)),
        entry('siang', readAt: DateTime(2026, 11, 22, 11)),
      ], now);

      expect(labels(groups), ['Hari ini', 'Kemarin', '10/11/2026']);
      expect(
        [for (final e in groups.first.entries) e.comic.remoteId],
        ['siang', 'pagi'],
      );
    });

    test('hari yang sama digabung walau urutan masukan acak', () {
      final groups = groupHistoryByDay([
        entry('a', readAt: DateTime(2026, 11, 22, 8)),
        entry('b', readAt: DateTime(2026, 11, 21, 8)),
        entry('c', readAt: DateTime(2026, 11, 22, 10)),
      ], now);

      expect(labels(groups), ['Hari ini', 'Kemarin']);
      expect(groups.first.entries, hasLength(2));
    });

    test('daftar kosong menghasilkan tanpa kelompok', () {
      expect(groupHistoryByDay(const [], now), isEmpty);
    });

    test('batas tengah malam: 00:00 hari ini, 23:59 kemarin', () {
      final groups = groupHistoryByDay([
        entry('a', readAt: DateTime(2026, 11, 22, 0, 0)),
        entry('b', readAt: DateTime(2026, 11, 21, 23, 59)),
      ], now);

      expect(labels(groups), ['Hari ini', 'Kemarin']);
    });

    test('awal bulan: kemarin dihitung lintas bulan', () {
      final firstOfMonth = DateTime(2026, 12, 1, 12);
      final groups = groupHistoryByDay([
        entry('a', readAt: DateTime(2026, 11, 30, 20)),
      ], firstOfMonth);

      expect(labels(groups), ['Kemarin']);
    });
  });

  group('historySubtitle', () {
    test('dengan halaman', () {
      expect(
        historySubtitle(entry('a', readAt: now, page: 3, count: 10)),
        'Chapter 1 • Halaman 4 / 10',
      );
    });

    test('selesai', () {
      expect(
        historySubtitle(entry('a', readAt: now, page: 9, count: 10)),
        'Chapter 1 • Selesai',
      );
    });

    test('halaman tidak diketahui hanya menampilkan chapter', () {
      expect(historySubtitle(entry('a', readAt: now)), 'Chapter 1');
    });

    test('chapter yang sudah tidak ada', () {
      expect(
        historySubtitle(entry('a', readAt: now, chapterTitle: null)),
        'Chapter terakhir',
      );
    });
  });
}
