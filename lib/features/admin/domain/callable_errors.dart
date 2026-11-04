/// Classification of admin callable failures that need a dedicated message
/// instead of the generic "forbidden" / "validation" text.
///
/// Pure Dart so the mapping can be unit-tested without Firebase.
library;

/// `details.reason` for banned accounts (decision D5). Mirrors
/// `BackendReasons.userBanned` in lib/core/backend/backend_contract.dart.
const String kUserBannedReason = 'USER_BANNED';

/// Whether the backend this CMS build talks to enforces App Check on the
/// admin* callables (`APP_CHECK_ENFORCE_ADMIN=true` on the functions; pass
/// the same `--dart-define=APP_CHECK_ENFORCE_ADMIN=true` to the CMS build).
///
/// The server default is `false` (functions/src/config.ts): admin callables
/// then accept requests without an App Check token, so the CMS must not warn
/// about App Check or blame it for an `unauthenticated` answer.
const bool kAdminAppCheckEnforced = bool.fromEnvironment('APP_CHECK_ENFORCE_ADMIN');

enum AdminCallableIssue {
  /// App Check cannot run on this platform (Windows/Linux, or web built
  /// without `APP_CHECK_WEB_SITE_KEY`) and the function enforces it.
  appCheckUnavailable,

  /// App Check is active here but the token was rejected (unregistered debug
  /// token, misconfigured provider).
  appCheckRejected,

  /// `unauthenticated` with no App Check hint: the ID token is missing or
  /// expired, or the account is no longer active — the admin has to sign in
  /// again.
  sessionExpired,

  /// The signed-in account is banned (D5).
  userBanned,
}

final RegExp _appCheckWord = RegExp(r'app[\s_-]?check', caseSensitive: false);

/// Whether an error [message] names App Check explicitly.
bool mentionsAppCheck(String? message) =>
    message != null && _appCheckWord.hasMatch(message);

/// Maps a `FirebaseFunctionsException` ([code], `details.reason` as
/// [reason], [message]) to a dedicated issue, or `null` for the regular
/// mapping.
///
/// admin* callables do not enforce App Check unless the backend sets
/// `APP_CHECK_ENFORCE_ADMIN` ([appCheckEnforced], default
/// [kAdminAppCheckEnforced]). So a bare `unauthenticated` normally comes from
/// `requireAuth` / an expired ID token and means "sign in again"
/// ([AdminCallableIssue.sessionExpired]). An App Check message is shown only
/// when the error names App Check explicitly, or when this build is known to
/// talk to a backend that enforces it.
AdminCallableIssue? classifyAdminCallableError({
  required String code,
  String? reason,
  String? message,
  required bool appCheckAvailable,
  bool appCheckEnforced = kAdminAppCheckEnforced,
}) {
  if (reason == kUserBannedReason) return AdminCallableIssue.userBanned;
  if (reason != null && reason.isNotEmpty) return null;
  final appCheckIssue = appCheckAvailable
      ? AdminCallableIssue.appCheckRejected
      : AdminCallableIssue.appCheckUnavailable;
  final explicitAppCheck = mentionsAppCheck(message);
  if (code == 'unauthenticated') {
    if (explicitAppCheck || appCheckEnforced) return appCheckIssue;
    return AdminCallableIssue.sessionExpired;
  }
  if (code == 'failed-precondition' &&
      (explicitAppCheck || (appCheckEnforced && !appCheckAvailable))) {
    return appCheckIssue;
  }
  return null;
}
