import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'reader_settings.dart';
import 'reader_settings_providers.dart';

/// Isi pengaturan reader tanpa pembungkus. Dipakai di lembar reader dan di
/// layar Settings.
class ReaderSettingsForm extends ConsumerWidget {
  const ReaderSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(readerSettingsProvider).value ?? ReaderSettings.defaults;
    final controller = ref.read(readerSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mode baca', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ReadingMode>(
            showSelectedIcon: false,
            segments: [
              for (final mode in ReadingMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {settings.readingMode},
            onSelectionChanged: (selection) => controller.apply(
              settings.copyWith(readingMode: selection.first),
            ),
          ),
        ),
        if (settings.readingMode.isHorizontal) ...[
          const SizedBox(height: 16),
          Text('Sesuaikan halaman', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PageFit>(
              showSelectedIcon: false,
              segments: [
                for (final fit in PageFit.values)
                  ButtonSegment(value: fit, label: Text(fit.label)),
              ],
              selected: {settings.pageFit},
              onSelectionChanged: (selection) =>
                  controller.apply(settings.copyWith(pageFit: selection.first)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Warna latar', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final background in ReaderBackground.values)
              _Swatch(
                background: background,
                selected: background == settings.background,
                onTap: () =>
                    controller.apply(settings.copyWith(background: background)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Layar tetap menyala'),
          subtitle: const Text('Layar tidak mati sendiri saat membaca.'),
          value: settings.keepScreenOn,
          onChanged: (value) =>
              controller.apply(settings.copyWith(keepScreenOn: value)),
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengaturan reader',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const ReaderSettingsForm(),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.background,
    required this.selected,
    required this.onTap,
  });

  final ReaderBackground background;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, color: background.foreground)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                background.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
