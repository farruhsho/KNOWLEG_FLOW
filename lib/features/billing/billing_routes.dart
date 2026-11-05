import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/route_paths.dart';
import 'domain/billing_mode.dart';
import 'presentation/billing_listener.dart';
import 'presentation/pages/pay_return_page.dart';
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
      // BILLING_MODE=web: the payment provider returns here (§10.3).
      GoRoute(
        path: RoutePaths.payReturn,
        builder: (context, state) =>
            PayReturnPage(orderId: state.uri.queryParameters['order']),
      ),
    ];

/// Wraps the app (via MaterialApp.builder) to listen for Google Play purchase
/// updates and re-verify unfinished purchases on start-up.
///
/// Must sit below `ProviderScope`. In `BILLING_MODE=external` and `web`
/// builds there is no Google Play to listen to and the child is returned
/// unchanged.
Widget wrapWithBillingListener(Widget child) {
  if (!BillingMode.current.usesPlayBilling) return child;
  return BillingListener(child: child);
}
