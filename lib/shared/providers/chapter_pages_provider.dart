import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/chapter.dart';
import 'comic_providers.dart';

typedef ChapterKey = ({String sourceId, String chapterId});

/// Halaman sebuah chapter, berurutan. Dipakai pemilih sampul dan,
/// nanti, reader.
final chapterPagesProvider = FutureProvider.autoDispose
    .family<List<ChapterPage>, ChapterKey>((ref, key) {
      return ref.watch(getChapterPagesProvider)(
        sourceId: key.sourceId,
        chapterRemoteId: key.chapterId,
      );
    });
