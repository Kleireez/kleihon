abstract class SearchHistoryRepository {
  /// Kata kunci terakhir, terbaru dulu. Memancarkan nilai baru setiap ada
  /// perubahan.
  Stream<List<String>> watchRecent({int limit = 10});

  /// Menyimpan kata kunci. Yang sama (tidak peka huruf besar-kecil) dipindah
  /// ke paling atas. Kata kunci kosong diabaikan.
  Future<void> add(String query);

  /// Tidak melakukan apa pun jika kata kunci tidak ada.
  Future<void> remove(String query);

  Future<void> clearAll();
}
