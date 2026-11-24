/// Panjang maksimal kata kunci yang disimpan.
const int maxSearchQueryLength = 100;

/// Merapikan kata kunci: spasi di tepi dibuang, spasi, tab, dan baris baru
/// di tengah menjadi satu spasi, dan dipotong jika terlalu panjang. Huruf
/// besar-kecil dipertahankan. Hasil kosong berarti kata kunci tidak valid.
String normalizeSearchQuery(String raw) {
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (collapsed.length <= maxSearchQueryLength) return collapsed;
  return collapsed.substring(0, maxSearchQueryLength).trim();
}
