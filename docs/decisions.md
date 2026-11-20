# Keputusan proyek
## 2026-11-20: Sumber awal adalah perpustakaan lokal

Konteks:
- Shinigami: tidak ada API publik atau izin terdokumentasi. Layanan pihak
  ketiga yang dicoba mengembalikan 403. Lihat docs/shinigami_api_research.md.
- MangaDex: API publik terdokumentasi, tetapi tidak dapat dijangkau dari
  jaringan developer (diblokir oleh penyedia internet).
  Lihat docs/mangadex_api_research.md.

Keputusan:
- Sumber pertama adalah LocalComicSource, yang membaca komik milik pengguna
  (CBZ/ZIP) yang diimpor ke penyimpanan aplikasi.
- Sumber online ditambahkan nanti lewat ComicSource bila ada akses yang sah
  dan dapat dijangkau.
- Format yang didukung pertama: CBZ/ZIP berisi gambar (jpg, jpeg, png, webp).
  PDF, CBR/RAR, dan folder gambar ditunda.

Konsekuensi:
- Phase 2 (sumber online) ditunda, Phase 3-5 dikerjakan dengan sumber lokal.
- Pembersihan cache tidak boleh menghapus data sumber 'local'.