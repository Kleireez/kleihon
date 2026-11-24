import 'dart:async';

import 'package:kleihon/domain/entities/search_query.dart';
import 'package:kleihon/domain/repositories/search_history_repository.dart';

/// HANYA UNTUK TEST: riwayat pencarian di memori (terbaru di indeks 0).
class FakeSearchHistoryRepository implements SearchHistoryRepository {
  FakeSearchHistoryRepository([List<String> initial = const []])
    : _items = [...initial];

  final List<String> _items;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Kata kunci yang diteruskan ke add, berurutan (sudah dirapikan).
  final List<String> added = [];
  int clearCalls = 0;

  List<String> get items => List.unmodifiable(_items);

  void _removeMatching(String normalized) {
    final lower = normalized.toLowerCase();
    _items.removeWhere((item) => item.toLowerCase() == lower);
  }

  @override
  Stream<List<String>> watchRecent({int limit = 10}) async* {
    yield _items.take(limit).toList();
    await for (final _ in _changes.stream) {
      yield _items.take(limit).toList();
    }
  }

  @override
  Future<void> add(String query) async {
    final normalized = normalizeSearchQuery(query);
    if (normalized.isEmpty) return;
    added.add(normalized);
    _removeMatching(normalized);
    _items.insert(0, normalized);
    _changes.add(null);
  }

  @override
  Future<void> remove(String query) async {
    final normalized = normalizeSearchQuery(query);
    if (normalized.isEmpty) return;
    _removeMatching(normalized);
    _changes.add(null);
  }

  @override
  Future<void> clearAll() async {
    clearCalls++;
    _items.clear();
    _changes.add(null);
  }
}
