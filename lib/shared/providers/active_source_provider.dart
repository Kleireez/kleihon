import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_library_layout.dart';

/// Sumber yang sedang dipakai layar katalog. Saat ini hanya ada sumber
/// lokal. Nanti dapat dipilih dari Settings.
final activeSourceIdProvider = Provider<String>((ref) => localSourceId);
