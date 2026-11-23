import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/domain/entities/bookmark.dart';
import 'package:kleihon/domain/entities/reading_status.dart';
import 'package:kleihon/domain/usecases/bookmark_usecases.dart';
import 'package:kleihon/domain/usecases/library_logic.dart';

import '../helpers/fake_bookmark_repository.dart';
import '../helpers/fake_comic_source.dart';

LibraryEntry entry(
  String title, {
  ReadingStatus status = ReadingStatus.unread,
  bool follow = false,
  DateTime? created,
  DateTime? readAt,
}) {
  return LibraryEntry(
    comic: testComic('s', title.toLowerCase(), title),
    bookmark: Bookmark(
      sourceId: 's',
      comicRemoteId: title.toLowerCase(),
      status: status,
      followUpdates: follow,
      createdAt: created ?? DateTime(2026, 11, 1),
    ),
    lastRead: readAt == null
        ? null
        : LastRead(chapterRemoteId: 'c', readAt: readAt),
  );
}

List<String> titles(List<LibraryEntry> entries) => [
  for (final item in entries) item.comic.title,
];

void main() {
  group('autoStatusAfterProgress', () {
    ReadingStatus? auto({
      required ReadingStatus current,
      bool first = false,
      bool completed = false,
      bool last = false,
    }) => autoStatusAfterProgress(
      current: current,
      firstProgressForChapter: first,
      chapterJustCompleted: completed,
      isLastChapter: last,
    );

    test('mulai membaca: belum dibaca menjadi sedang dibaca', () {
      expect(
        auto(current: ReadingStatus.unread, first: true),
        ReadingStatus.reading,
      );
    });

    test('sudah sedang dibaca tidak berubah saat mulai chapter lain', () {
      expect(auto(current: ReadingStatus.reading, first: true), isNull);
    });

    test('selesai lalu mulai chapter baru kembali menjadi sedang dibaca', () {
      expect(
        auto(current: ReadingStatus.completed, first: true),
        ReadingStatus.reading,
      );
    });

    test('chapter terakhir selesai menjadi selesai', () {
      expect(
        auto(current: ReadingStatus.reading, completed: true, last: true),
        ReadingStatus.completed,
      );
      expect(
        auto(current: ReadingStatus.unread, completed: true, last: true),
        ReadingStatus.completed,
      );
    });

    test('sudah selesai tidak berubah lagi', () {
      expect(
        auto(current: ReadingStatus.completed, completed: true, last: true),
        isNull,
      );
    });

    test(
      'chapter selesai tetapi bukan yang terakhir tidak mengubah status',
      () {
        expect(auto(current: ReadingStatus.reading, completed: true), isNull);
      },
    );

    test('chapter terakhir satu halaman: mulai dan selesai sekaligus', () {
      expect(
        auto(
          current: ReadingStatus.unread,
          first: true,
          completed: true,
          last: true,
        ),
        ReadingStatus.completed,
      );
    });

    test('penyimpanan biasa tanpa peristiwa tidak mengubah status manual', () {
      for (final status in ReadingStatus.values) {
        expect(auto(current: status), isNull);
      }
    });
  });

  group('filterLibrary', () {
    final entries = [
      entry('Alpha', status: ReadingStatus.reading, follow: true),
      entry('Beta', status: ReadingStatus.unread),
      entry('Gamma', status: ReadingStatus.completed, follow: true),
    ];

    test('kategori menyaring menurut status dan ikuti update', () {
      expect(titles(filterLibrary(entries)), ['Alpha', 'Beta', 'Gamma']);
      expect(
        titles(filterLibrary(entries, category: LibraryCategory.reading)),
        ['Alpha'],
      );
      expect(titles(filterLibrary(entries, category: LibraryCategory.unread)), [
        'Beta',
      ]);
      expect(
        titles(filterLibrary(entries, category: LibraryCategory.completed)),
        ['Gamma'],
      );
      expect(
        titles(filterLibrary(entries, category: LibraryCategory.following)),
        ['Alpha', 'Gamma'],
      );
    });

    test(
      'pencarian tidak peka huruf besar-kecil dan mengabaikan spasi tepi',
      () {
        expect(titles(filterLibrary(entries, query: '  ALP ')), ['Alpha']);
        expect(filterLibrary(entries, query: 'zzz'), isEmpty);
      },
    );

    test('pencarian juga mencocokkan judul alternatif', () {
      final withAlt = LibraryEntry(
        comic: testComicWithAlternatives('Delta', ['Judul Lain']),
        bookmark: entries.first.bookmark,
      );
      expect(titles(filterLibrary([withAlt], query: 'lain')), ['Delta']);
    });

    test('kategori dan pencarian berlaku bersamaan', () {
      expect(
        filterLibrary(
          entries,
          category: LibraryCategory.completed,
          query: 'alpha',
        ),
        isEmpty,
      );
    });
  });

  group('sortLibrary', () {
    test('terbaru: aktivitas baca, lalu waktu bookmark, terbaru dulu', () {
      final entries = [
        entry('A', created: DateTime(2026, 11, 1)),
        entry('B', readAt: DateTime(2026, 11, 10)),
        entry('C', created: DateTime(2026, 11, 5)),
      ];

      expect(titles(sortLibrary(entries, LibrarySort.recent)), ['B', 'C', 'A']);
    });

    test('terbaru: waktu sama diurutkan menurut judul', () {
      final time = DateTime(2026, 11, 5);
      final entries = [
        entry('Beta', created: time),
        entry('Alpha', created: time),
      ];

      expect(titles(sortLibrary(entries, LibrarySort.recent)), [
        'Alpha',
        'Beta',
      ]);
    });

    test('judul: urutan alami', () {
      final entries = [entry('Komik 10'), entry('Komik 2'), entry('Alpha')];

      expect(titles(sortLibrary(entries, LibrarySort.title)), [
        'Alpha',
        'Komik 2',
        'Komik 10',
      ]);
    });

    test('tidak mengubah daftar asli', () {
      final entries = [entry('B'), entry('A')];

      sortLibrary(entries, LibrarySort.title);

      expect(titles(entries), ['B', 'A']);
    });
  });

  group('countByCategory', () {
    test('menghitung tiap kategori', () {
      final entries = [
        entry('A', status: ReadingStatus.reading, follow: true),
        entry('B', status: ReadingStatus.reading),
        entry('C', status: ReadingStatus.unread),
        entry('D', status: ReadingStatus.completed, follow: true),
      ];

      final counts = countByCategory(entries);

      expect(counts[LibraryCategory.all], 4);
      expect(counts[LibraryCategory.reading], 2);
      expect(counts[LibraryCategory.unread], 1);
      expect(counts[LibraryCategory.completed], 1);
      expect(counts[LibraryCategory.following], 2);
    });

    test('daftar kosong menghasilkan nol di semua kategori', () {
      final counts = countByCategory(const []);

      for (final category in LibraryCategory.values) {
        expect(counts[category], 0);
      }
    });
  });

  group('ToggleBookmark', () {
    test('menambah lalu menghapus dan melaporkan keadaan akhir', () async {
      final repository = FakeBookmarkRepository();
      final toggle = ToggleBookmark(repository);

      expect(await toggle(sourceId: 's', comicRemoteId: 'k'), isTrue);
      expect(
        await repository.getBookmark(sourceId: 's', comicRemoteId: 'k'),
        isNotNull,
      );

      expect(await toggle(sourceId: 's', comicRemoteId: 'k'), isFalse);
      expect(
        await repository.getBookmark(sourceId: 's', comicRemoteId: 'k'),
        isNull,
      );
    });
  });
}
