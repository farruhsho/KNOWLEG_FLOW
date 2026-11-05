import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/backend/backend_contract.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';
import 'package:knowledge_flow/features/admin/admin_routes.dart';
import 'package:knowledge_flow/features/admin/data/admin_functions.dart';
import 'package:knowledge_flow/features/admin/data/models/admin_records.dart';
import 'package:knowledge_flow/features/admin/data/repositories/exam_repositories.dart';
import 'package:knowledge_flow/features/admin/domain/admin_nav.dart';
import 'package:knowledge_flow/features/admin/domain/admin_role.dart';
import 'package:knowledge_flow/features/admin/domain/exam_pool.dart';
import 'package:knowledge_flow/features/admin/domain/payment_order.dart';
import 'package:knowledge_flow/features/admin/domain/pricing_config.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/variants_page.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/web_payments_page.dart';
import 'package:knowledge_flow/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:knowledge_flow/l10n/app_localizations_ru.dart';

import 'phase4_fixtures.dart';

/// Records every callable invocation: name, client timeout and payload.
class _FakeFunctions implements FirebaseFunctions {
  final calls = <({String name, Duration? timeout, Object? data})>[];
  Object? response = const <String, dynamic>{};

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FakeCallable(this, name, options?.timeout);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  _FakeCallable(this._functions, this._name, this._timeout);
  final _FakeFunctions _functions;
  final String _name;
  final Duration? _timeout;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    _functions.calls.add((name: _name, timeout: _timeout, data: parameters));
    return _Result<T>(_functions.response as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Result<T> implements HttpsCallableResult<T> {
  _Result(this.data);

  @override
  final T data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<String> _paths(List<RouteBase> routes) => [
      for (final r in routes) ...[
        if (r is GoRoute) r.path,
        ..._paths(r.routes),
      ],
    ];

void main() {
  final l = AppLocalizationsRu();

  group('config/exam_pool (§10.1)', () {
    test('missing document and odd values fall back to the server defaults', () {
      expect(ExamPoolConfig.fromMap(null).exists, isFalse);
      expect(ExamPoolConfig.defaults.freshEnabled, isTrue);
      expect(ExamPoolConfig.defaults.minReviewStatus, MinReviewStatus.methodologistApproved);
      final odd = ExamPoolConfig.fromMap({'fresh_enabled': 'no', 'min_review_status': 'draft'});
      expect(odd.freshEnabled, isTrue);
      expect(odd.minReviewStatus, MinReviewStatus.methodologistApproved);
      expect(odd.exists, isTrue);
    });

    test('stored values are read', () {
      final c = ExamPoolConfig.fromMap({
        'fresh_enabled': false,
        'min_review_status': 'ai_verified',
        'updated_at': DateTime.utc(2026, 11, 5, 10),
        'updated_by': 'owner-uid',
      });
      expect(c.freshEnabled, isFalse);
      expect(c.minReviewStatus, MinReviewStatus.aiVerified);
      expect(c.updatedAt, DateTime.utc(2026, 11, 5, 10));
      expect(c.updatedBy, 'owner-uid');
    });

    test('the update payload carries only changed fields', () {
      const c = ExamPoolConfig(freshEnabled: true, minReviewStatus: MinReviewStatus.methodologistApproved);
      expect(examPoolUpdatePayload(c, freshEnabled: true), isEmpty);
      expect(examPoolUpdatePayload(c, freshEnabled: false), {'freshEnabled': false});
      expect(examPoolUpdatePayload(c, minReviewStatus: MinReviewStatus.aiVerified), {'minReviewStatus': 'ai_verified'});
      expect(
        examPoolUpdatePayload(c, freshEnabled: false, minReviewStatus: MinReviewStatus.methodologistApproved),
        {'freshEnabled': false},
      );
    });
  });

  group('adminExamPoolHealth report', () {
    final h = PoolHealth.fromMap(healthResponse());

    test('parses sections, parts, counts and the config echo', () {
      expect(h.blueprintId, 'ort_main_2026');
      expect(h.language, 'ru');
      expect(h.freshEnabled, isTrue);
      expect(h.minReviewStatus, MinReviewStatus.aiVerified);
      expect(h.sections.map((s) => s.sectionId), ['math', 'reading']);
      final p1 = h.sections.first.parts.first;
      expect(p1.byStatus.total, 59);
      expect(p1.byStatus.atLeast(MinReviewStatus.methodologistApproved), 40);
      expect(p1.byStatus.atLeast(MinReviewStatus.aiVerified), 52);
      expect(p1.missing, 0);
      expect(p1.covered, isTrue);
      final p2 = h.sections.first.parts[1];
      expect(p2.missing, 12);
      expect(p2.covered, isFalse);
      expect(h.sections[1].parts.single.passages.total, 3);
      expect(h.needed, 90);
      expect(h.eligible, 98);
      expect(h.disjointVariants, 0);
      expect(h.capped, isFalse);
    });

    test('unknown shortfall kinds are skipped; uncovered parts are listed', () {
      expect(h.shortfalls, hasLength(5));
      expect(h.uncoveredParts.map((u) => '${u.sectionId}/${u.part.partId}'), ['math/p2', 'reading/p1']);
    });

    test('cell shortfalls are grouped by topic, largest gap first', () {
      final topics = h.topicShortfalls;
      // math.arithmetic has needed == available: nothing missing, dropped.
      expect(topics.map((t) => t.topicId), ['math.algebra', 'math.geometry']);
      expect(topics.map((t) => t.missing), [6, 4]);
      expect(topics[1].cells.map((c) => c.difficulty), [1, 3]);
      final passages = h.passageShortfalls.single;
      expect(passages.layout, 'paired');
      expect(passages.missing, 1);
    });

    test('a capped answer and an empty report parse', () {
      final capped = PoolHealth.fromMap({'disjoint_variants': 100, 'disjoint_variants_capped': true});
      expect(capped.capped, isTrue);
      expect(capped.sections, isEmpty);
      expect(capped.topicShortfalls, isEmpty);
      expect(capped.minReviewStatus, isNull);
    });
  });

  group('payment_orders (§10.3)', () {
    final paid = PaymentOrder.fromMap('o1', {
      'uid': 'u1',
      'product_id': 'exam_single',
      'credits': 1,
      'amount_som': 100,
      'currency': 'KGS',
      'provider': 'sandbox',
      'status': 'paid',
      'provider_ref': 'sbx_1',
      'granted': true,
      'created_at': DateTime.utc(2026, 11, 5, 9),
      'paid_at': DateTime.utc(2026, 11, 5, 9, 2),
      'expires_at': DateTime.utc(2026, 11, 6, 9),
      'refund': null,
    });

    test('every field is read', () {
      expect(paid.uid, 'u1');
      expect(paid.productId, 'exam_single');
      expect(paid.amountSom, 100);
      expect(paid.provider, 'sandbox');
      expect(paid.providerRef, 'sbx_1');
      expect(paid.paidAt, DateTime.utc(2026, 11, 5, 9, 2));
      expect(paid.refund, isNull);
      expect(paid.canRefund, isTrue);
      expect(paid.refundPending, isFalse);
    });

    test('only a paid and granted order can be refunded (server rule)', () {
      PaymentOrder o(String status, {bool granted = true}) =>
          PaymentOrder.fromMap('x', {'status': status, 'granted': granted, 'amount_som': 100});
      for (final s in ['created', 'pending', 'failed', 'expired', 'refunded']) {
        expect(o(s).canRefund, isFalse, reason: s);
      }
      expect(o('paid', granted: false).canRefund, isFalse);
      expect(o('paid', granted: false).paidWithoutCredits, isFalse);
      expect(o('paid').canRefund, isTrue);
      expect(o('paid').paidWithoutCredits, isFalse);
      expect(kPaymentOrderStatuses.toSet(), {
        ...PaymentOrderStatuses.terminal,
        PaymentOrderStatuses.created,
        PaymentOrderStatuses.pending,
      });
    });

    test('refund, pending refund request and failure are read', () {
      final refunded = PaymentOrder.fromMap('r', {
        'status': 'refunded',
        'granted': true,
        'refund': {'at': DateTime.utc(2026, 11, 5), 'source': 'admin', 'credits_clawed_back': 1, 'debt_added': 1},
      });
      expect(refunded.refund!.source, 'admin');
      expect(refunded.refund!.creditsClawedBack, 1);
      expect(refunded.refund!.debtAdded, 1);
      final requested = PaymentOrder.fromMap('q', {
        'status': 'paid',
        'granted': true,
        'refund_requested': {'at': DateTime.utc(2026, 11, 5), 'by': 'admin1', 'reason': 'двойная оплата'},
      });
      expect(requested.refundPending, isTrue);
      expect(requested.canRefund, isFalse,
          reason: 'the server answers refund_in_progress to a second request');
      expect(requested.refundRequested!.reason, 'двойная оплата');
      final failed = PaymentOrder.fromMap('f', {'status': 'failed', 'failure': {'code': 'amount_mismatch'}});
      expect(failed.failureCode, 'amount_mismatch');
      expect(PaymentOrder.fromMap('e', null).status, 'created');
    });

    test('paid for a deleted account: refundable without a clawback', () {
      final o = PaymentOrder.fromMap('d', {
        'status': 'paid',
        'granted': false,
        'amount_som': 100,
        'failure': {'code': 'account_deleted'},
      });
      expect(o.paidWithoutCredits, isTrue);
      expect(o.canRefund, isTrue);
      final asked = PaymentOrder.fromMap('d2', {
        'status': 'paid',
        'granted': false,
        'failure': {'code': 'account_deleted'},
        'refund_requested': {'at': DateTime.utc(2026, 11, 5), 'by': 'admin1', 'reason': 'удалён'},
      });
      expect(asked.canRefund, isFalse);
      final refunded = PaymentOrder.fromMap('d3', {
        'status': 'refunded',
        'granted': false,
        'failure': {'code': 'account_deleted'},
      });
      expect(refunded.paidWithoutCredits, isFalse);
      expect(refunded.canRefund, isFalse);
    });

    test('the refund reason is trimmed and 3..200 long', () {
      expect(validRefundReason('  ab '), isNull);
      expect(validRefundReason(' abc '), 'abc');
      expect(validRefundReason('x' * 200), hasLength(200));
      expect(validRefundReason('x' * 201), isNull);
    });
  });

  group('revenue per Bishkek day', () {
    // 2026-11-06 16:00 in Bishkek.
    final now = DateTime.utc(2026, 11, 6, 10);

    PaymentOrder order(String id, String status, DateTime paidAt, int amount) =>
        PaymentOrder.fromMap(id, {'status': status, 'paid_at': paidAt, 'amount_som': amount, 'granted': true});

    test('day keys and window start follow UTC+6', () {
      expect(bishkekDayKey(DateTime.utc(2026, 11, 5, 17, 59)), '2026-11-05');
      expect(bishkekDayKey(DateTime.utc(2026, 11, 5, 18)), '2026-11-06');
      final keys = revenueDayKeys(now);
      expect(keys, hasLength(30));
      expect(keys.first, '2026-11-06');
      expect(keys.last, '2026-10-08');
      expect(revenueWindowStart(now), DateTime.utc(2026, 10, 7, 18));
      expect(revenueDayKeys(DateTime.utc(2026, 3, 1, 3), days: 3), ['2026-03-01', '2026-02-28', '2026-02-27']);
    });

    test('paid orders are summed per day; refunded ones are reported apart', () {
      final s = RevenueSummary.compute([
        order('a', 'paid', DateTime.utc(2026, 11, 5, 18, 30), 100), // Bishkek 2026-11-06 00:30
        order('b', 'paid', DateTime.utc(2026, 11, 6, 9), 450),
        order('c', 'paid', DateTime.utc(2026, 11, 5, 17), 100), // 2026-11-05 23:00
        order('d', 'refunded', DateTime.utc(2026, 11, 4, 8), 100),
        order('e', 'paid', DateTime.utc(2026, 10, 7, 17, 59), 800), // before the window
        PaymentOrder.fromMap('f', {'status': 'pending', 'amount_som': 100}),
      ], now: now);
      expect(s.days.first.day, '2026-11-06');
      expect(s.days.first.amountSom, 550);
      expect(s.days.first.orders, 2);
      expect(s.days[1].amountSom, 100);
      expect(s.days.where((d) => d.amountSom == 0), hasLength(28));
      expect(s.totalSom, 650);
      expect(s.totalOrders, 3);
      expect(s.refundedSom, 100);
      expect(s.refundedOrders, 1);
      expect(s.maxDaySom, 550);
      expect(s.truncated, isFalse);
    });
  });

  group('web_products (§10.3)', () {
    test('defaults: the base price is 100 som, packs are off', () {
      expect(kBasePriceSom, 100);
      expect(kDefaultWebProducts['exam_single'], const WebProductConfig(credits: 1, amountSom: 100, enabled: true));
      expect(kDefaultWebProducts['exam_pack_5']!.enabled, isFalse);
      expect(kDefaultWebProducts['exam_pack_10']!.enabled, isFalse);
      expect(PricingConfig.defaults.webProducts, kDefaultWebProducts);
      expect(PricingConfig.defaults.webProductsExist, isFalse);
      expect(PricingConfig.fromMap({'products': {'exam_single': 1}}).webProductsExist, isFalse);
    });

    test('stored products are parsed like the server (invalid entries dropped)', () {
      final p = PricingConfig.fromMap({
        'web_products': {
          'exam_single': {'credits': 1, 'amount_som': 100, 'enabled': true},
          'exam_pack_5': {'credits': 5, 'amountSom': 450, 'enabled': false},
          'bad_credits': {'credits': 0, 'amount_som': 100, 'enabled': true},
          'bad_amount': {'credits': 1, 'amount_som': 99.5, 'enabled': true},
          'bad_enabled': {'credits': 1, 'amount_som': 100, 'enabled': 'yes'},
          'Bad-Id': {'credits': 1, 'amount_som': 100, 'enabled': true},
        },
      });
      expect(p.webProductsExist, isTrue);
      expect(p.webProducts.keys, ['exam_single', 'exam_pack_5']);
      expect(p.webProducts['exam_pack_5']!.amountSom, 450);
    });

    test('validation mirrors adminUpdatePricing', () {
      expect(validateWebProducts(kDefaultWebProducts), isEmpty);
      expect(validateWebProducts({'exam_pack_5': const WebProductConfig(credits: 5, amountSom: 450, enabled: true)}),
          contains(WebPricingIssue.baseMissing));
      expect(validateWebProducts({
        'exam_single': const WebProductConfig(credits: 2, amountSom: 100, enabled: true),
      }), contains(WebPricingIssue.baseCredits));
      expect(validateWebProducts({
        ...kDefaultWebProducts,
        'exam_pack_5': const WebProductConfig(credits: 51, amountSom: 0, enabled: true),
      }), containsAll([WebPricingIssue.creditsRange, WebPricingIssue.amountRange]));
      expect(validateWebProducts({
        ...kDefaultWebProducts,
        'exam_pack_10': const WebProductConfig(credits: 10, amountSom: 100001, enabled: false),
      }), [WebPricingIssue.amountRange]);
    });

    test('a base price change needs a typed confirmation and confirmBasePriceChange', () {
      final changed = {...kDefaultWebProducts, 'exam_single': const WebProductConfig(credits: 1, amountSom: 150, enabled: true)};
      expect(basePriceChanged(kDefaultWebProducts), isFalse);
      expect(basePriceChanged(changed), isTrue);
      expect(basePriceConfirmationMatches('150', 150), isTrue);
      expect(basePriceConfirmationMatches(' 150 сом ', 150), isTrue);
      expect(basePriceConfirmationMatches('15', 150), isFalse);
      expect(basePriceConfirmationMatches('1500', 150), isFalse);
      expect(basePriceConfirmationMatches('', 150), isFalse);
      expect(webPricingPayload(kDefaultWebProducts), {
        'webProducts': {
          'exam_single': {'credits': 1, 'amount_som': 100, 'enabled': true},
          'exam_pack_5': {'credits': 5, 'amount_som': 450, 'enabled': false},
          'exam_pack_10': {'credits': 10, 'amount_som': 800, 'enabled': false},
        },
      });
      expect(webPricingPayload(changed)['confirmBasePriceChange'], isTrue);
    });

    test('display order: base product first, then by credits', () {
      expect(orderedWebProductIds(['exam_pack_10', 'promo_x', 'exam_pack_5', 'exam_single'], {
        ...kDefaultWebProducts,
        'promo_x': const WebProductConfig(credits: 3, amountSom: 270, enabled: false),
      }), ['exam_single', 'promo_x', 'exam_pack_5', 'exam_pack_10']);
      expect(sameWebProducts(kDefaultWebProducts, {...kDefaultWebProducts}), isTrue);
      expect(sameWebProducts(kDefaultWebProducts, {
        ...kDefaultWebProducts,
        'exam_pack_5': const WebProductConfig(credits: 5, amountSom: 450, enabled: true),
      }), isFalse);
    });
  });

  group('roles and navigation (§2, §10)', () {
    test('the pool page follows adminExamPoolHealth (edit_questions)', () {
      expect(RoutePaths.adminExamPool, '/admin/exam-pool');
      expect(AdminSection.examPool.path, RoutePaths.adminExamPool);
      expect(AdminSection.forPath('/admin/exam-pool'), AdminSection.examPool);
      expect(_paths(adminRoutes), contains('/admin/exam-pool'));
      final visible = {for (final r in AdminRole.values) if (AdminSection.examPool.visibleTo(r)) r};
      expect(visible, {AdminRole.superAdmin, AdminRole.contentManager, AdminRole.methodologist});
    });

    test('pool settings, refunds and pricing are super_admin only; support reads payments', () {
      for (final r in AdminRole.values) {
        final sa = r == AdminRole.superAdmin;
        expect(r.canManageExamPool, sa, reason: r.wire);
        expect(r.canRefundOrders, sa, reason: r.wire);
        expect(AdminSection.pricing.visibleTo(r), sa, reason: r.wire);
        expect(AdminSection.payments.visibleTo(r), sa || r == AdminRole.support, reason: r.wire);
      }
    });
  });

  group('per-attempt fresh variants in the CMS (§10.1)', () {
    test('the variants list asks only for library statuses by default', () {
      expect(variantListStatuses(null), ['draft', 'in_review', 'published', 'archived']);
      expect(variantListStatuses(null), isNot(contains(VariantDoc.generatedStatus)));
      expect(variantListStatuses('published'), ['published']);
      expect(VariantDoc.statuses, isNot(contains('generated')),
          reason: 'the status filter does not offer it either');
    });

    test('a generated variant is recognised and labelled', () {
      final v = VariantDoc.fromMap('fresh_att1', {
        'blueprint_id': 'ort_main_2026',
        'status': 'generated',
        'source': 'fresh',
        'generated_for': 'u1',
      });
      expect(v.isGenerated, isTrue);
      expect(v.isPublished, isFalse);
      expect(variantStatusLabel(l, v.status), l.adminVariantGenerated);
      expect(variantStatusTone(v.status), AdminTone.neutral);
    });
  });

  group('callables (§10)', () {
    test('adminExamPoolHealth: payload, 150 s timeout, parsed report', () async {
      final fns = _FakeFunctions()..response = healthResponse();
      final h = await AdminFunctions(fns).examPoolHealth('ort_main_2026', 'ky');
      final call = fns.calls.single;
      expect(call.name, BackendFunctions.adminExamPoolHealth);
      expect(call.data, {'blueprintId': 'ort_main_2026', 'language': 'ky'});
      expect(call.timeout, const Duration(seconds: 150));
      expect(h.sections, hasLength(2));
    });

    test('adminUpdateExamPool sends only the given fields and refuses an empty update', () async {
      final fns = _FakeFunctions()..response = {'ok': true};
      final api = AdminFunctions(fns);
      await api.updateExamPool({'minReviewStatus': 'ai_verified'});
      expect(fns.calls.single.name, BackendFunctions.adminUpdateExamPool);
      expect(fns.calls.single.data, {'minReviewStatus': 'ai_verified'});
      expect(() => api.updateExamPool(const {}), throwsArgumentError);
      expect(fns.calls, hasLength(1));
    });

    test('adminRefundOrder returns status and clawed back credits', () async {
      final fns = _FakeFunctions()..response = {'status': 'refunded', 'creditsClawedBack': 5};
      final r = await AdminFunctions(fns).refundOrder('o1', 'двойная оплата');
      expect(fns.calls.single.name, BackendFunctions.adminRefundOrder);
      expect(fns.calls.single.data, {'orderId': 'o1', 'reason': 'двойная оплата'});
      expect(fns.calls.single.timeout, AdminFunctions.refundOrderTimeout);
      expect(AdminFunctions.refundOrderTimeout, greaterThanOrEqualTo(const Duration(seconds: 75)),
          reason: 'the function waits for the provider before it answers');
      expect(r.refunded, isTrue);
      expect(r.creditsClawedBack, 5);
      fns.response = {'status': 'pending', 'creditsClawedBack': 0};
      expect((await AdminFunctions(fns).refundOrder('o1', 'abc')).refunded, isFalse);
    });

    test('adminUpdatePricing({webProducts}) leaves Play products alone', () async {
      final fns = _FakeFunctions()..response = {'ok': true};
      await AdminFunctions(fns).updateWebPricing(kDefaultWebProducts);
      final data = fns.calls.single.data as Map;
      expect(fns.calls.single.name, BackendFunctions.adminUpdatePricing);
      expect(data.keys, ['webProducts']);
    });
  });

  group('error messages (§10 reasons)', () {
    FirebaseFunctionsException err(String code, Map<String, Object?> details) =>
        FirebaseFunctionsException(code: code, message: 'm', details: details);

    test('refund, provider, pool and pricing reasons get dedicated texts', () {
      expect(adminErrorMessage(l, err('not-found', {'reason': 'ORDER_NOT_FOUND'}), appCheckAvailable: true),
          l.adminOrderErrNotFound);
      // This order's provider is not connected (others may be): refund it there.
      expect(
          adminErrorMessage(l, err('failed-precondition', {'reason': 'PAYMENTS_DISABLED', 'why': 'provider_unavailable'}),
              appCheckAvailable: true),
          l.adminOrderErrProviderUnavailable);
      expect(l.adminOrderErrProviderUnavailable, contains('напрямую у этого провайдера'));
      expect(
          adminErrorMessage(l, err('failed-precondition', {'reason': 'PAYMENTS_DISABLED'}), appCheckAvailable: true),
          l.adminOrderErrProvider);
      expect(
          adminErrorMessage(l, err('failed-precondition', {'reason': 'VALIDATION_FAILED', 'why': 'not_refundable', 'status': 'refunded'}),
              appCheckAvailable: true),
          l.adminOrderErrNotRefundable);
      expect(
          adminErrorMessage(l, err('failed-precondition', {'reason': 'VALIDATION_FAILED', 'why': 'refund_in_progress', 'status': 'paid'}),
              appCheckAvailable: true),
          l.adminOrderErrRefundInProgress);
      expect(
          adminErrorMessage(l, err('invalid-argument', {'reason': 'VALIDATION_FAILED', 'why': 'base_price_change_unconfirmed'}),
              appCheckAvailable: true),
          l.adminWebPricingErrBase);
      expect(
          adminErrorMessage(l, err('failed-precondition', {'reason': 'VARIANT_NOT_AVAILABLE', 'why': 'matrix_missing'}),
              appCheckAvailable: true),
          l.adminPoolErrMatrix);
      expect(
          adminErrorMessage(l, err('invalid-argument', {'reason': 'VALIDATION_FAILED', 'field': 'language'}),
              appCheckAvailable: true),
          l.adminPoolErrLanguage);
    });

    test('a refund that timed out has an unknown outcome', () {
      final timeout = FirebaseFunctionsException(code: 'deadline-exceeded', message: 'm');
      expect(isRefundOutcomeUnknown(timeout), isTrue);
      expect(refundOrderErrorMessage(l, timeout), l.adminOrderRefundUnknown);
      expect(l.adminOrderRefundUnknown, contains('Проверьте заказ, прежде чем повторять'));
      final denied = err('failed-precondition', {'reason': 'VALIDATION_FAILED', 'why': 'refund_in_progress'});
      expect(isRefundOutcomeUnknown(denied), isFalse);
      expect(refundOrderErrorMessage(l, denied), l.adminOrderErrRefundInProgress);
      expect(isRefundOutcomeUnknown(FirebaseFunctionsException(code: 'unavailable', message: 'm')), isFalse);
    });

    test('access denied: rules, role refusals, but never a banned account', () {
      expect(isAdminAccessDenied(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')), isTrue);
      expect(isAdminAccessDenied(err('permission-denied', {'reason': 'FORBIDDEN_ROLE'})), isTrue);
      expect(isAdminAccessDenied(FirebaseFunctionsException(code: 'permission-denied', message: 'm')), isTrue);
      expect(isAdminAccessDenied(err('permission-denied', {'reason': 'USER_BANNED'})), isFalse);
      expect(isAdminAccessDenied(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), isFalse);
      expect(isAdminAccessDenied(StateError('x')), isFalse);
    });
  });
}
