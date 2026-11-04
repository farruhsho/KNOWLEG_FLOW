import 'package:go_router/go_router.dart';

import '../../core/routes/route_paths.dart';
import 'presentation/pages/leaderboard_page.dart';
import 'presentation/pages/mistakes_page.dart';

/// Path of the "Ошибки и повторение" screen. Defined here because
/// route_paths.dart belongs to the shell package; move it to
/// `RoutePaths.mistakes` when convenient (listed as a cross-edit request).
const String kMistakesPath = '/mistakes';

/// Integration point for gamification pages that are not tab roots
/// (leaderboard, mistakes review). Owned by lib/features/gamification.
List<RouteBase> get gamificationRoutes => [
      GoRoute(
        path: RoutePaths.leaderboard,
        builder: (context, state) => const LeaderboardPage(),
      ),
      GoRoute(
        path: kMistakesPath,
        builder: (context, state) => const MistakesPage(),
      ),
    ];
