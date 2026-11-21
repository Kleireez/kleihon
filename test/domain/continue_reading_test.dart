import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/domain/entities/reading_progress.dart';
import 'package:kleihon/domain/usecases/continue_reading.dart';

import '../helpers/fake_comic_source.dart';

ReadingProgress progress(
  String chapterId, {
  required int page,
  int count = 10,
  int minute = 0,
}) => ReadingProgress(
  sourceId: 's',
  comicRemoteId: 'k',
  chapterRemoteId: chapterId,
  pageIndex: page,
  pageCount: count,
  scrollOffset: 0,
  aspects: const [],
  updatedAt: DateTime(2026, 11, 21, 10, minute),
);

void main() {
  final chapters = [
    testChapter('s', 'k', 'c1'),
    testChapter('s', 'k', 'c2'),
    testChapter('s', 'k', 'c3'),
  ];

  test('tanpa progres tidak ada target', () {
    expect(resolveContinueTarget(chapters: chapters, progress: {}), isNull);
  });

  test('melanjutkan chapter yang belum selesai dari posisi tersimpan', () {
    final saved = progress('c2', page: 4);
    final target = resolveContinueTarget(
      chapters: chapters,
      progress: {'c2': saved},
    )!;

    expect(target.chapter.remoteId, 'c2');
    expect(target.progress, saved);
    expect(target.finished, isFalse);
  });

  test('chapter yang baru dibaca menang atas yang lebih lama', () {
    final target = resolveContinueTarget(
      chapters: chapters,
      progress: {
        'c1': progress('c1', page: 3, minute: 5),
        'c3': progress('c3', page: 2, minute: 30),
      },
    )!;

    expect(target.chapter.remoteId, 'c3');
  });

  test('chapter selesai mengarah ke chapter berikutnya dari awal', () {
    final target = resolveContinueTarget(
      chapters: chapters,
      progress: {'c1': progress('c1', page: 9)},
    )!;

    expect(target.chapter.remoteId, 'c2');
    expect(target.progress, isNull);
    expect(target.finished, isFalse);
  });

  test('chapter terakhir yang selesai ditandai semua selesai', () {
    final target = resolveContinueTarget(
      chapters: chapters,
      progress: {'c3': progress('c3', page: 9)},
    )!;

    expect(target.chapter.remoteId, 'c3');
    expect(target.progress, isNull);
    expect(target.finished, isTrue);
  });

  test('progres chapter yang sudah tidak ada diabaikan', () {
    expect(
      resolveContinueTarget(
        chapters: chapters,
        progress: {'hantu': progress('hantu', page: 1)},
      ),
      isNull,
    );
  });

  test('isCompleted butuh jumlah halaman yang diketahui', () {
    expect(progress('c1', page: 9, count: 10).isCompleted, isTrue);
    expect(progress('c1', page: 8, count: 10).isCompleted, isFalse);
    expect(progress('c1', page: 99, count: 0).isCompleted, isFalse);
  });
}
