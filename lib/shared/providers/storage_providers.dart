import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/local/local_providers.dart';
import '../../data/storage/storage_service.dart';
import 'library_revision_provider.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  final layout = ref.watch(localLibraryLayoutProvider);
  return DeviceStorageService(
    libraryRoot: layout.root,
    cacheRoot: getTemporaryDirectory,
    onCacheCleared: () {
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.clear();
      imageCache.clearLiveImages();
    },
  );
});

class StorageUsage {
  const StorageUsage({required this.libraryBytes, required this.cacheBytes});

  final int libraryBytes;
  final int cacheBytes;
}

/// Pemakaian penyimpanan. Dihitung ulang saat isi perpustakaan berubah.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>((
  ref,
) async {
  ref.watch(libraryRevisionProvider);
  final service = ref.watch(storageServiceProvider);

  // Berurutan, supaya kegagalan tetap berupa error aslinya.
  final library = await service.libraryBytes();
  final cache = await service.cacheBytes();
  return StorageUsage(libraryBytes: library, cacheBytes: cache);
});
