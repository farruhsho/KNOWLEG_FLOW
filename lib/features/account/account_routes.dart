import 'package:go_router/go_router.dart';

import '../../core/routes/route_paths.dart';
import 'presentation/pages/account_delete_page.dart';

/// Integration point for account management, incl. in-app account deletion
/// required by Google Play (owned by lib/features/account).
List<RouteBase> get accountRoutes => [
      GoRoute(
        path: RoutePaths.accountDelete,
        builder: (context, state) => const AccountDeletePage(),
      ),
    ];
