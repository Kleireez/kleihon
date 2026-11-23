import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Status baca', style: theme.textTheme.titleMedium),
            ),
            for (final status in ReadingStatus.values)
              ListTile(
                title: Text(status.label),
                trailing: status == bookmark.status
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => repository.setReadingStatus(
                  sourceId: comicKey.sourceId,
                  comicRemoteId: comicKey.comicId,
                  status: status,
                ),
              ),
            const Divider(),
            SwitchListTile(
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
          ],
        ),
      ),
    );
  }
}
