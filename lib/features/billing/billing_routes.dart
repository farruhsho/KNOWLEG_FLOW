import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Integration point for billing (owned by lib/features/billing).
List<RouteBase> get billingRoutes => const [];

/// Wraps the app (via MaterialApp.builder) to listen for Google Play purchase
/// updates and re-verify unfinished purchases on start-up.
Widget wrapWithBillingListener(Widget child) => child;
