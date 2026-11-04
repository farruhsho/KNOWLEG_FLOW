import 'package:flutter/foundation.dart';

/// In-memory flag that is `true` only after the admin login has signed the
/// user in with Firebase Auth **and** resolved a valid admin role: the custom
/// claim `role` from `getIdTokenResult(true)` (super_admin, content_manager,
/// methodologist, moderator, support), falling back to the legacy
/// `/users/{uid}.role == 'admin'` (= super_admin). See ARCHITECTURE.md §2.
///
/// The go_router redirect reads this synchronously to gate every `/admin/*`
/// route. The resolved role itself lives in `adminSessionProvider` /
/// `adminRoleProvider` (lib/providers/admin_access_provider.dart), which keep
/// this flag in sync. It is intentionally NOT persisted: on a cold start (or
/// after sign-out) it resets to `false`, forcing admins back through the admin
/// login screen.
final ValueNotifier<bool> adminVerified = ValueNotifier<bool>(false);
