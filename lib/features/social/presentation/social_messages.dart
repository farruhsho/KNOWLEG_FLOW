import '../../../l10n/app_localizations.dart';
import '../domain/social_failure.dart';

/// What the student was doing when a [SocialFailure] happened. The same
/// backend reason reads differently per action (ALREADY_REDEEMED is "promo
/// already used" for a promo code but "you already entered a friend's code"
/// for a referral).
enum SocialAction { referral, promo, friendAdd, groupJoin, groupCreate, other }

extension SocialL10n on AppLocalizations {
  /// Human message for [failure] during [action] — never the raw error.
  String socialFailureMessage(SocialFailure failure, SocialAction action) =>
      socialFailureKindMessage(failure.kind, action);

  String socialFailureKindMessage(SocialFailureKind kind, SocialAction action) {
    switch (kind) {
      case SocialFailureKind.codeInvalid:
        return socialErrorCodeInvalid;
      case SocialFailureKind.codeExpired:
        return socialErrorCodeExpired;
      case SocialFailureKind.codeExhausted:
        return socialErrorCodeExhausted;
      case SocialFailureKind.alreadyRedeemed:
        return switch (action) {
          SocialAction.promo => socialErrorPromoAlreadyRedeemed,
          SocialAction.referral => socialErrorReferralAlreadyApplied,
          SocialAction.friendAdd => socialErrorFriendAlready,
          SocialAction.groupJoin => socialErrorGroupAlreadyMember,
          _ => socialErrorAlreadyDone,
        };
      case SocialFailureKind.rateLimited:
        return socialErrorRateLimited;
      case SocialFailureKind.referralNotAllowed:
        return socialErrorReferralNotAllowed;
      case SocialFailureKind.limitReached:
        return switch (action) {
          SocialAction.friendAdd => socialErrorFriendLimit,
          SocialAction.groupJoin || SocialAction.groupCreate => socialErrorGroupLimit,
          _ => socialErrorLimitGeneric,
        };
      case SocialFailureKind.notGroupOwner:
        return socialErrorNotGroupOwner;
      case SocialFailureKind.ownCode:
        return socialErrorOwnCode;
      case SocialFailureKind.banned:
        return socialErrorBanned;
      case SocialFailureKind.notSignedIn:
        return socialErrorNotSignedIn;
      case SocialFailureKind.permissionDenied:
        return socialErrorPermission;
      case SocialFailureKind.notFound:
        return socialErrorNotFound;
      case SocialFailureKind.offline:
        return socialErrorOffline;
      case SocialFailureKind.unsupportedPlatform:
        return socialErrorPlatform;
      case SocialFailureKind.validation:
        return socialErrorValidation;
      case SocialFailureKind.unknown:
        return socialErrorGeneric;
    }
  }

  /// Message for any error thrown by a social action.
  String socialErrorMessage(Object error, SocialAction action) =>
      socialFailureMessage(SocialFailure.from(error), action);

  /// "42 с на вопрос" / "1 мин 35 с на вопрос" for an average in seconds.
  String socialTimePerQuestion(double seconds) {
    final total = seconds.isFinite && seconds > 0 ? seconds.round() : 0;
    if (total < 60) return socialSecondsPerQuestion(total);
    return socialMinSecPerQuestion(total ~/ 60, total % 60);
  }
}
