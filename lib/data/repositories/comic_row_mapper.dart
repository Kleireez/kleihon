import 'dart:convert';

import '../../domain/entities/comic.dart';
import '../database/app_database.dart' as db;

/// Mengubah alamat sampul yang tersimpan menjadi alamat yang bisa dimuat
/// (misalnya path relatif sumber lokal menjadi URI file://).
typedef CoverResolver = Future<String?> Function(
  String sourceId,
  String? stored,
);

List<String> decodeStringList(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) return decoded.whereType<String>().toList();
  } catch (_) {
    // Data rusak diperlakukan sebagai daftar kosong.
  }
  return const [];
}

Future<Comic> comicFromRow(db.Comic row, CoverResolver resolveCover) async {
  return Comic(
    sourceId: row.sourceId,
    remoteId: row.remoteId,
    title: row.title,
    sourceUrl: row.sourceUrl,
    alternativeTitles: decodeStringList(row.alternativeTitlesJson),
    coverUrl: await resolveCover(row.sourceId, row.coverUrl),
    synopsis: row.synopsis,
    author: row.author,
    artist: row.artist,
    status: row.status,
    type: row.type,
    genres: decodeStringList(row.genresJson),
    rating: row.rating,
    updatedAt: row.updatedAt,
  );
}
