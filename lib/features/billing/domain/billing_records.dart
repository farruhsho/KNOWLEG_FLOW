import 'firestore_values.dart';

/// `purchases/{sha256(token)}.state` (ARCHITECTURE §1.6).
enum PurchaseRecordState {
  pending,
  granted,
  refunded,
  revoked,
  invalid,
  unknown;

  static PurchaseRecordState parse(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'pending':
        return pending;
      case 'granted':
        return granted;
      case 'refunded':
        return refunded;
      case 'revoked':
        return revoked;
      case 'invalid':
        return invalid;
      default:
        return unknown;
    }
  }
}

/// A server-written purchase row shown on the transactions page.
class PurchaseRecord {
  final String id;
  final String productId;
  final String? orderId;
  final PurchaseRecordState state;
  final int creditsGranted;
  final String? priceDisplay;
  final DateTime? createdAt;
  final DateTime? refundedAt;

  const PurchaseRecord({
    required this.id,
    required this.productId,
    required this.state,
    this.orderId,
    this.creditsGranted = 0,
    this.priceDisplay,
    this.createdAt,
    this.refundedAt,
  });

  factory PurchaseRecord.fromMap(String id, Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};
    final refund = FirestoreValues.readMap(d['refund']);
    return PurchaseRecord(
      id: id,
      productId: FirestoreValues.readString(d['product_id']) ?? '',
      orderId: FirestoreValues.readString(d['order_id']),
      state: PurchaseRecordState.parse(d['state']),
      creditsGranted: FirestoreValues.readInt(d['credits_granted']),
      priceDisplay: FirestoreValues.readString(d['price_display']),
      createdAt: FirestoreValues.readDate(d['created_at'] ?? d['purchase_time']),
      refundedAt: FirestoreValues.readDate(refund?['at']),
    );
  }
}

/// `entitlements/{uid}/ledger/{id}.reason`.
enum LedgerReason {
  purchase,
  examStart,
  refund,
  adminGrant,
  freeFirst,
  other;

  static LedgerReason parse(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'purchase':
        return purchase;
      case 'exam_start':
        return examStart;
      case 'refund':
        return refund;
      case 'admin_grant':
        return adminGrant;
      case 'free_first':
        return freeFirst;
      default:
        return other;
    }
  }
}

/// One balance change in the credits ledger.
class LedgerEntry {
  final String id;
  final int delta;
  final int? balanceAfter;
  final LedgerReason reason;
  final String? ref;
  final DateTime? at;

  const LedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    this.balanceAfter,
    this.ref,
    this.at,
  });

  factory LedgerEntry.fromMap(String id, Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};
    return LedgerEntry(
      id: id,
      delta: FirestoreValues.readInt(d['delta']),
      balanceAfter: d['balance_after'] == null
          ? null
          : FirestoreValues.readInt(d['balance_after']),
      reason: LedgerReason.parse(d['reason']),
      ref: FirestoreValues.readString(d['ref']),
      at: FirestoreValues.readDate(d['at']),
    );
  }
}
