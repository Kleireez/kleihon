import 'comic_source.dart';

class SourceRegistry {
  SourceRegistry([Iterable<ComicSource> sources = const []]) {
    sources.forEach(register);
  }

  final Map<String, ComicSource> _sources = {};

  void register(ComicSource source) {
    if (_sources.containsKey(source.id)) {
      throw ArgumentError('Sumber "${source.id}" sudah terdaftar');
    }
    _sources[source.id] = source;
  }

  ComicSource? byId(String id) => _sources[id];

  ComicSource require(String id) {
    final source = _sources[id];
    if (source == null) {
      throw StateError('Sumber "$id" tidak terdaftar');
    }
    return source;
  }

  List<ComicSource> get all => List.unmodifiable(_sources.values);
}
