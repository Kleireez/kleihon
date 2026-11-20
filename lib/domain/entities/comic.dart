import 'entity_id.dart';

class Comic {
  const Comic({
    required this.sourceId,
    required this.remoteId,
    required this.title,
    required this.sourceUrl,
    this.alternativeTitles = const [],
    this.coverUrl,
    this.synopsis,
    this.author,
    this.artist,
    this.status,
    this.type,
    this.genres = const [],
    this.rating,
    this.updatedAt,
  });

  final String sourceId;
  final String remoteId;
  final String title;

  /// URL asli di sumber.
  final String sourceUrl;
  final List<String> alternativeTitles;
  final String? coverUrl;
  final String? synopsis;
  final String? author;
  final String? artist;
  final String? status;

  /// Manga, manhwa, manhua, atau lainnya.
  final String? type;
  final List<String> genres;
  final double? rating;
  final DateTime? updatedAt;

  String get id => makeEntityId(sourceId, remoteId);
}

class Genre {
  const Genre({required this.id, required this.name});

  final String id;
  final String name;
}
