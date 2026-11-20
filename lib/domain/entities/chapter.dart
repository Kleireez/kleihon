import 'entity_id.dart';

class Chapter {
  const Chapter({
    required this.sourceId,
    required this.comicRemoteId,
    required this.remoteId,
    required this.title,
    required this.chapterUrl,
    this.chapterNumber,
    this.publishedAt,
  });

  final String sourceId;
  final String comicRemoteId;
  final String remoteId;
  final String title;
  final String chapterUrl;
  final double? chapterNumber;
  final DateTime? publishedAt;

  String get id => makeEntityId(sourceId, remoteId);
  String get comicId => makeEntityId(sourceId, comicRemoteId);
}

class ChapterPage {
  const ChapterPage({required this.index, required this.imageUrl});

  final int index;
  final String imageUrl;
}
