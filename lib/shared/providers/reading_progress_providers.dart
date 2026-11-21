import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_providers.dart';
import '../../data/repositories/reading_progress_repository_impl.dart';
import '../../domain/repositories/reading_progress_repository.dart';

final readingProgressRepositoryProvider = Provider<ReadingProgressRepository>(
  (ref) => ReadingProgressRepositoryImpl(ref.watch(appDatabaseProvider)),
);
