# Riset API MangaDex

Tanggal: 20 November 2026
Status: **Kandidat. Aturan dibaca, belum diuji.**
Sumber: https://api.mangadex.org/docs (halaman "Limitations and Requirements"
dan spesifikasi OpenAPI)

## Aturan pemakaian (dari dokumentasi resmi)

- Wajib mencantumkan kredit untuk MangaDex, dan untuk grup scanlation
  jika aplikasi menampilkan chapter.
- Dilarang menjalankan iklan atau layanan berbayar pada aplikasi yang
  memakai API.
- Batas global sekitar 5 request/detik per IP.
  `GET /at-home/server/{id}`: 40 request/menit.
- Respons 429 harus dihormati (jangan retry langsung).
- Gambar yang di-hotlink dilayani dengan respons salah. Dokumentasi
  meminta permintaan gambar lewat proxy. Penerapan untuk aplikasi
  seluler BELUM DIPASTIKAN.
- Gunakan User-Agent jujur untuk aplikasi sendiri. Jangan meniru aplikasi lain.

## Cara membaca chapter

- URL halaman = server + token sementara + mode kualitas (`data` /
  `data-saver`) + hash chapter + nama file.
- Server didapat dari `GET /at-home/server/{chapterId}`.
- URL bersifat sementara: jangan disimpan lama.

## Belum diketahui

- Jumlah konten berbahasa Indonesia.
- Perlu tidaknya login untuk membaca.
- Aturan unduhan offline.
- Penerapan aturan hotlink untuk aplikasi seluler.