import 'package:go_router/go_router.dart';

import '../../core/navigation/nav_helpers.dart';
import '../../core/routes/route_paths.dart';
import 'presentation/pages/group_detail_page.dart';
import 'presentation/pages/groups_page.dart';
import 'presentation/pages/invite_page.dart';

/// Integration point for the social & growth feature (ARCHITECTURE §9):
/// invite/referrals, groups and homework. Owned by lib/features/social;
/// spread into the router's top-level (root navigator) routes. Without
/// anything to pop (deep link), back goes to the profile.
List<RouteBase> get socialRoutes => [
      GoRoute(
        path: RoutePaths.invite,
        builder: (context, state) => const RootBackGuard(
          fallback: RoutePaths.profile,
          child: InvitePage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.groups,
        builder: (context, state) => const RootBackGuard(
          fallback: RoutePaths.profile,
          child: GroupsPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.groupDetail,
        builder: (context, state) => RootBackGuard(
          fallback: RoutePaths.groups,
          child: GroupDetailPage(groupId: state.pathParameters['groupId'] ?? ''),
        ),
      ),
    ];
