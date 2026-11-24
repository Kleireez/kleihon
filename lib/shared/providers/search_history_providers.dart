import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_providers.dart';
import '../../data/repositories/search_history_repository_impl.dart';
import '../../domain/repositories/search_history_repository.dart';

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => SearchHistoryRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// Kata kunci terakhir untuk saran di kolom pencarian.
final recentSearchesProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(searchHistoryRepositoryProvider).watchRecent();
});
