import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/exam_question.dart' show readDateTolerant;
import '../../domain/localized_text.dart';
import '../../domain/variant_validation.dart';

int _int(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);
String _s(Object? v) => v == null ? '' : v.toString();
String? _sn(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Row of `users/{uid}` as the CMS shows it (FB-22: real snake_case fields).
class AdminUserRecord {
  final String uid;
  final String name;
  final String email;

  /// Legacy `users.role` (`student` | `admin`). The effective admin role is a
  /// custom claim and is not readable from Firestore.
  final String legacyRole;
  final bool isBanned;
  final String subscriptionTier;
  final DateTime? subscriptionExpiresAt;
  final DateTime? createdAt;
  final DateTime? lastActive;
  final String preferredLanguage;
  final int? grade;
  final String? school;

  const AdminUserRecord({
    required this.uid,
    required this.name,
    required this.email,
    this.legacyRole = 'student',
    this.isBanned = false,
    this.subscriptionTier = 'free',
    this.subscriptionExpiresAt,
    this.createdAt,
    this.lastActive,
    this.preferredLanguage = 'ru',
    this.grade,
    this.school,
  });

  bool get isPremium =>
      subscriptionTier != 'free' &&
      (subscriptionExpiresAt == null || subscriptionExpiresAt!.isAfter(DateTime.now()));

  factory AdminUserRecord.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final sub = d['subscription'];
    return AdminUserRecord(
      uid: doc.id,
      name: _s(d['name'] ?? d['display_name'] ?? d['displayName']),
      email: _s(d['email']),
      legacyRole: _sn(d['role']) ?? 'student',
      isBanned: d['is_banned'] == true,
      subscriptionTier: sub is Map ? (_sn(sub['tier']) ?? 'free') : 'free',
      subscriptionExpiresAt: sub is Map ? readDateTolerant(sub['expires_at']) : null,
      createdAt: readDateTolerant(d['created_at'] ?? d['createdAt']),
      lastActive: readDateTolerant(d['last_active'] ?? d['lastActive']),
      preferredLanguage: _sn(d['preferred_language']) ?? 'ru',
      grade: d['grade'] is num ? (d['grade'] as num).toInt() : null,
      school: _sn(d['school']),
    );
  }
}

/// `entitlements/{uid}` (ARCHITECTURE.md §1.5).
class EntitlementInfo {
  final bool exists;
  final int credits;
  final bool freeExamUsed;
  final int lifetimeCreditsPurchased;
  final DateTime? updatedAt;

  const EntitlementInfo({
    this.exists = false,
    this.credits = 0,
    this.freeExamUsed = false,
    this.lifetimeCreditsPurchased = 0,
    this.updatedAt,
  });

  factory EntitlementInfo.fromMap(Map<String, dynamic>? d) => d == null
      ? const EntitlementInfo()
      : EntitlementInfo(
          exists: true,
          credits: _int(d['credits']),
          freeExamUsed: d['free_exam_used'] == true,
          lifetimeCreditsPurchased: _int(d['lifetime_credits_purchased']),
          updatedAt: readDateTolerant(d['updated_at']),
        );
}

/// `entitlements/{uid}/ledger/{id}`.
class LedgerEntry {
  final String id;
  final int delta;
  final int balanceAfter;
  final String reason;
  final String ref;
  final String? actorUid;
  final DateTime? at;

  const LedgerEntry({
    required this.id,
    required this.delta,
    required this.balanceAfter,
    required this.reason,
    required this.ref,
    this.actorUid,
    this.at,
  });

  factory LedgerEntry.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return LedgerEntry(
      id: doc.id,
      delta: _int(d['delta']),
      balanceAfter: _int(d['balance_after']),
      reason: _s(d['reason']),
      ref: _s(d['ref']),
      actorUid: _sn(d['actor_uid']),
      at: readDateTolerant(d['at']),
    );
  }
}

/// `purchases/{sha256(token)}` (ARCHITECTURE.md §1.6).
class PurchaseRecord {
  final String id;
  final String uid;
  final String platform;
  final String productId;
  final String orderId;
  final String state;
  final int creditsGranted;
  final String priceDisplay;
  final DateTime? purchaseTime;
  final DateTime? createdAt;
  final Map<String, dynamic>? refund;

  const PurchaseRecord({
    required this.id,
    required this.uid,
    required this.platform,
    required this.productId,
    required this.orderId,
    required this.state,
    required this.creditsGranted,
    required this.priceDisplay,
    this.purchaseTime,
    this.createdAt,
    this.refund,
  });

  static const states = ['pending', 'granted', 'refunded', 'revoked', 'invalid'];

  factory PurchaseRecord.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return PurchaseRecord(
      id: doc.id,
      uid: _s(d['uid']),
      platform: _s(d['platform']),
      productId: _s(d['product_id']),
      orderId: _s(d['order_id']),
      state: _s(d['state']),
      creditsGranted: _int(d['credits_granted']),
      priceDisplay: _s(d['price_display']),
      purchaseTime: readDateTolerant(d['purchase_time']),
      createdAt: readDateTolerant(d['created_at']),
      refund: d['refund'] is Map ? Map<String, dynamic>.from(d['refund'] as Map) : null,
    );
  }
}

/// `admin_logs/{id}`, written by the admin callables. The schema is not fixed
/// in ARCHITECTURE.md, so every field is read tolerantly.
class AdminLogRecord {
  final String id;
  final String action;
  final String? actorUid;
  final String? targetUid;
  final Map<String, dynamic> details;
  final DateTime? at;

  const AdminLogRecord({
    required this.id,
    required this.action,
    this.actorUid,
    this.targetUid,
    this.details = const {},
    this.at,
  });

  factory AdminLogRecord.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final details = <String, dynamic>{};
    final raw = d['details'] ?? d['payload'] ?? d['data'];
    if (raw is Map) {
      details.addAll(Map<String, dynamic>.from(raw));
    } else {
      for (final e in d.entries) {
        if (!const {'action', 'actor_uid', 'actor', 'target_uid', 'target', 'at', 'created_at'}
            .contains(e.key)) {
          details[e.key] = e.value;
        }
      }
    }
    return AdminLogRecord(
      id: doc.id,
      action: _s(d['action'] ?? d['type'] ?? d['function']),
      actorUid: _sn(d['actor_uid'] ?? d['actor']),
      targetUid: _sn(d['target_uid'] ?? d['target']),
      details: details,
      at: readDateTolerant(d['at'] ?? d['created_at']),
    );
  }
}

/// `exam_variants/{id}` (ARCHITECTURE.md §1.2).
class VariantDoc {
  final String id;
  final String blueprintId;
  final int blueprintVersion;
  final int number;
  final Map<String, String> title;
  final String language;

  /// draft | in_review | published | archived.
  final String status;
  final List<VariantSectionDraft> sections;
  final int contentVersion;
  final String difficultyLabel;
  final DateTime? publishedAt;

  const VariantDoc({
    required this.id,
    required this.blueprintId,
    required this.blueprintVersion,
    required this.number,
    required this.title,
    required this.language,
    this.status = 'draft',
    this.sections = const [],
    this.contentVersion = 1,
    this.difficultyLabel = 'standard',
    this.publishedAt,
  });

  static const statuses = ['draft', 'in_review', 'published', 'archived'];

  bool get isPublished => status == 'published';
  int get questionCount => sections.fold(0, (a, s) => a + s.questionIds.length);

  factory VariantDoc.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) =>
      VariantDoc.fromMap(doc.id, doc.data() ?? const {});

  factory VariantDoc.fromMap(String id, Map<String, dynamic> d) {
    final sections = <VariantSectionDraft>[];
    final raw = d['sections'];
    if (raw is List) {
      for (final s in raw) {
        if (s is! Map) continue;
        final ids = s['question_ids'];
        sections.add(VariantSectionDraft(
          _s(s['section_id']),
          ids is List ? [for (final i in ids) if (i != null) i.toString()] : const [],
        ));
      }
    }
    return VariantDoc(
      id: id,
      blueprintId: _s(d['blueprint_id']),
      blueprintVersion: _int(d['blueprint_version'], 1),
      number: _int(d['number'], 1),
      title: readLocalized(d['title']),
      language: (_sn(d['language']) ?? 'ru') == 'kg' ? 'ky' : (_sn(d['language']) ?? 'ru'),
      status: _sn(d['status']) ?? 'draft',
      sections: sections,
      contentVersion: _int(d['content_version'], 1),
      difficultyLabel: _sn(d['difficulty_label']) ?? 'standard',
      publishedAt: readDateTolerant(d['published_at']),
    );
  }

  VariantDoc copyWith({
    String? blueprintId,
    int? blueprintVersion,
    int? number,
    Map<String, String>? title,
    String? language,
    String? status,
    List<VariantSectionDraft>? sections,
    int? contentVersion,
    String? difficultyLabel,
  }) =>
      VariantDoc(
        id: id,
        blueprintId: blueprintId ?? this.blueprintId,
        blueprintVersion: blueprintVersion ?? this.blueprintVersion,
        number: number ?? this.number,
        title: title ?? this.title,
        language: language ?? this.language,
        status: status ?? this.status,
        sections: sections ?? this.sections,
        contentVersion: contentVersion ?? this.contentVersion,
        difficultyLabel: difficultyLabel ?? this.difficultyLabel,
        publishedAt: publishedAt,
      );

  VariantDraft toDraft() => VariantDraft(
        blueprintId: blueprintId,
        blueprintVersion: blueprintVersion,
        language: language,
        sections: sections,
      );
}
