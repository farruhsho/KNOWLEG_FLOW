import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_contract.dart';
import '../domain/callable_errors.dart';
import '../domain/exam_pool.dart';
import '../domain/notification_draft.dart';
import '../domain/pricing_config.dart';
import '../domain/promo_code.dart';
import 'admin_firebase.dart';

/// Result of `adminPublishVariant` (ARCHITECTURE.md §3).
class PublishVariantResult {
  final String status;
  final List<String> problems;
  const PublishVariantResult(this.status, this.problems);
}

/// Result of `adminRefundOrder` (ARCHITECTURE.md §10.3).
class RefundOrderResult {
  /// `refunded` | `pending`.
  final String status;
  final int creditsClawedBack;
  const RefundOrderResult({required this.status, this.creditsClawedBack = 0});

  bool get refunded => status == 'refunded';
}

/// Typed wrappers for the admin callables (ARCHITECTURE.md §3). Secrets (the
/// Anthropic key, Play credentials) live only in the functions — SEC-001.
class AdminFunctions {
  AdminFunctions(this._functions);
  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data,
      {Duration? timeout}) async {
    final callable = _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: timeout ?? const Duration(seconds: 30)),
    );
    final res = await callable.call<dynamic>(data);
    final out = res.data;
    if (out is Map) return Map<String, dynamic>.from(out);
    return const {};
  }

  Future<void> setRole(String uid, String? role) =>
      _call(BackendFunctions.adminSetRole, {'uid': uid, 'role': role});

  Future<int?> grantCredits(String uid, int delta, String reason) async {
    final r = await _call(BackendFunctions.adminGrantCredits,
        {'uid': uid, 'delta': delta, 'reason': reason});
    final c = r['credits'];
    return c is num ? c.toInt() : null;
  }

  Future<PublishVariantResult> publishVariant(String variantId, bool publish) async {
    final r = await _call(BackendFunctions.adminPublishVariant,
        {'variantId': variantId, 'publish': publish});
    final problems = <String>[];
    final raw = r['problems'];
    if (raw is List) {
      for (final p in raw) {
        if (p is String) {
          problems.add(p);
        } else if (p is Map) {
          problems.add((p['message'] ?? p['code'] ?? p.toString()).toString());
        } else if (p != null) {
          problems.add(p.toString());
        }
      }
    }
    return PublishVariantResult((r['status'] ?? '').toString(), problems);
  }

  Future<void> updatePricing(Map<String, int> products, int freeExamsPerUser) =>
      _call(BackendFunctions.adminUpdatePricing,
          {'products': products, 'freeExamsPerUser': freeExamsPerUser});

  /// `adminUpdatePricing({webProducts, confirmBasePriceChange?})` (§10.3,
  /// super_admin): replaces `config/pricing.web_products` as a whole; Google
  /// Play products and free exams are left as they are.
  Future<void> updateWebPricing(Map<String, WebProductConfig> products) =>
      _call(BackendFunctions.adminUpdatePricing, webPricingPayload(products));

  /// Client timeout of `adminExamPoolHealth`: the function may run 120 s
  /// (one query per blueprint part plus key / passage reads).
  static const Duration examPoolHealthTimeout = Duration(seconds: 150);

  /// `adminExamPoolHealth({blueprintId, language})` (§10.1; super_admin,
  /// content_manager, methodologist).
  Future<PoolHealth> examPoolHealth(String blueprintId, String language) async {
    final r = await _call(
      BackendFunctions.adminExamPoolHealth,
      {'blueprintId': blueprintId, 'language': language},
      timeout: examPoolHealthTimeout,
    );
    return PoolHealth.fromMap(r);
  }

  /// `adminUpdateExamPool({freshEnabled?, minReviewStatus?})` (§10.1,
  /// super_admin). [update] comes from [examPoolUpdatePayload] and must not
  /// be empty.
  Future<void> updateExamPool(Map<String, Object> update) {
    if (update.isEmpty) throw ArgumentError.value(update, 'update', 'nothing to update');
    return _call(BackendFunctions.adminUpdateExamPool, update);
  }

  /// `adminRefundOrder({orderId, reason})` (§10.3, super_admin). `refunded`:
  /// the provider refunded at once and the credits were clawed back;
  /// `pending`: the provider confirms later (its webhook claws back).
  Future<RefundOrderResult> refundOrder(String orderId, String reason) async {
    final r = await _call(BackendFunctions.adminRefundOrder, {'orderId': orderId, 'reason': reason});
    final clawed = r['creditsClawedBack'];
    return RefundOrderResult(
      status: (r['status'] ?? '').toString(),
      creditsClawedBack: clawed is num ? clawed.toInt() : 0,
    );
  }

  Future<List<Map<String, dynamic>>> aiDraftQuestions({
    required String subjectId,
    required String sectionId,
    required String? partId,
    required String topicId,
    required int difficulty,
    required String language,
    required int count,
  }) async {
    final r = await _call(
      BackendFunctions.adminAiDraftQuestions,
      {
        'subjectId': subjectId,
        'sectionId': sectionId,
        'partId': partId,
        'topicId': topicId,
        'difficulty': difficulty,
        'language': language,
        'count': count.clamp(1, 10),
      },
      timeout: const Duration(seconds: 180),
    );
    final drafts = r['drafts'];
    if (drafts is! List) return const [];
    return [
      for (final d in drafts)
        if (d is Map) Map<String, dynamic>.from(d),
    ];
  }

  /// Client timeout of `adminSendNotification`, for the dry run and the send
  /// alike (§9.7): the reach check scans the same users as a send, and the
  /// function itself may run up to 540 s.
  static const Duration sendNotificationTimeout = Duration(seconds: 540);

  /// `adminSendNotification` (§9.4). With [dryRun] the server only counts
  /// the recipients ("Проверить охват"); otherwise it sends in batches of
  /// ≤ 500 and records the broadcast in `notifications`.
  Future<NotificationSendResult> sendNotification(NotificationDraft draft,
      {required bool dryRun}) async {
    final r = await _call(
      BackendFunctions.adminSendNotification,
      draft.toCallable(dryRun: dryRun),
      timeout: sendNotificationTimeout,
    );
    return NotificationSendResult.fromMap(r);
  }

  /// `adminUpsertPromoCode` (§9.2, super_admin). Creates, edits or
  /// deactivates a code; the server logs the change in `admin_logs`.
  ///
  /// With [createOnly] (a new code, §9.7) the server refuses an existing
  /// code with `VALIDATION_FAILED`, `details.why = 'exists'`
  /// ([isPromoCodeExistsError]) and changes nothing. Returns the response's
  /// `created` flag, or `null` when the server did not send one.
  Future<bool?> upsertPromoCode(PromoCodeDraft draft, {bool createOnly = false}) async {
    final r = await _call(
        BackendFunctions.adminUpsertPromoCode, draft.toCallable(createOnly: createOnly));
    final created = r['created'];
    return created is bool ? created : null;
  }
}

/// Whether [error] is the `adminUpsertPromoCode` refusal of a `createOnly`
/// call for a code that already exists (§9.7).
bool isPromoCodeExistsError(Object error) =>
    error is FirebaseFunctionsException &&
    BackendReasons.of(error) == BackendReasons.validationFailed &&
    callableDetailsWhy(error.details) == kPromoExistsWhy;

final adminFunctionsServiceProvider =
    Provider<AdminFunctions>((ref) => AdminFunctions(ref.watch(adminFunctionsProvider)));
