import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/reading_progress.dart';
import '../../shared/providers/reading_progress_providers.dart';

typedef ReaderKey = ({String sourceId, String comicId, String chapterId});

/// Progres tersimpan sebuah chapter. Dibaca sekali saat reader dibuka.
final savedProgressProvider = FutureProvider.autoDispose
    .family<ReadingProgress?, ReaderKey>((ref, key) {
      return ref
          .watch(readingProgressRepositoryProvider)
          .getProgress(
            sourceId: key.sourceId,
            comicRemoteId: key.comicId,
            chapterRemoteId: key.chapterId,
          );
    });
