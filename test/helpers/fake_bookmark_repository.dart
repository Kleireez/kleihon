import 'dart:async';

import 'package:kleihon/domain/entities/bookmark.dart';
import 'package:kleihon/domain/entities/comic.dart';
import 'package:kleihon/domain/entities/reading_status.dart';
import 'package:kleihon/domain/repositories/bookmark_repository.dart';

/// HANYA UNTUK TEST: bookmark di memori.
class FakeBookmarkRepository implements BookmarkRepository {
  final Map<String, Bookmark> _bookmarks = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Komik yang tersedia untuk Library (kunci: "sourceId|comicRemoteId").
  final Map<String, Comic> comics = {};
  final Map<String, LastRead> lastReads = {};

  /// Panggilan addBookmark, berurutan.
  final List<String> added = [];

  String _key(String sourceId, String comicRemoteId) =>
      '$sourceId|$comicRemoteId';

  /// Menyiapkan bookmark (dan komiknya) tanpa dicatat sebagai panggilan.
  void seed(Bookmark bookmark, {Comic? comic, LastRead? lastRead}) {
    final key = _key(bookmark.sourceId, bookmark.comicRemoteId);
    _bookmarks[key] = bookmark;
    if (comic != null) comics[key] = comic;
    if (lastRead != null) lastReads[key] = lastRead;
    _changes.add(null);
  }

  List<LibraryEntry> _library() => [
    for (final entry in _bookmarks.entries)
      if (comics[entry.key] != null)
        LibraryEntry(
          comic: comics[entry.key]!,
          bookmark: entry.value,
          lastRead: lastReads[entry.key],
        ),
  ];

  @override
  Future<Bookmark?> getBookmark({
    required String sourceId,
    required String comicRemoteId,
  }) async => _bookmarks[_key(sourceId, comicRemoteId)];

  @override
  Stream<Bookmark?> watchBookmark({
    required String sourceId,
    required String comicRemoteId,
  }) async* {
    yield _bookmarks[_key(sourceId, comicRemoteId)];
    await for (final _ in _changes.stream) {
      yield _bookmarks[_key(sourceId, comicRemoteId)];
    }
  }

  @override
  Future<void> addBookmark({
    required String sourceId,
    required String comicRemoteId,
    ReadingStatus status = ReadingStatus.unread,
  }) async {
    final key = _key(sourceId, comicRemoteId);
    added.add(key);
    if (_bookmarks.containsKey(key)) return;
    _bookmarks[key] = Bookmark(
      sourceId: sourceId,
      comicRemoteId: comicRemoteId,
      status: status,
      followUpdates: false,
      createdAt: DateTime(2026, 11, 21),
    );
    _changes.add(null);
  }

  @override
  Future<void> removeBookmark({
    required String sourceId,
    required String comicRemoteId,
  }) async {
    _bookmarks.remove(_key(sourceId, comicRemoteId));
    _changes.add(null);
  }

  Bookmark _copy(Bookmark old, {ReadingStatus? status, bool? follow}) =>
      Bookmark(
        sourceId: old.sourceId,
        comicRemoteId: old.comicRemoteId,
        status: status ?? old.status,
        followUpdates: follow ?? old.followUpdates,
        createdAt: old.createdAt,
      );

  @override
  Future<bool> setReadingStatus({
    required String sourceId,
    required String comicRemoteId,
    required ReadingStatus status,
  }) async {
    final key = _key(sourceId, comicRemoteId);
    final old = _bookmarks[key];
    if (old == null) return false;
    _bookmarks[key] = _copy(old, status: status);
    _changes.add(null);
    return true;
  }

  @override
  Future<bool> setFollowUpdates({
    required String sourceId,
    required String comicRemoteId,
    required bool follow,
  }) async {
    final key = _key(sourceId, comicRemoteId);
    final old = _bookmarks[key];
    if (old == null) return false;
    _bookmarks[key] = _copy(old, follow: follow);
    _changes.add(null);
    return true;
  }

  @override
  Stream<List<LibraryEntry>> watchLibrary() async* {
    yield _library();
    await for (final _ in _changes.stream) {
      yield _library();
    }
  }
}
