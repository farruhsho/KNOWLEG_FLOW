import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_contract.dart';
import '../domain/notification_draft.dart';
import '../domain/promo_code.dart';
import 'admin_firebase.dart';

/// Result of `adminPublishVariant` (ARCHITECTURE.md §3).
class PublishVariantResult {
  final String status;
  final List<String> problems;
  const PublishVariantResult(this.status, this.problems);
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

  /// `adminSendNotification` (§9.4). With [dryRun] the server only counts
  /// the recipients ("Проверить охват"); otherwise it sends in batches of
  /// ≤ 500 and records the broadcast in `notifications`.
  Future<NotificationSendResult> sendNotification(NotificationDraft draft,
      {required bool dryRun}) async {
    final r = await _call(
      BackendFunctions.adminSendNotification,
      draft.toCallable(dryRun: dryRun),
      timeout: Duration(seconds: dryRun ? 60 : 300),
    );
    return NotificationSendResult.fromMap(r);
  }

  /// `adminUpsertPromoCode` (§9.2, super_admin). Creates, edits or
  /// deactivates a code; the server logs the change in `admin_logs`.
  Future<void> upsertPromoCode(PromoCodeDraft draft) =>
      _call(BackendFunctions.adminUpsertPromoCode, draft.toCallable());
}

final adminFunctionsServiceProvider =
    Provider<AdminFunctions>((ref) => AdminFunctions(ref.watch(adminFunctionsProvider)));
