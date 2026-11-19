import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'source_registry.dart';

/// Sengaja kosong. ShinigamiComicSource didaftarkan di Phase 2
/// setelah API discovery selesai dan akses terbukti sah.
final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  return SourceRegistry();
});