import 'package:material_ui/material_ui.dart';

import '../../domain/entities/comic.dart';
import 'comic_cover.dart';

class ComicGridTile extends StatelessWidget {
  const ComicGridTile({super.key, required this.comic, required this.onTap});

  final Comic comic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ComicCover(url: comic.coverUrl, borderRadius: 10)),
          const SizedBox(height: 8),
          Text(
            comic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge?.copyWith(
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
