import 'package:material_ui/material_ui.dart';

import '../../domain/entities/comic.dart';
import 'comic_cover.dart';

class ComicGridTile extends StatelessWidget {
  const ComicGridTile({super.key, required this.comic, required this.onTap});

  final Comic comic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ComicCover(url: comic.coverUrl)),
          const SizedBox(height: 6),
          Text(
            comic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
