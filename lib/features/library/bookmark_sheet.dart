import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/entities/reading_status.dart';
import '../../shared/providers/bookmark_providers.dart';
import '../comic_detail/comic_detail_providers.dart';
import 'library_labels.dart';
import 'library_providers.dart';

/// Lembar untuk mengubah status baca dan pengaturan ikuti update.
class BookmarkSheet extends ConsumerWidget {
  const BookmarkSheet({super.key, required this.comicKey});

  final ComicKey comicKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmark = ref.watch(bookmarkProvider(comicKey)).value;
    final repository = ref.read(bookmarkRepositoryProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (bookmark == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Komik ini tidak ada di Library.'),
        ),
      );
    }

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
            Text('Status baca', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Material(
              color: scheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppTheme.hairlineOf(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < ReadingStatus.values.length; i++) ...[
                    ListTile(
                      title: Text(
                        ReadingStatus.values[i].label,
                        style: ReadingStatus.values[i] == bookmark.status
                            ? TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              )
                            : null,
                      ),
                      trailing: ReadingStatus.values[i] == bookmark.status
                          ? Icon(Icons.check_rounded, color: scheme.primary)
                          : null,
                      onTap: () => repository.setReadingStatus(
                        sourceId: comicKey.sourceId,
                        comicRemoteId: comicKey.comicId,
                        status: ReadingStatus.values[i],
                      ),
                    ),
                    if (i < ReadingStatus.values.length - 1)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: scheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppTheme.hairlineOf(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                title: const Text('Ikuti update'),
                subtitle: const Text(
                  'Tersimpan di Library. Pemeriksaan update tersedia untuk '
                  'sumber online.',
                ),
                value: bookmark.followUpdates,
                onChanged: (value) => repository.setFollowUpdates(
                  sourceId: comicKey.sourceId,
                  comicRemoteId: comicKey.comicId,
                  follow: value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
