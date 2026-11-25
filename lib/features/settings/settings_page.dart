import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/app_logger.dart';
import '../../shared/providers/history_providers.dart';
import '../../shared/providers/search_history_providers.dart';
import '../reader/reader_settings_sheet.dart';
import 'app_settings.dart';
import 'app_settings_labels.dart';
import 'app_settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _clearReadingHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Hapus riwayat baca?',
      message:
          'Seluruh riwayat dan progres baca akan dihapus. Komik di Library '
          'dan statusnya tidak terpengaruh. Tindakan ini tidak bisa '
          'dibatalkan.',
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      await ref.read(historyRepositoryProvider).clearAll();
      messenger.showSnackBar(
        const SnackBar(content: Text('Riwayat baca dihapus.')),
      );
    } catch (e, s) {
      appLogger.e('Gagal menghapus riwayat baca', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus riwayat baca.')),
      );
    }
  }

  Future<void> _clearSearchHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Hapus riwayat pencarian?',
      message: 'Semua kata kunci pencarian yang tersimpan akan dihapus.',
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      await ref.read(searchHistoryRepositoryProvider).clearAll();
      messenger.showSnackBar(
        const SnackBar(content: Text('Riwayat pencarian dihapus.')),
      );
    } catch (e, s) {
      appLogger.e('Gagal menghapus riwayat pencarian', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus riwayat pencarian.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _SectionHeader('Tampilan'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tema', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      for (final mode in AppThemeMode.values)
                        ButtonSegment(value: mode, label: Text(mode.label)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) => controller.update(
                      settings.copyWith(themeMode: selection.first),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _SectionHeader('Reader'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ReaderSettingsForm(),
          ),
          const _SectionHeader('Data pribadi'),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Hapus riwayat baca'),
            subtitle: const Text(
              'Riwayat dan progres baca. Library tidak terpengaruh.',
            ),
            onTap: () => _clearReadingHistory(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.search_off),
            title: const Text('Hapus riwayat pencarian'),
            onTap: () => _clearSearchHistory(context, ref),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
