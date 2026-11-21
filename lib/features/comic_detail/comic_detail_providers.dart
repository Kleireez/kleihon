import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/chapter.dart';
import '../../domain/entities/comic.dart';
import '../../domain/entities/reading_progress.dart';
import '../../shared/providers/comic_providers.dart';
import '../../shared/providers/library_revision_provider.dart';
import '../../shared/providers/reading_progress_providers.dart';

/// Identitas komik di sebuah sumber. Record memiliki kesamaan berdasarkan
/// nilai, jadi aman dipakai sebagai kunci family.
typedef ComicKey = ({String sourceId, String comicId});

class ComicDetailData {
  const ComicDetailData({required this.comic, required this.chapters});

  final Comic comic;

  /// Urutan baca: dari chapter paling awal ke yang terbaru.
  final List<Chapter> chapters;
}

final comicDetailProvider = FutureProvider.autoDispose
    .family<ComicDetailData, ComicKey>((ref, key) async {
      ref.watch(libraryRevisionProvider);
      final getDetail = ref.watch(getComicDetailProvider);
      final getChapters = ref.watch(getAllChaptersProvider);

      // Berurutan, bukan paralel: kegagalan tetap berupa AppException asli
      // dan tidak ada error yang tertinggal tanpa penanganan.
      final comic = await getDetail(
        sourceId: key.sourceId,
        comicRemoteId: key.comicId,
      );
      final chapters = await getChapters(
        sourceId: key.sourceId,
        comicRemoteId: key.comicId,
      );

      return ComicDetailData(comic: comic, chapters: chapters);
    });

/// Progres baca semua chapter sebuah komik, dengan kunci chapterRemoteId.
/// Diperbarui otomatis saat progres disimpan.
final comicProgressProvider = StreamProvider.autoDispose
    .family<Map<String, ReadingProgress>, ComicKey>((ref, key) {
      return ref
          .watch(readingProgressRepositoryProvider)
          .watchComicProgress(
            sourceId: key.sourceId,
            comicRemoteId: key.comicId,
          );
    });
