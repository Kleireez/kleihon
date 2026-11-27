import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/chapter.dart';
import 'comic_providers.dart';
import 'download_providers.dart';

typedef ChapterKey = ({String sourceId, String chapterId});

/// Halaman sebuah chapter, berurutan. Mendahulukan berkas unduhan offline jika
/// sudah tersedia di perangkat.
final chapterPagesProvider = FutureProvider.autoDispose
    .family<List<ChapterPage>, ChapterKey>((ref, key) async {
      final offline = await ref
          .watch(downloadServiceProvider)
          .getDownloadedPages(
            sourceId: key.sourceId,
            chapterRemoteId: key.chapterId,
          );
      if (offline != null) return offline;

      return ref.watch(getChapterPagesProvider)(
        sourceId: key.sourceId,
        chapterRemoteId: key.chapterId,
      );
    });
