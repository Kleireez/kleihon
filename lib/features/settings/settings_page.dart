import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/app_info.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/format_bytes.dart';
import '../../shared/providers/history_providers.dart';
import '../../shared/providers/search_history_providers.dart';
import '../../shared/providers/storage_providers.dart';
import '../reader/reader_settings_sheet.dart';
import 'app_settings.dart';
import 'app_settings_labels.dart';
import 'app_settings_providers.dart';
import 'privacy_policy.dart';

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

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      final freed = await ref.read(storageServiceProvider).clearCache();
      ref.invalidate(storageUsageProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            freed > 0
                ? 'Cache dibersihkan (${formatBytes(freed)}).'
                : 'Cache sudah bersih.',
          ),
        ),
      );
    } catch (e, s) {
      appLogger.e('Gagal membersihkan cache', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal membersihkan cache.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final usage = ref.watch(storageUsageProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    String sizeText(int Function(StorageUsage usage) pick) => usage.when(
      data: (value) => formatBytes(pick(value)),
      loading: () => 'Menghitung...',
      error: (error, stack) => 'Tidak dapat dihitung',
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: theme.textTheme.headlineSmall),
            Text(
              'Preferensi Pembaca & Sistem',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _SectionHeader(
            icon: Icons.palette_outlined,
            title: 'Tampilan',
          ),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tema', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (var i = 0; i < AppThemeMode.values.length; i++) ...[
                          Expanded(
                            child: _ThemePreviewCard(
                              mode: AppThemeMode.values[i],
                              selected:
                                  settings.themeMode == AppThemeMode.values[i],
                              onTap: () => controller.update(
                                settings.copyWith(
                                  themeMode: AppThemeMode.values[i],
                                ),
                              ),
                            ),
                          ),
                          if (i < AppThemeMode.values.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Palet warna', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    _PaletteSelector(
                      selected: settings.palette,
                      onSelect: (palette) => controller.update(
                        settings.copyWith(palette: palette),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const _SectionHeader(
            icon: Icons.menu_book_outlined,
            title: 'Reader',
          ),
          const _SettingsCard(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: ReaderSettingsForm(),
              ),
            ],
          ),
          const _SectionHeader(
            icon: Icons.sd_storage_outlined,
            title: 'Penyimpanan',
          ),
          _SettingsCard(
            children: [
              ListTile(
                leading: Icon(Icons.folder_outlined, color: scheme.primary),
                title: const Text('Perpustakaan lokal'),
                subtitle: Text(
                  '${sizeText((value) => value.libraryBytes)}\n'
                  'Komik yang kamu impor. Hapus lewat halaman komik.',
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.cleaning_services_outlined,
                  color: scheme.primary,
                ),
                title: const Text('Cache'),
                subtitle: Text(sizeText((value) => value.cacheBytes)),
                trailing: TextButton(
                  onPressed: () => _clearCache(context, ref),
                  child: const Text('Hapus cache'),
                ),
              ),
            ],
          ),
          const _SectionHeader(
            icon: Icons.shield_outlined,
            title: 'Data pribadi',
          ),
          _SettingsCard(
            children: [
              ListTile(
                leading: Icon(Icons.history_rounded, color: scheme.secondary),
                title: const Text('Hapus riwayat baca'),
                subtitle: const Text(
                  'Riwayat dan progres baca. Library tidak terpengaruh.',
                ),
                onTap: () => _clearReadingHistory(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.search_off_rounded, color: scheme.secondary),
                title: const Text('Hapus riwayat pencarian'),
                onTap: () => _clearSearchHistory(context, ref),
              ),
            ],
          ),
          const _SectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'Tentang',
          ),
          _SettingsCard(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Versi aplikasi'),
                subtitle: Text('$appVersion ($appBuild)'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Kebijakan privasi'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyPage(),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Lisensi sumber terbuka'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: appName,
                  applicationVersion: appVersion,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  String get _subtitle => switch (mode) {
    AppThemeMode.dark => 'Mystic Noir',
    AppThemeMode.light => 'Washi Paper',
    AppThemeMode.system => 'Otomatis',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.14)
            : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? scheme.primary : AppTheme.hairlineOf(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _ThemeThumbnail(mode: mode),
                    if (selected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  mode.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
                Text(
                  _subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeThumbnail extends StatelessWidget {
  const _ThemeThumbnail({required this.mode});

  final AppThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final BoxDecoration decoration;
    final IconData icon;
    final Color iconColor;

    switch (mode) {
      case AppThemeMode.dark:
        decoration = BoxDecoration(
          color: const Color(0xFF111318),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hairline),
        );
        icon = Icons.dark_mode_outlined;
        iconColor = const Color(0xFFF4CA7E);
      case AppThemeMode.light:
        decoration = BoxDecoration(
          color: const Color(0xFFFBF9F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hairline),
        );
        icon = Icons.light_mode_outlined;
        iconColor = const Color(0xFF7D5705);
      case AppThemeMode.system:
        decoration = BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111318), Color(0xFFFBF9F5)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hairline),
        );
        icon = Icons.brightness_auto_outlined;
        iconColor = Colors.white;
    }

    return Container(
      height: 44,
      width: double.infinity,
      decoration: decoration,
      child: Center(child: Icon(icon, size: 18, color: iconColor)),
    );
  }
}

class _PaletteSelector extends StatelessWidget {
  const _PaletteSelector({required this.selected, required this.onSelect});

  final AppColorPalette selected;
  final ValueChanged<AppColorPalette> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hairline = AppTheme.hairlineOf(context);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.9,
      children: [
        for (final palette in AppColorPalette.values)
          Material(
            color: palette == selected
                ? scheme.primaryContainer.withValues(alpha: 0.14)
                : scheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: palette == selected ? scheme.primary : hairline,
                width: palette == selected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(palette),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: palette.previewColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: hairline),
                      ),
                      child: palette == selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Color(0xFF111318),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        palette.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: palette == selected
                              ? scheme.primary
                              : scheme.onSurface,
                          fontWeight: palette == selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.hairlineOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
