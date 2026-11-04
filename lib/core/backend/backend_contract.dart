import 'package:cloud_functions/cloud_functions.dart';

/// Names shared with the Cloud Functions backend (`functions/src`). Keep in
/// sync with docs/modernization/ARCHITECTURE.md §3.
abstract final class BackendFunctions {
  /// Must match the region the functions are deployed to.
  static const String region = 'europe-west1';

  static const String examStart = 'examStart';
  static const String examGetState = 'examGetState';
  static const String examSubmitSection = 'examSubmitSection';
  static const String examGetReview = 'examGetReview';
  static const String billingVerifyPurchase = 'billingVerifyPurchase';
  static const String aiTutor = 'aiTutor';
  static const String recordActivity = 'recordActivity';
  static const String accountDelete = 'accountDelete';
  static const String adminSetRole = 'adminSetRole';
  static const String adminGrantCredits = 'adminGrantCredits';
  static const String adminPublishVariant = 'adminPublishVariant';
  static const String adminUpdatePricing = 'adminUpdatePricing';
  static const String adminAiDraftQuestions = 'adminAiDraftQuestions';

  static FirebaseFunctions get instance =>
      FirebaseFunctions.instanceFor(region: region);

  static HttpsCallable callable(String name, {Duration? timeout}) =>
      instance.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: timeout ?? const Duration(seconds: 30)),
      );
}

/// `details.reason` values carried by backend HttpsErrors.
abstract final class BackendReasons {
  static const noEntitlement = 'NO_ENTITLEMENT';
  static const variantNotAvailable = 'VARIANT_NOT_AVAILABLE';
  static const attemptNotFound = 'ATTEMPT_NOT_FOUND';
  static const attemptNotInProgress = 'ATTEMPT_NOT_IN_PROGRESS';
  static const wrongSection = 'WRONG_SECTION';
  static const purchaseInvalid = 'PURCHASE_INVALID';
  static const purchaseAccountMismatch = 'PURCHASE_ACCOUNT_MISMATCH';
  static const purchasePending = 'PURCHASE_PENDING';
  static const aiQuotaExceeded = 'AI_QUOTA_EXCEEDED';
  static const aiDisabled = 'AI_DISABLED';
  static const aiExamInProgress = 'AI_EXAM_IN_PROGRESS';
  static const forbiddenRole = 'FORBIDDEN_ROLE';
  static const validationFailed = 'VALIDATION_FAILED';

  /// The account is banned by a moderator (permission-denied). Sent by
  /// examStart, aiTutor, recordActivity and adminAiDraftQuestions.
  static const userBanned = 'USER_BANNED';

  /// accountDelete needs a sign-in from the last 5 minutes
  /// (failed-precondition): re-authenticate, then retry once.
  static const requiresRecentLogin = 'REQUIRES_RECENT_LOGIN';

  /// Extracts `details.reason` from a callable error, if present.
  static String? of(Object error) {
    if (error is FirebaseFunctionsException) {
      final d = error.details;
      if (d is Map && d['reason'] is String) return d['reason'] as String;
    }
    return null;
  }
}

/// Firestore collections introduced by the modernization (all additive; the
/// legacy collections in AppConstants are untouched).
abstract final class Collections {
  static const examBlueprints = 'exam_blueprints';
  static const examVariants = 'exam_variants';
  static const examAttempts = 'exam_attempts';
  static const examDrafts = 'drafts'; // sub-collection of exam_attempts
  static const entitlements = 'entitlements';
  static const ledger = 'ledger'; // sub-collection of entitlements
  static const purchases = 'purchases';
  static const userStats = 'user_stats';
  static const leaderboards = 'leaderboards';
  static const leaderboardEntries = 'entries';
  static const aiUsage = 'ai_usage';
  static const config = 'config';
  static const adminLogs = 'admin_logs';
  static const userMistakes = 'user_mistakes';
  static const userMistakeItems = 'items'; // sub-collection of user_mistakes
}

/// Google Play product ids (consumables). Credits per product live
/// server-side in `config/pricing`; the price shown to users always comes
/// from Google Play's ProductDetails.
abstract final class BillingProducts {
  static const examSingle = 'exam_single';
  static const examPack5 = 'exam_pack_5';
  static const examPack10 = 'exam_pack_10';
  static const all = {examSingle, examPack5, examPack10};
}
