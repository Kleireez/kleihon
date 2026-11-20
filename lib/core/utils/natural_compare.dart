final RegExp _chunkPattern = RegExp(r'\d+|\D+');

List<String> _chunks(String value) =>
    _chunkPattern.allMatches(value).map((m) => m.group(0)!).toList();

/// Urutan alami: "ch2" sebelum "ch10", tidak peka huruf besar-kecil.
int naturalCompare(String a, String b) {
  final left = _chunks(a.toLowerCase());
  final right = _chunks(b.toLowerCase());
  final shared = left.length < right.length ? left.length : right.length;

  for (var i = 0; i < shared; i++) {
    final x = left[i];
    final y = right[i];
    final xn = int.tryParse(x);
    final yn = int.tryParse(y);
    final result = (xn != null && yn != null)
        ? xn.compareTo(yn)
        : x.compareTo(y);
    if (result != 0) return result;
  }

  final byLength = left.length.compareTo(right.length);
  return byLength != 0 ? byLength : a.compareTo(b);
}
