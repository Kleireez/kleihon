# Daftar periksa rilis

Jalankan pada build release sebelum menyatakan sebuah versi stabil.

Tanggal: 2026-11-27
Versi: 0.1.0+1
Perangkat: 22101316G

## Otomatis

- [x] `flutter analyze` bersih
- [x] `flutter test` lulus (`flutter test -j 2`)
- [x] `flutter test integration_test -d <id perangkat>` lulus (`+5: All tests passed!`)
- [x] `flutter build apk --release` berhasil (`build\app\outputs\flutter-apk\app-release.apk`)

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

- Integration test (`app_flow_test.dart` & `library_flow_test.dart`) lulus 5/5 pada `22101316G`.
- APK release (`0.1.0+1`) berhasil dibangun (`62.0 MB`).
