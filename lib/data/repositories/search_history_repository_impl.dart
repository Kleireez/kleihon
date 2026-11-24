import 'package:drift/drift.dart';

import '../../domain/entities/search_query.dart';
import '../../domain/repositories/search_history_repository.dart';
import '../database/app_database.dart';

class SearchHistoryRepositoryImpl implements SearchHistoryRepository {
  SearchHistoryRepositoryImpl(
    this._db, {
    this.maxEntries = 50,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;

  /// Entri terlama dibuang jika jumlahnya melebihi ini.
  final int maxEntries;
  final DateTime Function() _clock;

  @override
  Stream<List<String>> watchRecent({int limit = 10}) {
    final query = _db.select(_db.searchHistoryEntries)
      ..orderBy([
        (t) => OrderingTerm.desc(t.searchedAt),
        // Waktu disimpan per detik, jadi id menentukan urutan yang sama.
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit);
    return query.watch().map((rows) => [for (final row in rows) row.query]);
  }

  @override
  Future<void> add(String query) async {
    final normalized = normalizeSearchQuery(query);
    if (normalized.isEmpty) return;

    await _db.transaction(() async {
      await _deleteMatching(normalized);
      await _db
          .into(_db.searchHistoryEntries)
          .insert(
            SearchHistoryEntriesCompanion.insert(
              query: normalized,
              searchedAt: Value(_clock()),
            ),
          );

      // Menjaga jumlah entri: yang paling lama dibuang.
      final rows =
          await (_db.select(_db.searchHistoryEntries)..orderBy([
                (t) => OrderingTerm.desc(t.searchedAt),
                (t) => OrderingTerm.desc(t.id),
              ]))
              .get();
      if (rows.length > maxEntries) {
        final stale = [for (final row in rows.skip(maxEntries)) row.id];
        await (_db.delete(
          _db.searchHistoryEntries,
        )..where((t) => t.id.isIn(stale))).go();
      }
    });
  }

  @override
  Future<void> remove(String query) async {
    final normalized = normalizeSearchQuery(query);
    if (normalized.isEmpty) return;
    await _deleteMatching(normalized);
  }

  @override
  Future<void> clearAll() async {
    await _db.delete(_db.searchHistoryEntries).go();
  }

  /// Menghapus entri yang sama tanpa memperhatikan huruf besar-kecil.
  Future<void> _deleteMatching(String normalized) async {
    final lower = normalized.toLowerCase();
    final rows = await _db.select(_db.searchHistoryEntries).get();
    final ids = [
      for (final row in rows)
        if (row.query.toLowerCase() == lower) row.id,
    ];
    if (ids.isEmpty) return;
    await (_db.delete(
      _db.searchHistoryEntries,
    )..where((t) => t.id.isIn(ids))).go();
  }
}
