import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/local_import/local_import_page.dart';
import '../features/home/home_page.dart';
import '../shared/widgets/placeholder_page.dart';
import 'shell/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (c, s) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (c, s) => PlaceholderPage(
                  title: 'Explore',
                  note: 'Katalog komik (Phase 3).',
                  // Tombol uji sementara, dihapus setelah Phase 3.
                  actions: [
                    FilledButton(
                      onPressed: () => c.push('/comic/contoh-id'),
                      child: const Text('Uji: buka detail komik'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (c, s) => const PlaceholderPage(
                  title: 'Library',
                  note: 'Bookmark dan status baca (Phase 5).',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (c, s) => const PlaceholderPage(
                  title: 'History',
                  note: 'Riwayat membaca (Phase 5).',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (c, s) => const PlaceholderPage(
                  title: 'Settings',
                  note: 'Tema, reader, cache (Phase 1-7).',
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/import',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const LocalImportPage(),
      ),
      GoRoute(
        path: '/comic/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => PlaceholderPage(
          title: 'Detail komik',
          note: 'ID: ${s.pathParameters['id']}',
          actions: [
            FilledButton(
              onPressed: () => c.push('/reader/contoh-chapter'),
              child: const Text('Uji: buka reader'),
            ),
          ],
        ),
      ),
      GoRoute(
        path: '/reader/:chapterId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => PlaceholderPage(
          title: 'Reader',
          note: 'Chapter: ${s.pathParameters['chapterId']}',
        ),
      ),
    ],
  );
});
