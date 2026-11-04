import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/pricing_config.dart';
import '../../domain/review_workflow.dart';
import '../admin_firebase.dart';
import '../models/admin_records.dart';

/// `users/{uid}` for the CMS. Role changes and credits never go through
/// Firestore — only through `adminSetRole` / `adminGrantCredits` (CMS-14).
class UsersRepository {
  UsersRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AdminCollections.users);

  /// Newest first, or an email-prefix search (single-field range → no
  /// composite index). Paginated (FB-17).
  Future<AdminPage<AdminUserRecord>> page(
    String emailPrefix, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 25,
  }) {
    final prefix = emailPrefix.trim().toLowerCase();
    final Query<Map<String, dynamic>> q = prefix.isEmpty
        ? _col.orderBy('created_at', descending: true)
        : _col
            .where('email', isGreaterThanOrEqualTo: prefix)
            .where('email', isLessThan: '$prefix')
            .orderBy('email');
    return fetchPage(q, after: after, pageSize: pageSize, map: AdminUserRecord.fromSnapshot);
  }

  Future<AdminUserRecord?> get(String uid) async {
    final d = await _col.doc(uid).get();
    return d.exists ? AdminUserRecord.fromSnapshot(d) : null;
  }

  Future<EntitlementInfo> entitlement(String uid) async {
    final d = await _db.collection(AdminCollections.entitlements).doc(uid).get();
    return EntitlementInfo.fromMap(d.data());
  }

  Future<List<LedgerEntry>> ledger(String uid, {int limit = 20}) async {
    final snap = await _db
        .collection(AdminCollections.entitlements)
        .doc(uid)
        .collection(AdminCollections.ledger)
        .orderBy('at', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(LedgerEntry.fromSnapshot).toList();
  }

  Future<Map<String, dynamic>?> stats(String uid) async =>
      (await _db.collection(AdminCollections.userStats).doc(uid).get()).data();

  /// Ban flag on the profile (CMS-15). Enforcement (rules / disabling the Auth
  /// account) is server-side; the CMS records who did it and why.
  Future<void> setBanned(String uid, bool banned, {required String actor, String reason = ''}) =>
      _col.doc(uid).update({
        'is_banned': banned,
        'ban_reason': banned ? reason : null,
        'banned_by': banned ? actor : null,
        'banned_at': banned ? FieldValue.serverTimestamp() : null,
      });

  /// Premium = the `subscription` map the student app already reads
  /// (`SubscriptionModel`: tier + expires_at), not a dead `is_premium` flag.
  Future<void> setPremium(String uid, bool premium, {required String actor, int days = 365}) =>
      _col.doc(uid).update({
        'subscription': premium
            ? {
                'tier': 'yearly',
                'expires_at': Timestamp.fromDate(DateTime.now().add(Duration(days: days))),
                'granted_by': actor,
                'source': 'admin',
              }
            : {'tier': 'free', 'expires_at': null},
      });
}

/// Read-only purchases (support + super_admin) and `config/pricing`.
class PaymentsRepository {
  PaymentsRepository(this._db);
  final FirebaseFirestore _db;

  Future<AdminPage<PurchaseRecord>> page(
    String? state, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 25,
  }) {
    final col = _db.collection(AdminCollections.purchases);
    // Equality filter alone needs no composite index; the unfiltered list is
    // newest first.
    final Query<Map<String, dynamic>> q = state == null
        ? col.orderBy('created_at', descending: true)
        : col.where('state', isEqualTo: state);
    return fetchPage(q, after: after, pageSize: pageSize, map: PurchaseRecord.fromSnapshot);
  }

  Future<PricingConfig> pricing() async {
    final d = await _db.collection(AdminCollections.config).doc(AdminCollections.pricingDoc).get();
    return d.exists ? PricingConfig.fromMap(d.data()) : PricingConfig.defaults;
  }
}

class AdminLogsRepository {
  AdminLogsRepository(this._db);
  final FirebaseFirestore _db;

  Future<AdminPage<AdminLogRecord>> page({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) =>
      fetchPage(
        _db.collection(AdminCollections.adminLogs).orderBy('at', descending: true),
        after: after,
        pageSize: pageSize,
        map: AdminLogRecord.fromSnapshot,
      );
}

/// Dashboard counters — `count()` aggregations, never collection scans
/// (FB-17 / CMS-02).
enum AdminStat {
  users,
  subjects,
  lessons,
  practiceQuestions,
  examQuestions,
  examPendingReview,
  examApproved,
  publishedVariants,
  grantedPurchases,
}

class StatsRepository {
  StatsRepository(this._db);
  final FirebaseFirestore _db;

  Query<Map<String, dynamic>> _query(AdminStat s) {
    switch (s) {
      case AdminStat.users:
        return _db.collection(AdminCollections.users);
      case AdminStat.subjects:
        return _db.collection(AdminCollections.subjects);
      case AdminStat.lessons:
        return _db.collection(AdminCollections.lessons);
      case AdminStat.practiceQuestions:
        return _db.collection(AdminCollections.questions);
      case AdminStat.examQuestions:
        return _db.collection(AdminCollections.examQuestions);
      case AdminStat.examPendingReview:
        return _db.collection(AdminCollections.examQuestions).where('review.status',
            whereIn: [ReviewStatus.draft.wire, ReviewStatus.aiVerified.wire]);
      case AdminStat.examApproved:
        return _db
            .collection(AdminCollections.examQuestions)
            .where('review.status', isEqualTo: ReviewStatus.methodologistApproved.wire);
      case AdminStat.publishedVariants:
        return _db
            .collection(AdminCollections.examVariants)
            .where('status', isEqualTo: 'published');
      case AdminStat.grantedPurchases:
        return _db.collection(AdminCollections.purchases).where('state', isEqualTo: 'granted');
    }
  }

  Future<int> count(AdminStat s) async => (await _query(s).count().get()).count ?? 0;
}
