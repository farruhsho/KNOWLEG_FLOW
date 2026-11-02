import '../../../core/backend/backend_contract.dart';

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
}

class ExamFailure implements Exception {
  final ExamFailureKind kind;
  final String? message;

  const ExamFailure(this.kind, [this.message]);

  @override
  String toString() => 'ExamFailure($kind${message == null ? '' : ': $message'})';
}
