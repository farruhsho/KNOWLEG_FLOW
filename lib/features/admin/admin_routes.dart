import 'package:go_router/go_router.dart';

/// Integration point for the admin CMS (owned by lib/features/admin). Every
/// path here must start with /admin so the router's admin gate applies.
List<RouteBase> get adminRoutes => const [];
