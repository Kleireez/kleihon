# Daftar periksa rilis

Jalankan pada build release sebelum menyatakan sebuah versi stabil.

Tanggal:
Versi:
Perangkat:

## Otomatis

- [ ] `flutter analyze` bersih
- [ ] `flutter test` lulus
- [ ] `flutter test integration_test -d <id perangkat>` lulus
- [ ] `flutter build apk --release` berhasil

## Uji asap di build release (`flutter run --release`)

- [ ] Aplikasi terbuka, Home menampilkan komik (SQLite berjalan)
- [ ] Explore: pencarian, tombol cari, saran pencarian
- [ ] Bookmark dan Library
- [ ] Reader vertikal: gulir mulus, slider halaman
- [ ] Reader horizontal (kiri ke kanan dan kanan ke kiri)
- [ ] History dan tombol Lanjut membaca
- [ ] Impor CBZ lewat pemilih berkas
- [ ] Settings: tema, penyimpanan, hapus cache, kebijakan privasi
- [ ] Hapus chapter atau komik
- [ ] Tutup aplikasi sepenuhnya lalu buka lagi: data tetap ada

## Kompatibilitas

- [ ] `minSdkVersion` pada manifest hasil build tidak lebih dari 26 (Android 8.0)
- Perangkat yang sudah diuji langsung: 22101316G (Android 14)

## Catatan hasil

(isi temuan di sini)
