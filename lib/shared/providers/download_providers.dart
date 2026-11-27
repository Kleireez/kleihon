import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/database_providers.dart';
import '../../data/downloads/download_service.dart';
import '../../features/comic_detail/comic_detail_providers.dart';
import 'comic_providers.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(
    database: ref.watch(appDatabaseProvider),
    repository: ref.watch(comicRepositoryProvider),
    downloadsRoot: () async {
      final docs = await getApplicationDocumentsDirectory();
      return Directory(p.join(docs.path, 'downloads'));
    },
  );
});

final comicDownloadsProvider = StreamProvider.autoDispose
    .family<Map<String, DownloadTaskInfo>, ComicKey>((ref, key) {
      return ref
          .watch(downloadServiceProvider)
          .watchComicDownloads(
            sourceId: key.sourceId,
            comicRemoteId: key.comicId,
          );
    });
