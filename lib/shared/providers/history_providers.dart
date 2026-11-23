import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_providers.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../domain/entities/history.dart';
import '../../domain/repositories/history_repository.dart';
import 'bookmark_providers.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(coverResolverProvider),
  );
});

final historyEntriesProvider = StreamProvider.autoDispose<List<HistoryEntry>>((
  ref,
) {
  return ref.watch(historyRepositoryProvider).watchHistory();
});

/// Jam untuk pengelompokan hari. Dapat diganti saat test.
final historyClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
