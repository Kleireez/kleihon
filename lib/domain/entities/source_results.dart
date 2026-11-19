import 'comic.dart';

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.hasNext,
  });

  final List<T> items;
  final int page;
  final bool hasNext;
}

/// Bagian yang bernilai null berarti sumber tidak menyediakannya.
/// UI harus menampilkan "tidak tersedia", bukan data pengganti.
class HomeData {
  const HomeData({this.latest, this.popular, this.recommended});

  final List<Comic>? latest;
  final List<Comic>? popular;
  final List<Comic>? recommended;
}