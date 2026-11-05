import '../../../core/backend/backend_contract.dart';

/// `details.reason` of a banned account (contract D5). Mirrors
/// `BackendReasons.userBanned`; kept here as a literal so this feature does
/// not depend on when that constant lands.
const String examReasonUserBanned = 'USER_BANNED';

/// Typed failure of an exam backend call, mapped from
/// `HttpsError.details.reason` ([BackendReasons]) or the transport error.
enum ExamFailureKind {
  noEntitlement,
  variantNotAvailable,
  attemptNotFound,
  attemptNotInProgress,
  wrongSection,
  validationFailed,
  unauthenticated,

  /// The account is banned by a moderator (`USER_BANNED`). Not retryable.
  userBanned,

  /// Exam callables need App Check, which this build cannot obtain
  /// (Windows / Linux desktop builds, web built without
  /// `APP_CHECK_WEB_SITE_KEY`; contract D7). Not retryable.
  platformUnsupported,

  /// `examStart` mode `fresh`: the verified bank does not cover this
  /// direction / language yet (`POOL_TOO_SMALL`). No credit was charged.
  poolTooSmall,

  /// A strict («Как на ОРТ») section was sent before its deadline
  /// (`SECTION_NOT_OVER`): wait a moment and send again.
  sectionNotOver,

  /// No connection / timeout / backend unavailable — safe to retry.
  network,
  unknown;

  static ExamFailureKind fromReason(String? reason) => switch (reason) {
        BackendReasons.noEntitlement => ExamFailureKind.noEntitlement,
        BackendReasons.variantNotAvailable => ExamFailureKind.variantNotAvailable,
        BackendReasons.attemptNotFound => ExamFailureKind.attemptNotFound,
        BackendReasons.attemptNotInProgress =>
          ExamFailureKind.attemptNotInProgress,
        BackendReasons.wrongSection => ExamFailureKind.wrongSection,
        BackendReasons.validationFailed => ExamFailureKind.validationFailed,
        examReasonUserBanned => ExamFailureKind.userBanned,
        BackendReasons.poolTooSmall => ExamFailureKind.poolTooSmall,
        BackendReasons.sectionNotOver => ExamFailureKind.sectionNotOver,
        _ => ExamFailureKind.unknown,
      };

  /// Maps a callable/Firestore error code (`unavailable`, `deadline-exceeded`
  /// …) when there is no backend reason.
  static ExamFailureKind fromCode(String? code) => switch (code) {
        'unavailable' ||
        'deadline-exceeded' ||
        'network-request-failed' ||
        'cancelled' =>
          ExamFailureKind.network,
        'unauthenticated' => ExamFailureKind.unauthenticated,
        'not-found' => ExamFailureKind.attemptNotFound,
        _ => ExamFailureKind.unknown,
      };

  bool get isRetryable => this == network || this == unknown;

  /// The user cannot fix this by trying again (a retry button would only
  /// repeat the same answer).
  bool get isTerminal => this == userBanned || this == platformUnsupported;
}

class ExamFailure implements Exception {
  final ExamFailureKind kind;
  final String? message;

  /// `HttpsError.details` (e.g. `{section_id, part_id}` of POOL_TOO_SMALL).
  final Map<String, Object?> details;

  const ExamFailure(this.kind, [this.message, this.details = const {}]);

  @override
  String toString() => 'ExamFailure($kind${message == null ? '' : ': $message'})';
}
