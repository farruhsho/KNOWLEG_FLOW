import 'package:flutter/foundation.dart';

/// In-memory flag that is `true` only after [AdminLoginPage] has signed the user
/// in with Firebase Auth **and** verified that their `/users/{uid}.role` is
/// `'admin'` (the same field `firestore.rules` `isAdmin()` trusts).
///
/// The go_router redirect reads this synchronously to gate every `/admin/*`
/// route. It is intentionally NOT persisted: on a cold start (or after sign-out)
/// it resets to `false`, forcing admins to re-authenticate through the admin
/// login screen. This is the "role in router, no backend" gate; the long-term
/// target is Firebase Auth custom claims (see CTO_AUDIT_REPORT.md §11.3).
final ValueNotifier<bool> adminVerified = ValueNotifier<bool>(false);
