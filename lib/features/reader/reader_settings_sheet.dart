import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';
import 'reader_settings.dart';
import 'reader_settings_providers.dart';

/// Isi pengaturan reader tanpa pembungkus. Dipakai di lembar reader dan di
/// layar Settings.
class ReaderSettingsForm extends ConsumerWidget {
  const ReaderSettingsForm({super.key});

  String _modeDescription(ReadingMode mode) {
    switch (mode) {
      case ReadingMode.vertical:
        return 'Gulir vertikal kontinu';
      case ReadingMode.horizontalLtr:
        return 'Geser kiri ke kanan';
      case ReadingMode.horizontalRtl:
        return 'Geser kanan ke kiri';
    }
  }

  IconData _modeIcon(ReadingMode mode) {
    switch (mode) {
      case ReadingMode.vertical:
        return Icons.swap_vert_rounded;
      case ReadingMode.horizontalLtr:
        return Icons.arrow_forward_rounded;
      case ReadingMode.horizontalRtl:
        return Icons.arrow_back_rounded;
    }
  }

  IconData _fitIcon(PageFit fit) {
    switch (fit) {
      case PageFit.width:
        return Icons.fit_screen_outlined;
      case PageFit.height:
        return Icons.height_rounded;
    }
  }

  String _bgDescription(ReaderBackground bg) {
    switch (bg) {
      case ReaderBackground.black:
        return 'Hitam Pekat';
      case ReaderBackground.dark:
        return 'Gelap';
      case ReaderBackground.sepia:
        return 'Sepia Hangat';
      case ReaderBackground.white:
        return 'Putih Kertas';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(readerSettingsProvider).value ?? ReaderSettings.defaults;
    final controller = ref.read(readerSettingsProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hairline = AppTheme.hairlineOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Mode baca',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              _modeDescription(settings.readingMode),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: hairline),
          ),
          child: Row(
            children: [
              for (final mode in ReadingMode.values)
                Expanded(
                  child: _SegmentPill(
                    icon: _modeIcon(mode),
                    label: mode.label,
                    selected: mode == settings.readingMode,
                    onTap: () => controller.apply(
                      settings.copyWith(readingMode: mode),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (settings.readingMode.isHorizontal) ...[
          const SizedBox(height: 18),
          Text(
            'Sesuaikan halaman',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hairline),
            ),
            child: Row(
              children: [
                for (final fit in PageFit.values)
                  Expanded(
                    child: _SegmentPill(
                      icon: _fitIcon(fit),
                      label: fit.label,
                      selected: fit == settings.pageFit,
                      onTap: () => controller.apply(
                        settings.copyWith(pageFit: fit),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Warna latar',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              _bgDescription(settings.background),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < ReaderBackground.values.length; i++) ...[
              Expanded(
                child: _SwatchCard(
                  background: ReaderBackground.values[i],
                  selected: ReaderBackground.values[i] == settings.background,
                  onTap: () => controller.apply(
                    settings.copyWith(background: ReaderBackground.values[i]),
                  ),
                ),
              ),
              if (i < ReaderBackground.values.length - 1)
                const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Material(
          color: scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            secondary: Icon(
              Icons.wb_sunny_outlined,
              color: scheme.primary,
            ),
            title: const Text('Layar tetap menyala'),
            subtitle: const Text('Layar tidak mati sendiri saat membaca.'),
            value: settings.keepScreenOn,
            onChanged: (value) =>
                controller.apply(settings.copyWith(keepScreenOn: value)),
          ),
        ),
      ],
    );
  }
}

/// Lembar pengaturan reader, dibuka dari bilah atas reader.
class ReaderSettingsSheet extends StatelessWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pengaturan reader',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHigh,
                    minimumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ReaderSettingsForm(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Terapkan & Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwatchCard extends StatelessWidget {
  const _SwatchCard({
    required this.background,
    required this.selected,
    required this.onTap,
  });

  final ReaderBackground background;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.12)
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: background.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check, size: 18, color: background.foreground)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  background.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
