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

  // Phase 3 (ARCHITECTURE §9).
  static const String referralGetCode = 'referralGetCode';
  static const String referralApply = 'referralApply';
  static const String promoRedeem = 'promoRedeem';
  static const String adminUpsertPromoCode = 'adminUpsertPromoCode';
  static const String friendAdd = 'friendAdd';
  static const String groupCreate = 'groupCreate';
  static const String groupJoin = 'groupJoin';
  static const String groupLeave = 'groupLeave';
  static const String groupRemoveMember = 'groupRemoveMember';
  static const String adminSendNotification = 'adminSendNotification';

  // Phase 4 (ARCHITECTURE §10): fresh variants, strict mode, web payments.
  static const String paymentCreateOrder = 'paymentCreateOrder';
  static const String paymentGetOrder = 'paymentGetOrder';
  static const String adminRefundOrder = 'adminRefundOrder';
  static const String adminUpdateExamPool = 'adminUpdateExamPool';
  static const String adminExamPoolHealth = 'adminExamPoolHealth';

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

  // Phase 3 (ARCHITECTURE §9).
  static const codeInvalid = 'CODE_INVALID';
  static const codeExpired = 'CODE_EXPIRED';
  static const codeExhausted = 'CODE_EXHAUSTED';
  static const alreadyRedeemed = 'ALREADY_REDEEMED';
  static const rateLimited = 'RATE_LIMITED';
  static const referralNotAllowed = 'REFERRAL_NOT_ALLOWED';
  static const limitReached = 'LIMIT_REACHED';
  static const notGroupOwner = 'NOT_GROUP_OWNER';

  // Phase 4 (ARCHITECTURE §10).

  /// `examStart` mode `fresh`: the verified bank cannot cover the blueprint
  /// in this language even with repeats; no credit was charged.
  /// `details: {section_id, part_id}`.
  static const poolTooSmall = 'POOL_TOO_SMALL';

  /// `examSubmitSection` of a strict attempt before `deadline_at − 5 s`.
  static const sectionNotOver = 'SECTION_NOT_OVER';

  /// `paymentCreateOrder` while no payment provider is configured.
  static const paymentsDisabled = 'PAYMENTS_DISABLED';

  /// `paymentGetOrder` / `adminRefundOrder`: unknown or someone else's order.
  static const orderNotFound = 'ORDER_NOT_FOUND';

  /// `paymentCreateOrder`: product disabled or unknown in
  /// `config/pricing.web_products`.
  static const productUnavailable = 'PRODUCT_UNAVAILABLE';

  /// Extracts `details.reason` from a callable error, if present.
  static String? of(Object error) {
    if (error is FirebaseFunctionsException) {
      final d = error.details;
      if (d is Map && d['reason'] is String) return d['reason'] as String;
    }
    return null;
  }

  /// The whole `details` map of a callable error (empty when absent), e.g.
  /// `{reason: 'POOL_TOO_SMALL', section_id: 'math', part_id: 'p1'}`.
  static Map<String, Object?> detailsOf(Object error) {
    if (error is FirebaseFunctionsException) {
      final d = error.details;
      if (d is Map) {
        return {for (final e in d.entries) e.key.toString(): e.value};
      }
    }
    return const {};
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

  // Phase 3 (ARCHITECTURE §9).
  static const referrals = 'referrals';
  static const referralItems = 'items'; // sub-collection of referrals
  static const friends = 'friends';
  static const friendList = 'list'; // sub-collection of friends
  static const groups = 'groups';
  static const groupMembers = 'members'; // sub-collection of groups
  static const groupAssignments = 'assignments'; // sub-collection of groups
  static const assignmentSubmissions = 'submissions'; // sub-collection of assignments
  static const notifications = 'notifications';

  // Phase 4 (ARCHITECTURE §10.3). Server-written; the owner reads own
  // orders, super_admin and support read all.
  static const paymentOrders = 'payment_orders';

  /// Webhook idempotency records (server only).
  static const paymentEvents = 'payment_events';
}

/// Document ids inside [Collections.config].
abstract final class ConfigDocs {
  /// Credits per product, free exams per user, `web_products` (§10.3).
  static const pricing = 'pricing';

  /// `{fresh_enabled, min_review_status, updated_at, updated_by}` (§10.1).
  /// Read by signed-in users; written only by `adminUpdateExamPool`.
  static const examPool = 'exam_pool';
  static const aiTutor = 'ai_tutor';
  static const achievements = 'achievements';
}

/// `payment_orders/{id}.status` values (ARCHITECTURE §10.3).
abstract final class PaymentOrderStatuses {
  static const created = 'created';
  static const pending = 'pending';
  static const paid = 'paid';
  static const failed = 'failed';
  static const expired = 'expired';
  static const refunded = 'refunded';

  /// Final states: polling stops once an order reaches one of these.
  static const terminal = {paid, failed, expired, refunded};
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
