import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/database/app_database.dart' as db;
import 'package:kleihon/data/repositories/bookmark_repository_impl.dart';
import 'package:kleihon/domain/entities/bookmark.dart';
import 'package:kleihon/domain/entities/reading_status.dart';

void main() {
  late db.AppDatabase database;
  late BookmarkRepositoryImpl repository;

  Future<void> insertComic(String remoteId, {String? cover, String? title}) {
    return database
        .into(database.comics)
        .insert(
          db.ComicsCompanion.insert(
            id: 's:$remoteId',
            sourceId: 's',
            remoteId: remoteId,
            title: title ?? 'Judul $remoteId',
            sourceUrl: 'https://example.invalid/$remoteId',
            coverUrl: Value(cover),
          ),
        );
  }

  Future<void> add(String remoteId, {ReadingStatus? status}) {
    return repository.addBookmark(
      sourceId: 's',
      comicRemoteId: remoteId,
      status: status ?? ReadingStatus.unread,
    );
  }

  Future<Bookmark?> get(String remoteId) =>
      repository.getBookmark(sourceId: 's', comicRemoteId: remoteId);

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repository = BookmarkRepositoryImpl(
      database,
      (sourceId, stored) async => stored == null ? null : 'resolved:$stored',
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('bookmark tersimpan dan terbaca kembali', () async {
    await insertComic('k1');
    expect(await get('k1'), isNull);

    await add('k1');

    final bookmark = (await get('k1'))!;
    expect(bookmark.sourceId, 's');
    expect(bookmark.comicRemoteId, 'k1');
    expect(bookmark.status, ReadingStatus.unread);
    expect(bookmark.followUpdates, isFalse);
  });

  test('menambah dua kali tidak mengubah status yang sudah ada', () async {
    await insertComic('k1');
    await add('k1', status: ReadingStatus.reading);

    await add('k1', status: ReadingStatus.unread);

    expect((await get('k1'))!.status, ReadingStatus.reading);
    expect(await database.select(database.bookmarks).get(), hasLength(1));
  });

  test('komik yang tidak ada ditolak', () async {
    await expectLater(add('hantu'), throwsA(anything));

    expect(await database.select(database.bookmarks).get(), isEmpty);
  });

  test('hapus bookmark, dan menghapus yang tidak ada tidak error', () async {
    await insertComic('k1');
    await add('k1');

    await repository.removeBookmark(sourceId: 's', comicRemoteId: 'k1');
    expect(await get('k1'), isNull);

    await repository.removeBookmark(sourceId: 's', comicRemoteId: 'k1');
    await repository.removeBookmark(sourceId: 's', comicRemoteId: 'hantu');
  });

  test(
    'ubah status dan ikuti update melaporkan ada tidaknya bookmark',
    () async {
      await insertComic('k1');
      await add('k1');

      expect(
        await repository.setReadingStatus(
          sourceId: 's',
          comicRemoteId: 'k1',
          status: ReadingStatus.completed,
        ),
        isTrue,
      );
      expect(
        await repository.setFollowUpdates(
          sourceId: 's',
          comicRemoteId: 'k1',
          follow: true,
        ),
        isTrue,
      );
      final bookmark = (await get('k1'))!;
      expect(bookmark.status, ReadingStatus.completed);
      expect(bookmark.followUpdates, isTrue);

      expect(
        await repository.setReadingStatus(
          sourceId: 's',
          comicRemoteId: 'hantu',
          status: ReadingStatus.reading,
        ),
        isFalse,
      );
      expect(
        await repository.setFollowUpdates(
          sourceId: 's',
          comicRemoteId: 'hantu',
          follow: true,
        ),
        isFalse,
      );
    },
  );

  test('watchBookmark memancarkan setiap perubahan', () async {
    await insertComic('k1');

    final emissions = <Bookmark?>[];
    final subscription = repository
        .watchBookmark(sourceId: 's', comicRemoteId: 'k1')
        .listen(emissions.add);
    await pumpEventQueue();
    expect(emissions.last, isNull);

    await add('k1');
    await pumpEventQueue();
    expect(emissions.last?.status, ReadingStatus.unread);

    await repository.setReadingStatus(
      sourceId: 's',
      comicRemoteId: 'k1',
      status: ReadingStatus.reading,
    );
    await pumpEventQueue();
    expect(emissions.last?.status, ReadingStatus.reading);

    await repository.removeBookmark(sourceId: 's', comicRemoteId: 'k1');
    await pumpEventQueue();
    expect(emissions.last, isNull);

    await subscription.cancel();
  });

  test(
    'watchLibrary hanya berisi komik ber-bookmark dengan data lengkap',
    () async {
      await insertComic('k1', cover: 'a/cover.jpg', title: 'Komik Satu');
      await insertComic('k2', title: 'Komik Dua');

      final emissions = <List<LibraryEntry>>[];
      final subscription = repository.watchLibrary().listen(emissions.add);
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await add('k1');
      await pumpEventQueue();
      expect(emissions.last, hasLength(1));
      final entry = emissions.last.single;
      expect(entry.comic.title, 'Komik Satu');
      expect(entry.comic.coverUrl, 'resolved:a/cover.jpg');
      expect(entry.bookmark.comicRemoteId, 'k1');
      expect(entry.lastRead, isNull);

      // Riwayat baca dan judul chapter ikut muncul.
      await database
          .into(database.chapters)
          .insert(
            db.ChaptersCompanion.insert(
              id: 's:c1',
              comicId: 's:k1',
              title: 'Chapter 1',
              chapterUrl: 'x',
            ),
          );
      await database
          .into(database.readingHistoryEntries)
          .insert(
            db.ReadingHistoryEntriesCompanion.insert(
              comicId: 's:k1',
              chapterId: 's:c1',
              lastReadAt: Value(DateTime(2026, 11, 21, 10)),
            ),
          );
      await pumpEventQueue();
      final withHistory = emissions.last.single;
      expect(withHistory.lastRead?.chapterRemoteId, 'c1');
      expect(withHistory.lastRead?.chapterTitle, 'Chapter 1');
      expect(withHistory.lastRead?.readAt, DateTime(2026, 11, 21, 10));
      expect(withHistory.activityAt, DateTime(2026, 11, 21, 10));

      await repository.removeBookmark(sourceId: 's', comicRemoteId: 'k1');
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await subscription.cancel();
    },
  );
}
