import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/library/library_page.dart';
import '../features/comic_detail/comic_detail_page.dart';
import '../features/comic_detail/cover_picker_page.dart';
import '../features/explore/explore_page.dart';
import '../features/home/home_page.dart';
import '../features/reader/reader_page.dart';
import '../shared/widgets/placeholder_page.dart';
import 'routes.dart';
import 'shell/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (c, s) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (c, s) => const ExplorePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (c, s) => const LibraryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
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
                path: AppRoutes.settings,
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
        path: AppRoutes.comicPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => ComicDetailPage(
          sourceId: s.pathParameters['sourceId']!,
          comicId: s.pathParameters['comicId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.coverPickerPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => CoverPickerPage(
          sourceId: s.pathParameters['sourceId']!,
          comicId: s.pathParameters['comicId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.readerPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => ReaderPage(
          sourceId: s.pathParameters['sourceId']!,
          comicId: s.pathParameters['comicId']!,
          chapterId: s.pathParameters['chapterId']!,
        ),
      ),
    ],
  );
});
