import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/domain/entities/reading_progress.dart';
import 'package:kleihon/features/reader/reader_progress_saver.dart';

import '../helpers/fake_reading_progress_repository.dart';

/// HANYA UNTUK TEST: penyimpanan yang selalu gagal.
class _FailingRepository extends FakeReadingProgressRepository {
  @override
  Future<void> saveProgress(ReadingProgress progress) async =>
      throw StateError('gagal');
}

const Duration _debounce = Duration(milliseconds: 40);
const Duration _wait = Duration(milliseconds: 150);

void main() {
  late FakeReadingProgressRepository repository;
  late int page;

  ReaderProgressSaver makeSaver({
    FakeReadingProgressRepository? repo,
    ReaderSnapshot? Function()? snapshot,
  }) {
    return ReaderProgressSaver(
      repository: repo ?? repository,
      sourceId: 's',
      comicRemoteId: 'k',
      chapterRemoteId: 'c1',
      debounce: _debounce,
      snapshot:
          snapshot ??
          () => (
            pageIndex: page,
            scrollOffset: page * 2.0,
            pageCount: 10,
            aspects: const [1.0],
          ),
    );
  }

  setUp(() {
    repository = FakeReadingProgressRepository();
    page = 0;
  });

  test(
    'schedule menyimpan sekali setelah jeda dengan keadaan terbaru',
    () async {
      final saver = makeSaver();

      page = 1;
      saver.schedule();
      page = 2;
      saver.schedule();
      page = 3;
      saver.schedule();
      expect(repository.saved, isEmpty);

      await Future<void>.delayed(_wait);

      expect(repository.saved, hasLength(1));
      expect(repository.saved.single.pageIndex, 3);
      expect(repository.saved.single.scrollOffset, 6.0);
      expect(repository.saved.single.pageCount, 10);
      expect(repository.saved.single.chapterRemoteId, 'c1');
    },
  );

  test('flush menyimpan seketika dan membatalkan jeda', () async {
    final saver = makeSaver();

    page = 4;
    saver.schedule();
    await saver.flush();
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.pageIndex, 4);

    // Tidak ada penyimpanan kedua dari timer yang tersisa.
    await Future<void>.delayed(_wait);
    expect(repository.saved, hasLength(1));
  });

  test('flush tanpa perubahan tidak menyimpan apa pun', () async {
    final saver = makeSaver();

    await saver.flush();

    expect(repository.saved, isEmpty);
  });

  test('keadaan yang belum siap tidak disimpan', () async {
    final saver = makeSaver(snapshot: () => null);

    saver.schedule();
    await saver.flush();

    expect(repository.saved, isEmpty);
  });

  test('flush membaca keadaan sebelum await pertama', () async {
    final saver = makeSaver();

    page = 5;
    saver.schedule();
    final pending = saver.flush();
    // Meniru dispose(): keadaan reader berubah setelah flush dipanggil.
    page = 99;
    await pending;

    expect(repository.saved.single.pageIndex, 5);
  });

  test('kegagalan menyimpan tidak melempar', () async {
    final saver = makeSaver(repo: _FailingRepository());

    saver.schedule();

    await saver.flush();
  });
}
