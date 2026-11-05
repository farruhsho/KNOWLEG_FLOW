import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/backend/backend_contract.dart';
import '../../domain/exam_pool.dart';
import '../../domain/payment_order.dart';
import '../admin_firebase.dart';

/// Web payment orders (ARCHITECTURE.md §10.3): read-only for super_admin and
/// support (`payment_orders` rule: `canViewPayments()`). Every change goes
/// through the payment functions (`adminRefundOrder` for refunds).
class PaymentOrdersRepository {
  PaymentOrdersRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.paymentOrders);

  /// Newest first; with [status] the composite index `(status, created_at
  /// DESC)` from firestore.indexes.json is used. Paginated (FB-17).
  Future<AdminPage<PaymentOrder>> page(
    String? status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 25,
  }) {
    final Query<Map<String, dynamic>> q = status == null
        ? _col.orderBy('created_at', descending: true)
        : _col.where('status', isEqualTo: status).orderBy('created_at', descending: true);
    return fetchPage(q, after: after, pageSize: pageSize, map: (d) => PaymentOrder.fromMap(d.id, d.data()));
  }

  /// Most orders the revenue summary reads (one query).
  static const int revenueLimit = 3000;

  /// Orders paid since the start of the revenue window (`paid_at` range on a
  /// single field — no composite index). Orders that were never paid have
  /// `paid_at: null` and are not returned.
  Future<RevenueSummary> revenue({required DateTime now, int days = 30}) async {
    final start = revenueWindowStart(now, days: days);
    final snap = await _col
        .where('paid_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('paid_at', descending: true)
        .limit(revenueLimit)
        .get();
    return RevenueSummary.compute(
      [for (final d in snap.docs) PaymentOrder.fromMap(d.id, d.data())],
      now: now,
      days: days,
      truncated: snap.docs.length >= revenueLimit,
    );
  }
}

/// `config/exam_pool` (§10.1): readable by every signed-in user, written only
/// by `adminUpdateExamPool`.
class ExamPoolRepository {
  ExamPoolRepository(this._db);
  final FirebaseFirestore _db;

  Future<ExamPoolConfig> config() async {
    final d = await _db.collection(Collections.config).doc(ConfigDocs.examPool).get();
    return d.exists ? ExamPoolConfig.fromMap(d.data()) : ExamPoolConfig.defaults;
  }
}
