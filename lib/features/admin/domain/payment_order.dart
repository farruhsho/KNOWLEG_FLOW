/// Web payment orders (ARCHITECTURE.md §10.3) for the CMS «Платежи» page.
///
/// `payment_orders/{orderId}` = `{uid, product_id, credits, amount_som,
/// currency: 'KGS', provider, status: created|pending|paid|failed|expired|
/// refunded, provider_ref, checkout_url, created_at, updated_at, expires_at,
/// paid_at, granted, refund: null|{at, source: provider|admin,
/// credits_clawed_back, debt_added?}, refund_requested?: {at, by, reason},
/// failure?: {code}}` — written only by the payment functions; super_admin and
/// support read all of them (view_payments).
///
/// Pure Dart (no Flutter / Firebase) so parsing, refund rules and the
/// revenue summary are unit-tested.
library;

import 'exam_question.dart' show readDateTolerant;

/// `payment_orders.status` values, in the order the CMS filter lists them.
/// Mirrors `PaymentOrderStatuses` (lib/core/backend/backend_contract.dart).
const List<String> kPaymentOrderStatuses = [
  'created',
  'pending',
  'paid',
  'failed',
  'expired',
  'refunded',
];

/// `adminRefundOrder` reason length after trimming (server `reqString(reason,
/// 3, 200)`, counted in UTF-16 code units like a JS string).
const int kRefundReasonMin = 3;
const int kRefundReasonMax = 200;

/// Trimmed refund reason, or `null` when its length is outside
/// [kRefundReasonMin]..[kRefundReasonMax].
String? validRefundReason(String raw) {
  final t = raw.trim();
  return t.length >= kRefundReasonMin && t.length <= kRefundReasonMax ? t : null;
}

/// `payment_orders.failure.code` of an order paid after its account was
/// deleted: `paid`, `granted: false` (functions/src/handlers/payments.ts).
const String kAccountDeletedFailure = 'account_deleted';

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

String _str(Object? v) => v is String ? v : (v == null ? '' : v.toString());

String? _strOrNull(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

Map<String, dynamic>? _mapOrNull(Object? v) =>
    v is Map ? {for (final e in v.entries) e.key.toString(): e.value} : null;

/// `payment_orders.refund` (set when the order was refunded).
class OrderRefund {
  final DateTime? at;

  /// `admin` (adminRefundOrder) or `provider` (refund webhook).
  final String source;
  final int creditsClawedBack;

  /// Credits the user could not give back (already spent) → debt.
  final int debtAdded;

  const OrderRefund({this.at, required this.source, this.creditsClawedBack = 0, this.debtAdded = 0});

  factory OrderRefund.fromMap(Map<String, dynamic> m) => OrderRefund(
        at: readDateTolerant(m['at']),
        source: _str(m['source']),
        creditsClawedBack: _int(m['credits_clawed_back']),
        debtAdded: _int(m['debt_added']),
      );
}

/// `payment_orders.refund_requested`: adminRefundOrder asked the provider,
/// which confirms asynchronously (the `refunded` webhook claws back).
class OrderRefundRequest {
  final DateTime? at;
  final String? by;
  final String reason;

  const OrderRefundRequest({this.at, this.by, this.reason = ''});

  factory OrderRefundRequest.fromMap(Map<String, dynamic> m) => OrderRefundRequest(
        at: readDateTolerant(m['at']),
        by: _strOrNull(m['by']),
        reason: _str(m['reason']),
      );
}

class PaymentOrder {
  final String id;
  final String uid;
  final String productId;
  final int credits;
  final int amountSom;
  final String currency;
  final String provider;
  final String status;
  final String? providerRef;
  final bool granted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;
  final DateTime? expiresAt;
  final OrderRefund? refund;
  final OrderRefundRequest? refundRequested;

  /// `failure.code` (`checkout_failed`, `amount_mismatch`, `provider_failed`,
  /// `account_deleted`, …).
  final String? failureCode;

  const PaymentOrder({
    required this.id,
    required this.uid,
    required this.productId,
    required this.credits,
    required this.amountSom,
    this.currency = 'KGS',
    required this.provider,
    required this.status,
    this.providerRef,
    this.granted = false,
    this.createdAt,
    this.updatedAt,
    this.paidAt,
    this.expiresAt,
    this.refund,
    this.refundRequested,
    this.failureCode,
  });

  factory PaymentOrder.fromMap(String id, Map<String, dynamic>? raw) {
    final d = raw ?? const <String, dynamic>{};
    final refund = _mapOrNull(d['refund']);
    final requested = _mapOrNull(d['refund_requested']);
    final failure = _mapOrNull(d['failure']);
    return PaymentOrder(
      id: id,
      uid: _str(d['uid']),
      productId: _str(d['product_id']),
      credits: _int(d['credits']),
      amountSom: _int(d['amount_som']),
      currency: _strOrNull(d['currency']) ?? 'KGS',
      provider: _str(d['provider']),
      status: _strOrNull(d['status']) ?? 'created',
      providerRef: _strOrNull(d['provider_ref']),
      granted: d['granted'] == true,
      createdAt: readDateTolerant(d['created_at']),
      updatedAt: readDateTolerant(d['updated_at']),
      paidAt: readDateTolerant(d['paid_at']),
      expiresAt: readDateTolerant(d['expires_at']),
      refund: refund == null ? null : OrderRefund.fromMap(refund),
      refundRequested: requested == null ? null : OrderRefundRequest.fromMap(requested),
      failureCode: failure == null ? null : _strOrNull(failure['code']),
    );
  }

  /// Whether `adminRefundOrder` accepts this order: a paid order with no
  /// refund requested yet (the server reserves the refund first and answers
  /// `refund_in_progress` to a second request), whose credits were granted —
  /// or that was paid for a deleted account ([paidWithoutCredits]), refunded
  /// without a clawback.
  bool get canRefund =>
      status == 'paid' && refundRequested == null && (granted || paidWithoutCredits);

  /// Paid, but no credits were given: the account was deleted before the
  /// payment arrived (`failure.code == 'account_deleted'`). A refund returns
  /// the money only — there is nothing to claw back.
  bool get paidWithoutCredits =>
      status == 'paid' && !granted && failureCode == kAccountDeletedFailure;

  /// A refund was requested from the provider and is not confirmed yet.
  bool get refundPending => refundRequested != null && status != 'refunded';
}

/// Revenue of one Bishkek day.
class RevenueDay {
  /// `yyyy-mm-dd` in Bishkek (UTC+6).
  final String day;
  final int amountSom;
  final int orders;

  const RevenueDay(this.day, this.amountSom, this.orders);
}

/// Paid web orders per Bishkek day (`paid_at`), for the last [days] days.
class RevenueSummary {
  /// Newest day first; days without payments are included (amount 0).
  final List<RevenueDay> days;
  final int totalSom;
  final int totalOrders;

  /// Orders paid in the window and refunded since (not part of the revenue).
  final int refundedSom;
  final int refundedOrders;

  /// The query hit its document limit: the totals may be incomplete.
  final bool truncated;

  const RevenueSummary({
    required this.days,
    required this.totalSom,
    required this.totalOrders,
    required this.refundedSom,
    required this.refundedOrders,
    this.truncated = false,
  });

  int get maxDaySom => days.fold(0, (a, d) => d.amountSom > a ? d.amountSom : a);

  /// Summarises [orders] (any statuses; only `paid` counts as revenue,
  /// `refunded` is reported separately) for the [days] Bishkek days ending
  /// today ([now]).
  factory RevenueSummary.compute(
    Iterable<PaymentOrder> orders, {
    required DateTime now,
    int days = 30,
    bool truncated = false,
  }) {
    final keys = revenueDayKeys(now, days: days);
    final amount = {for (final k in keys) k: 0};
    final count = {for (final k in keys) k: 0};
    var refundedSom = 0;
    var refundedOrders = 0;
    for (final o in orders) {
      final paid = o.paidAt;
      if (paid == null) continue;
      final key = bishkekDayKey(paid);
      if (!amount.containsKey(key)) continue;
      if (o.status == 'paid') {
        amount[key] = amount[key]! + o.amountSom;
        count[key] = count[key]! + 1;
      } else if (o.status == 'refunded') {
        refundedSom += o.amountSom;
        refundedOrders++;
      }
    }
    final list = [for (final k in keys) RevenueDay(k, amount[k]!, count[k]!)];
    return RevenueSummary(
      days: list,
      totalSom: list.fold(0, (a, d) => a + d.amountSom),
      totalOrders: list.fold(0, (a, d) => a + d.orders),
      refundedSom: refundedSom,
      refundedOrders: refundedOrders,
      truncated: truncated,
    );
  }
}

/// Calendar day of [t] in Bishkek (UTC+6, no DST) as `yyyy-mm-dd`.
String bishkekDayKey(DateTime t) {
  final b = t.toUtc().add(const Duration(hours: 6));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${b.year}-${two(b.month)}-${two(b.day)}';
}

/// The [days] Bishkek day keys ending with the day of [now], newest first.
List<String> revenueDayKeys(DateTime now, {int days = 30}) {
  final b = now.toUtc().add(const Duration(hours: 6));
  final today = DateTime.utc(b.year, b.month, b.day);
  String two(int n) => n.toString().padLeft(2, '0');
  return [
    for (var i = 0; i < days; i++)
      () {
        final d = DateTime.utc(today.year, today.month, today.day - i);
        return '${d.year}-${two(d.month)}-${two(d.day)}';
      }(),
  ];
}

/// The instant the revenue window starts: midnight in Bishkek of the oldest
/// of the [days] days ending today ([now]), as UTC.
DateTime revenueWindowStart(DateTime now, {int days = 30}) {
  final b = now.toUtc().add(const Duration(hours: 6));
  return DateTime.utc(b.year, b.month, b.day - (days - 1)).subtract(const Duration(hours: 6));
}
