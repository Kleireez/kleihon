import 'package:material_ui/material_ui.dart';

class PolicySection {
  const PolicySection(this.title, this.body);

  final String title;
  final String body;
}

/// Isi kebijakan privasi. Perbarui jika perilaku aplikasi berubah (misalnya
/// saat sumber online ditambahkan).
const List<PolicySection> privacySections = [
  PolicySection(
    'Ringkasan',
    'KleiHon menyimpan semua datamu hanya di perangkat ini. Saat ini aplikasi '
        'tidak mengirim data pribadi atau data penggunaan ke server mana pun, '
        'tidak memiliki akun, dan tidak memakai iklan atau analitik.',
  ),
  PolicySection(
    'Data yang disimpan di perangkat',
    'Komik yang kamu impor, Library dan status baca, riwayat dan progres '
        'baca, riwayat pencarian, serta pengaturan aplikasi. Semuanya berada '
        'di penyimpanan privat aplikasi.',
  ),
  PolicySection(
    'Berkas yang kamu pilih',
    'KleiHon hanya membaca berkas yang kamu pilih sendiri lewat pemilih '
        'berkas. Isinya disalin ke penyimpanan aplikasi, dan berkas aslinya '
        'tidak diubah.',
  ),
  PolicySection(
    'Sumber online',
    'Jika sumber online ditambahkan di versi mendatang, KleiHon akan '
        'menghubungi situs sumber itu untuk mengambil katalog dan gambar. '
        'Situs tersebut dapat melihat alamat IP dan permintaan yang dibuat '
        'dari perangkatmu. KleiHon tidak mengirim data pribadi kepada mereka. '
        'Kebijakan ini akan diperbarui sebelum fitur tersebut tersedia.',
  ),
  PolicySection(
    'Menghapus datamu',
    'Riwayat baca dan riwayat pencarian dapat dihapus dari Settings. Komik '
        'dapat dihapus dari halaman komik. Menghapus data aplikasi lewat '
        'pengaturan Android menghapus semuanya.',
  ),
  PolicySection(
    'Perubahan',
    'Kebijakan ini dapat diperbarui mengikuti fitur baru. Versi terbaru '
        'selalu tersedia di dalam aplikasi.',
  ),
];

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kebijakan privasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Kebijakan Privasi KleiHon', style: theme.textTheme.titleLarge),
          for (final section in privacySections) ...[
            const SizedBox(height: 20),
            Text(section.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(section.body),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
