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

  /// Exam callables need App Check, which has no provider on this platform
  /// (Windows / Linux desktop builds, contract D7). Not retryable.
  platformUnsupported,

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

  const ExamFailure(this.kind, [this.message]);

  @override
  String toString() => 'ExamFailure($kind${message == null ? '' : ': $message'})';
}
