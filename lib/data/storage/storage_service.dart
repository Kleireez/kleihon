import 'dart:io';

/// Informasi dan pembersihan penyimpanan. Dipisah supaya bisa diganti saat test.
abstract class StorageService {
  /// Ukuran total perpustakaan lokal (gambar komik).
  Future<int> libraryBytes();

  /// Ukuran cache (folder sementara aplikasi).
  Future<int> cacheBytes();

  /// Mengosongkan cache. Mengembalikan jumlah byte yang dibebaskan.
  Future<int> clearCache();
}

class DeviceStorageService implements StorageService {
  DeviceStorageService({
    required this.libraryRoot,
    required this.cacheRoot,
    this.onCacheCleared,
  });

  final Future<Directory> Function() libraryRoot;
  final Future<Directory> Function() cacheRoot;

  /// Dipanggil setelah folder cache dikosongkan (misalnya untuk membersihkan
  /// cache gambar di memori).
  final void Function()? onCacheCleared;

  @override
  Future<int> libraryBytes() async => directorySize(await libraryRoot());

  @override
  Future<int> cacheBytes() async => directorySize(await cacheRoot());

  @override
  Future<int> clearCache() async {
    final root = await cacheRoot();
    final before = await directorySize(root);

    if (await root.exists()) {
      final entities = await root.list(followLinks: false).toList();
      for (final entity in entities) {
        try {
          await entity.delete(recursive: true);
        } on FileSystemException {
          // Sedang dipakai proses lain: dilewati, sisanya tetap dibersihkan.
        }
      }
    }
    onCacheCleared?.call();

    final after = await directorySize(root);
    return before > after ? before - after : 0;
  }
}

/// Total ukuran semua berkas di [directory] (rekursif, tanpa mengikuti
/// symlink). Folder yang tidak ada dianggap kosong, dan berkas yang hilang
/// atau tidak terbaca saat dihitung dilewati.
Future<int> directorySize(Directory directory) async {
  if (!await directory.exists()) return 0;

  var total = 0;
  try {
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      try {
        total += await entity.length();
      } on FileSystemException {
        // Hilang saat dihitung.
      }
    }
  } on FileSystemException {
    // Sebagian tidak terbaca: yang sudah terhitung tetap dipakai.
  }
  return total;
}
