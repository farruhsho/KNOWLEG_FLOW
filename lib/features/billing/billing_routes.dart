import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/route_paths.dart';
import 'domain/billing_mode.dart';
import 'presentation/billing_listener.dart';
import 'presentation/pages/store_page.dart';
import 'presentation/pages/transactions_page.dart';

/// Integration point for billing (owned by lib/features/billing).
List<RouteBase> get billingRoutes => [
      GoRoute(
        path: RoutePaths.store,
        builder: (context, state) => const StorePage(),
      ),
      GoRoute(
        path: RoutePaths.transactions,
        builder: (context, state) => const TransactionsPage(),
      ),
    ];

/// Wraps the app (via MaterialApp.builder) to listen for Google Play purchase
/// updates and re-verify unfinished purchases on start-up.
///
/// Must sit below `ProviderScope`. In `BILLING_MODE=external` builds there is
/// nothing to listen to and the child is returned unchanged.
Widget wrapWithBillingListener(Widget child) {
  if (!BillingMode.current.sellsInApp) return child;
  return BillingListener(child: child);
}
