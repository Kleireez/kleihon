import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/domain/entities/reading_progress.dart';
import 'package:kleihon/features/comic_detail/progress_labels.dart';

ReadingProgress progress({required int page, required int count}) =>
    ReadingProgress(
      sourceId: 's',
      comicRemoteId: 'k',
      chapterRemoteId: 'c',
      pageIndex: page,
      pageCount: count,
      scrollOffset: 0,
      aspects: const [],
      updatedAt: DateTime(2026, 11, 21),
    );

void main() {
  group('progressLabel', () {
    test('tanpa progres tidak ada label', () {
      expect(progressLabel(null), isNull);
    });

    test('sedang dibaca menampilkan halaman mulai dari 1', () {
      expect(progressLabel(progress(page: 3, count: 10)), 'Halaman 4 / 10');
    });

    test('halaman terakhir berarti selesai', () {
      expect(progressLabel(progress(page: 9, count: 10)), 'Selesai');
    });

    test('jumlah halaman tidak diketahui tidak ada label', () {
      expect(progressLabel(progress(page: 3, count: 0)), isNull);
    });
  });

  group('chapterSubtitle', () {
    test('menggabungkan tanggal dan progres', () {
      expect(
        chapterSubtitle(
          published: DateTime(2026, 11, 5),
          progress: progress(page: 3, count: 10),
        ),
        '05/11/2026 • Halaman 4 / 10',
      );
    });

    test('hanya tanggal, hanya progres, atau tidak ada', () {
      expect(chapterSubtitle(published: DateTime(2026, 11, 5)), '05/11/2026');
      expect(
        chapterSubtitle(progress: progress(page: 9, count: 10)),
        'Selesai',
      );
      expect(chapterSubtitle(), isNull);
    });
  });
}
