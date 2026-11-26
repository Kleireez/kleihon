import 'package:kleihon/data/storage/storage_service.dart';

/// HANYA UNTUK TEST: pemakaian penyimpanan yang diatur manual.
class FakeStorageService implements StorageService {
  FakeStorageService({
    this.library = 0,
    this.cache = 0,
    this.failReads = false,
  });

  int library;
  int cache;

  /// Jika true, penghitungan ukuran gagal.
  bool failReads;
  int clearCalls = 0;

  @override
  Future<int> libraryBytes() async {
    if (failReads) throw StateError('gagal hitung');
    return library;
  }

  @override
  Future<int> cacheBytes() async {
    if (failReads) throw StateError('gagal hitung');
    return cache;
  }

  @override
  Future<int> clearCache() async {
    clearCalls++;
    final freed = cache;
    cache = 0;
    return freed;
  }
}
