import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/local_providers.dart';
import 'source_registry.dart';

/// Sumber yang terdaftar. Sumber online ditambahkan di sini setelah
/// aksesnya terbukti sah dan terjangkau (lihat docs/decisions.md).
final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  return SourceRegistry([ref.watch(localComicSourceProvider)]);
});
