import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../routes/route_paths.dart';

/// Pops when there is somewhere to go back to, otherwise goes home — a deep
/// link or refreshed page never dead-ends (NAV-01).
void popOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(RoutePaths.home);
  }
}

/// `GoRouterState.extra` of the enclosing route, or null outside a GoRouter
/// (widget tests) — lets pages read optional launch data without changing
/// their public constructors.
Object? routeExtraOf(BuildContext context) {
  try {
    return GoRouterState.of(context).extra;
  } catch (_) {
    return null;
  }
}
