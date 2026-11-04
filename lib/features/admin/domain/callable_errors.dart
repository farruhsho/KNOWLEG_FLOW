/// Classification of admin callable failures that need a dedicated message
/// instead of the generic "forbidden" / "validation" text.
///
/// Pure Dart so the mapping can be unit-tested without Firebase.
library;

/// `details.reason` for banned accounts (decision D5). Mirrors
/// `BackendReasons.userBanned` in lib/core/backend/backend_contract.dart.
const String kUserBannedReason = 'USER_BANNED';

enum AdminCallableIssue {
  /// App Check cannot run on this platform (Windows/Linux, or web built
  /// without `APP_CHECK_WEB_SITE_KEY`) and the function enforces it.
  appCheckUnavailable,

  /// App Check is active here but the token was rejected (unregistered debug
  /// token, misconfigured provider).
  appCheckRejected,

  /// The signed-in account is banned (D5).
  userBanned,
}

/// Maps a `FirebaseFunctionsException` ([code], `details.reason` as
/// [reason]) to a dedicated issue, or `null` for the regular mapping.
///
/// Callables answer `unauthenticated` without a reason when the App Check
/// token is missing or invalid; an admin inside the CMS is always signed in,
/// so that combination means App Check (SEC-APPCHECK-01). A bare
/// `failed-precondition` is treated the same way only where App Check is not
/// available — every domain `failed-precondition` carries a reason.
AdminCallableIssue? classifyAdminCallableError({
  required String code,
  String? reason,
  required bool appCheckAvailable,
}) {
  if (reason == kUserBannedReason) return AdminCallableIssue.userBanned;
  if (reason != null && reason.isNotEmpty) return null;
  if (code == 'unauthenticated') {
    return appCheckAvailable
        ? AdminCallableIssue.appCheckRejected
        : AdminCallableIssue.appCheckUnavailable;
  }
  if (code == 'failed-precondition' && !appCheckAvailable) {
    return AdminCallableIssue.appCheckUnavailable;
  }
  return null;
}
