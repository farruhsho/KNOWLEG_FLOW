import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/backend/backend_contract.dart';

/// Why a growth/social action failed. Mapped from the backend's
/// `details.reason` (ARCHITECTURE §9) and, when there is none, from the
/// Firebase error code.
enum SocialFailureKind {
  codeInvalid,
  codeExpired,
  codeExhausted,
  alreadyRedeemed,
  rateLimited,
  referralNotAllowed,
  limitReached,
  notGroupOwner,

  /// The student typed their own referral code (checked on the client too).
  ownCode,
  banned,
  notSignedIn,
  permissionDenied,
  notFound,
  offline,

  /// No App Check on this platform: callables are unavailable (D7).
  unsupportedPlatform,
  validation,
  unknown,
}

/// Typed failure thrown by the social repository.
class SocialFailure implements Exception {
  final SocialFailureKind kind;
  final Object? cause;

  const SocialFailure(this.kind, [this.cause]);

  /// [kind] for a backend `details.reason`, or null for an unknown reason.
  static SocialFailureKind? kindForReason(String? reason) => switch (reason) {
        BackendReasons.codeInvalid => SocialFailureKind.codeInvalid,
        BackendReasons.codeExpired => SocialFailureKind.codeExpired,
        BackendReasons.codeExhausted => SocialFailureKind.codeExhausted,
        BackendReasons.alreadyRedeemed => SocialFailureKind.alreadyRedeemed,
        BackendReasons.rateLimited => SocialFailureKind.rateLimited,
        BackendReasons.referralNotAllowed => SocialFailureKind.referralNotAllowed,
        BackendReasons.limitReached => SocialFailureKind.limitReached,
        BackendReasons.notGroupOwner => SocialFailureKind.notGroupOwner,
        BackendReasons.userBanned => SocialFailureKind.banned,
        BackendReasons.validationFailed => SocialFailureKind.validation,
        BackendReasons.forbiddenRole => SocialFailureKind.permissionDenied,
        _ => null,
      };

  /// [kind] for a Firebase error code (callable or Firestore).
  static SocialFailureKind kindForCode(String code) => switch (code) {
        'unavailable' || 'deadline-exceeded' => SocialFailureKind.offline,
        'unauthenticated' => SocialFailureKind.notSignedIn,
        'permission-denied' => SocialFailureKind.permissionDenied,
        'resource-exhausted' => SocialFailureKind.rateLimited,
        'already-exists' => SocialFailureKind.alreadyRedeemed,
        'not-found' => SocialFailureKind.notFound,
        'invalid-argument' => SocialFailureKind.validation,
        _ => SocialFailureKind.unknown,
      };

  factory SocialFailure.from(Object error) {
    if (error is SocialFailure) return error;
    if (error is FirebaseFunctionsException) {
      final kind = kindForReason(BackendReasons.of(error)) ?? kindForCode(error.code);
      return SocialFailure(kind, error);
    }
    if (error is FirebaseException) {
      return SocialFailure(kindForCode(error.code), error);
    }
    return SocialFailure(SocialFailureKind.unknown, error);
  }

  @override
  String toString() => 'SocialFailure($kind, $cause)';
}
