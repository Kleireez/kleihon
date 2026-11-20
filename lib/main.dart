import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';

void main() {
  runApp(
    ProviderScope(
      // Kegagalan langsung ditampilkan. Pengguna yang memutuskan mencoba lagi.
      retry: (retryCount, error) => null,
      child: const KleiHonApp(),
    ),
  );
}
