import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Naik setiap kali isi perpustakaan lokal berubah (impor, nanti hapus).
/// Layar yang menampilkan daftar komik memuat ulang saat nilainya berubah.
class LibraryRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final libraryRevisionProvider = NotifierProvider<LibraryRevision, int>(
  LibraryRevision.new,
);
