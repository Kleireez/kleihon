import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_providers.dart';
import 'local_comic_source.dart';
import 'local_library.dart';
import 'local_library_layout.dart';

final localLibraryLayoutProvider = Provider<LocalLibraryLayout>((ref) {
  return LocalLibraryLayout(() async {
    // Folder dokumen aplikasi, bukan folder cache.
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'kleihon_library'));
  });
});

final localComicSourceProvider = Provider<LocalComicSource>((ref) {
  return LocalComicSource(
    database: ref.watch(appDatabaseProvider),
    layout: ref.watch(localLibraryLayoutProvider),
  );
});

final localLibraryProvider = Provider<LocalLibrary>((ref) {
  return LocalLibrary(
    database: ref.watch(appDatabaseProvider),
    layout: ref.watch(localLibraryLayoutProvider),
  );
});
