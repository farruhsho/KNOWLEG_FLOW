import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/backend/backend_contract.dart';

/// Why a growth/social action failed. Mapped from the backend's
/// `details.why` / `details.what` (ARCHITECTURE §9.7), then `details.reason`
/// (§9) and, when there is none, from the Firebase error code.
enum SocialFailureKind {
  codeInvalid,
  codeExpired,
  codeExhausted,
  alreadyRedeemed,
  rateLimited,
  referralNotAllowed,
  limitReached,

  /// LIMIT_REACHED with `what: 'group_members'`: the group already has the
  /// maximum number of members (500).
  groupFull,
  notGroupOwner,

  /// The student typed their own referral code (checked on the client too;
  /// the server says `why: 'self'` / `'own_code'`).
  ownCode,

  /// `why: 'owner_has_members'`: the owner cannot leave a group with members.
  ownerHasMembers,

  /// `why: 'removed_from_group'`: the owner removed the student from this
  /// group, so joining it again is refused.
  removedFromGroup,

  /// `why: 'profile_missing'`: `users/{uid}` is not created yet (right after
  /// sign-up); retrying a moment later helps.
  profileMissing,
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

  /// [kind] for a backend `details.why` (ARCHITECTURE §9.7), or null when
  /// [why] adds nothing to the reason (e.g. `has_exams`, `has_purchases`).
  static SocialFailureKind? kindForWhy(String? why) => switch (why) {
        'self' || 'own_code' => SocialFailureKind.ownCode,
        'already_referred' => SocialFailureKind.alreadyRedeemed,
        'owner_has_members' => SocialFailureKind.ownerHasMembers,
        'removed_from_group' => SocialFailureKind.removedFromGroup,
        'profile_missing' => SocialFailureKind.profileMissing,
        _ => null,
      };

  /// LIMIT_REACHED narrowed by `details.what`; null keeps
  /// [SocialFailureKind.limitReached] (`friends`, `memberships`,
  /// `owned_groups`: the action names the limit).
  static SocialFailureKind? kindForLimit(String? what) => switch (what) {
        'group_members' => SocialFailureKind.groupFull,
        _ => null,
      };

  /// String `details[key]` of a callable error, if present.
  static String? _detail(FirebaseFunctionsException error, String key) {
    final d = error.details;
    if (d is Map && d[key] is String) return d[key] as String;
    return null;
  }

  factory SocialFailure.from(Object error) {
    if (error is SocialFailure) return error;
    if (error is FirebaseFunctionsException) {
      final reason = BackendReasons.of(error);
      final kind = kindForWhy(_detail(error, 'why')) ??
          (reason == BackendReasons.limitReached ? kindForLimit(_detail(error, 'what')) : null) ??
          kindForReason(reason) ??
          kindForCode(error.code);
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
