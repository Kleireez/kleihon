import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/app_logger.dart';
import '../../data/local/local_providers.dart';
import '../../domain/entities/chapter.dart';
import '../../shared/providers/chapter_pages_provider.dart';
import '../../shared/providers/library_revision_provider.dart';
import '../../shared/widgets/comic_cover.dart';
import 'comic_detail_providers.dart';

class CoverPickerPage extends ConsumerStatefulWidget {
  const CoverPickerPage({
    super.key,
    required this.sourceId,
    required this.comicId,
  });

  final String sourceId;
  final String comicId;

  @override
  ConsumerState<CoverPickerPage> createState() => _CoverPickerPageState();
}

class _CoverPickerPageState extends ConsumerState<CoverPickerPage> {
  static const int _pageLimit = 12;

  String? _chapterId;

  ComicKey get _key => (sourceId: widget.sourceId, comicId: widget.comicId);

  Future<void> _choose(String chapterId, ChapterPage page) async {
    final messenger = ScaffoldMessenger.of(context);
    final revision = ref.read(libraryRevisionProvider.notifier);
    final library = ref.read(localLibraryProvider);
    final fileName = Uri.parse(page.imageUrl).pathSegments.last;

    try {
      await library.setCover(
        comicRemoteId: widget.comicId,
        chapterRemoteId: chapterId,
        pageFileName: fileName,
      );
    } catch (e, s) {
      appLogger.e('Gagal mengganti sampul', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mengganti sampul.')),
      );
      return;
    }

    revision.bump();
    messenger.showSnackBar(const SnackBar(content: Text('Sampul diperbarui.')));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(comicDetailProvider(_key));

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih sampul')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Gagal memuat komik.')),
        data: (data) {
          if (data.chapters.isEmpty) {
            return const Center(child: Text('Belum ada chapter.'));
          }
          final chapterId = _chapterId ?? data.chapters.first.remoteId;
          final pages = ref.watch(
            chapterPagesProvider((
              sourceId: widget.sourceId,
              chapterId: chapterId,
            )),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: chapterId,
                  items: [
                    for (final chapter in data.chapters)
                      DropdownMenuItem(
                        value: chapter.remoteId,
                        child: Text(
                          chapter.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _chapterId = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Ketuk halaman untuk dijadikan sampul '
                  '($_pageLimit halaman pertama).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: pages.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      const Center(child: Text('Gagal memuat halaman.')),
                  data: (list) {
                    final shown = list.take(_pageLimit).toList();
                    if (shown.isEmpty) {
                      return const Center(child: Text('Chapter ini kosong.'));
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.66,
                          ),
                      itemCount: shown.length,
                      itemBuilder: (context, index) => InkWell(
                        onTap: () => _choose(chapterId, shown[index]),
                        child: ComicCover(url: shown[index].imageUrl),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
