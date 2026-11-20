import 'dart:io';

import 'package:path/path.dart' as p;

const String localSourceId = 'local';

/// Menentukan lokasi berkas komik lokal.
/// Database hanya menyimpan path relatif terhadap folder akar perpustakaan.
class LocalLibraryLayout {
  LocalLibraryLayout(this._rootResolver);

  final Future<Directory> Function() _rootResolver;
  Directory? _root;

  Future<Directory> root() async => _root ??= await _rootResolver();

  static String chapterRelativePath(
    String comicRemoteId,
    String chapterRemoteId,
  ) => p.posix.join('comics', comicRemoteId, chapterRemoteId);

  Future<String> _absolute(String relativePath) async {
    final parts = p.posix.split(relativePath);
    if (p.posix.isAbsolute(relativePath) || parts.contains('..')) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Path tidak valid',
      );
    }
    final base = await root();
    return p.joinAll([base.path, ...parts]);
  }

  Future<Directory> resolveDirectory(String relativePath) async =>
      Directory(await _absolute(relativePath));

  Future<File> resolveFile(String relativePath) async =>
      File(await _absolute(relativePath));
}
