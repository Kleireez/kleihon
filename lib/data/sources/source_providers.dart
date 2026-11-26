import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/local_providers.dart';
import 'mangadex_source.dart';
import 'source_registry.dart';

final mangaDexSourceProvider = Provider<MangaDexSource>(
  (ref) => MangaDexSource(),
);

/// Sumber yang terdaftar (lokal dan sumber online resmi yang dapat diakses).
final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  return SourceRegistry([
    ref.watch(localComicSourceProvider),
    ref.watch(mangaDexSourceProvider),
  ]);
});
