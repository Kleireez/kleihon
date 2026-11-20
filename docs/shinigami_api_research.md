# Riset API Shinigami

Tanggal: 20 November 2026
Sumber yang diperiksa: https://s1.shinigami.mx/
Status: **TERBLOKIR. Belum ada akses yang terbukti sah. Tidak dipakai.**

## Yang terverifikasi

- Domain front-end: `https://s1.shinigami.mx/`. Domain situs ini berpindah-pindah
  (HakuNeko issue #8540 menyebut `g.shinigami.asia` dan domain `a`-`d`).
- `robots.txt` (ditempel developer): `User-agent: *` memakai `Allow: /`,
  `Content-Signal: search=yes, ai-train=no, use=reference`. Daftar panjang bot
  yang ditutup berasal dari fitur robots.txt terkelola Cloudflare. robots.txt
  bukan izin pemakaian dan tidak membahas aplikasi pihak ketiga.
- Halaman utama adalah single-page app: HTML hanya berisi `<div id="root">`
  dan satu bundel JavaScript. Data komik tidak ada di HTML awal.
- Ada tag `<meta name="sg-strata" content="on">`. Fungsinya tidak diketahui.

## Yang tidak ditemukan

- API publik atau dokumentasi resmi.
- Halaman Terms, kebijakan pemakaian, atau kontak pemilik.
- Base URL, endpoint, parameter, format response, autentikasi, pagination.

## Proyek pihak ketiga (tidak resmi, tidak dipakai)

- Sansekai/Unofficial-Shinigami-Api: layanan di api.sansekai.my.id.
  Uji `GET /api/komik/get-latest?type=project` (lewat Swagger) menghasilkan
  `403 Forbidden`. Dokumentasi hanya mencantumkan respons 200. Penyebab
  tidak diketahui. Tidak ada upaya mengakali.
- VernSG/Shinigami-Api: scraper Express.js yang harus di-hosting sendiri.
  Tidak diuji, karena akan mengambil data langsung dari situs tanpa izin.
- KotatsuApp/kotatsu-parsers (GPL-3.0, diarsipkan pemiliknya 4 November 2025):
  pengaturan sumber Shinigami di aplikasi Kotatsu memuat opsi CAPTCHA,
  perlambat unduhan untuk menghindari pemblokiran IP, dan penggantian domain
  manual. Itu pola penghalang akses yang dilarang diakali oleh PRD. Kode GPL
  tidak boleh disalin ke KleiHon.

## Keputusan

Integrasi `ShinigamiComicSource` tidak dibangun. Alasan: tidak ada izin atau
API resmi, layanan pihak ketiga menolak akses, dan jalur lain mensyaratkan
pengakalan proteksi akses (PRD 3.3). Lihat docs/decisions.md.

Langkah yang mungkin di masa depan:
1. Minta izin atau dokumentasi API kepada pemilik situs.
2. Gunakan sumber lain yang punya API terdokumentasi dan dapat dijangkau.
