import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_library_layout.dart';
import '../../data/sources/source_providers.dart';
import '../../features/settings/app_settings_providers.dart';

/// Sumber yang sedang dipakai layar katalog (tersimpan di pengaturan aplikasi).
final activeSourceIdProvider = Provider<String>((ref) {
  final preferred = ref.watch(
    appSettingsProvider.select((s) => s.activeSourceId),
  );
  final registry = ref.watch(sourceRegistryProvider);
  if (registry.byId(preferred) != null) return preferred;
  if (registry.byId(localSourceId) != null) return localSourceId;
  return registry.all.isNotEmpty ? registry.all.first.id : preferred;
});
