import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/backend/backend_contract.dart';
import '../application/paged_list_controller.dart';
import '../domain/billing_records.dart';

/// Read-only access to the server-written purchase history and credit ledger.
///
/// Firestore index needed (owned by the backend package):
/// `purchases` — `uid ASC, created_at DESC`.
class BillingHistoryRepository {
  BillingHistoryRepository([FirebaseFirestore? db]) : _dbOverride = db;

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  static const pageSize = 20;

  Future<PageChunk<PurchaseRecord>> purchases(String uid, Object? cursor) async {
    // The rules only allow reading purchases whose uid is the caller, so the
    // equality filter is mandatory, not an optimisation.
    Query<Map<String, dynamic>> q = _db
        .collection(Collections.purchases)
        .where('uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(pageSize);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return PageChunk(
      [for (final d in snap.docs) PurchaseRecord.fromMap(d.id, d.data())],
      nextCursor: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == pageSize,
    );
  }

  Future<PageChunk<LedgerEntry>> ledger(String uid, Object? cursor) async {
    Query<Map<String, dynamic>> q = _db
        .collection(Collections.entitlements)
        .doc(uid)
        .collection(Collections.ledger)
        .orderBy('at', descending: true)
        .limit(pageSize);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return PageChunk(
      [for (final d in snap.docs) LedgerEntry.fromMap(d.id, d.data())],
      nextCursor: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == pageSize,
    );
  }
}
