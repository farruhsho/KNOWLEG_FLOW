import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/billing/application/billing_providers.dart';
import 'package:knowledge_flow/features/billing/application/paged_list_controller.dart';
import 'package:knowledge_flow/features/billing/domain/billing_mode.dart';
import 'package:knowledge_flow/features/billing/domain/billing_records.dart';
import 'package:knowledge_flow/features/billing/domain/entitlements.dart';
import 'package:knowledge_flow/features/billing/domain/obfuscated_account_id.dart';
import 'package:knowledge_flow/features/billing/domain/pricing_config.dart';

void main() {
  group('obfuscatedAccountId', () {
    test('is lowercase hex SHA-256 (NIST vector "abc")', () {
      expect(
        obfuscatedAccountId('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('is 64 chars (Play limit), deterministic and per-user', () {
      const uid = 'Xh3kLq9mZ0aBcDeFgHiJkLmNoPq2';
      final a = obfuscatedAccountId(uid);
      expect(a, hasLength(64));
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(obfuscatedAccountId(uid), a);
      expect(obfuscatedAccountId('${uid}x'), isNot(a));
      expect(a.contains(uid), isFalse);
    });

    test('rejects an empty uid', () {
      expect(() => obfuscatedAccountId(''), throwsArgumentError);
    });
  });

  group('BillingMode', () {
    test('parses known values and defaults to play', () {
      expect(BillingMode.parse('external'), BillingMode.external);
      expect(BillingMode.parse(' EXTERNAL '), BillingMode.external);
      expect(BillingMode.parse('play'), BillingMode.play);
      expect(BillingMode.parse('nonsense'), BillingMode.play);
      expect(BillingMode.parse(null), BillingMode.play);
      expect(BillingMode.external.sellsInApp, isFalse);
      expect(BillingMode.play.sellsInApp, isTrue);
    });

    test('canSellProvider is false in external builds', () {
      final ext = ProviderContainer(
          overrides: [billingModeProvider.overrideWithValue(BillingMode.external)]);
      final play = ProviderContainer(
          overrides: [billingModeProvider.overrideWithValue(BillingMode.play)]);
      addTearDown(ext.dispose);
      addTearDown(play.dispose);
      expect(ext.read(canSellProvider), isFalse);
      expect(play.read(canSellProvider), isTrue);
    });
  });

  group('Entitlements.fromMap', () {
    test('missing document → free exam available, no credits', () {
      final e = Entitlements.fromMap(null);
      expect(e, Entitlements.initial);
      expect(e.hasFreeExam, isTrue);
      expect(e.canStartExam, isTrue);
    });

    test('canonical snake_case document', () {
      final at = DateTime.utc(2026, 11, 2, 8);
      final e = Entitlements.fromMap({
        'free_exam_used': true,
        'free_exam_used_at': Timestamp.fromDate(at),
        'free_exam_attempt_id': 'att_1',
        'credits': 4,
        'lifetime_credits_purchased': 10,
        'updated_at': Timestamp.fromDate(at),
      });
      expect(e.freeExamUsed, isTrue);
      expect(e.hasFreeExam, isFalse);
      expect(e.credits, 4);
      expect(e.lifetimeCreditsPurchased, 10);
      expect(e.freeExamUsedAt, at.toLocal());
      expect(e.canStartExam, isTrue);
    });

    test('used free exam and no credits → cannot start', () {
      final e = Entitlements.fromMap({'free_exam_used': true, 'credits': 0});
      expect(e.canStartExam, isFalse);
    });

    test('tolerates strings, doubles, camelCase and negative values', () {
      final e = Entitlements.fromMap({
        'freeExamUsed': 'true',
        'credits': '3',
        'lifetimeCreditsPurchased': 5.0,
      });
      expect(e.freeExamUsed, isTrue);
      expect(e.credits, 3);
      expect(e.lifetimeCreditsPurchased, 5);

      expect(Entitlements.fromMap({'credits': -2}).credits, 0);
      expect(Entitlements.fromMap({'credits': 'abc'}).credits, 0);
      expect(Entitlements.fromMap({'free_exam_used': 1}).freeExamUsed, isTrue);
    });
  });

  group('free exams per user (ENT-FREE-01 / D14)', () {
    test('used count falls back to the free_exam_used flag', () {
      expect(Entitlements.fromMap({'free_exam_used': true}).freeExamsUsedCount, 1);
      expect(Entitlements.fromMap({'free_exam_used': false}).freeExamsUsedCount, 0);
      expect(Entitlements.fromMap({}).freeExamsUsedCount, 0);
      // The server takes max(count, flag ? 1 : 0).
      expect(Entitlements.fromMap({'free_exam_used': true, 'free_exams_used_count': 0}).freeExamsUsedCount, 1);
      expect(Entitlements.fromMap({'free_exams_used_count': 2}).freeExamUsed, isTrue);
      const legacy = Entitlements(freeExamUsed: true, credits: 0, lifetimeCreditsPurchased: 0);
      expect(legacy.freeExamsUsedCount, 1);
      expect(legacy.hasFreeExam, isFalse);
    });

    test('allowance above one: a second free exam is still available', () {
      final e = Entitlements.fromMap(
        {'free_exam_used': true, 'free_exams_used_count': 1, 'credits': 0},
        freeExamsAllowed: 2,
      );
      expect(e.freeExamsRemaining, 1);
      expect(e.hasFreeExam, isTrue);
      expect(e.canStartExam, isTrue);
      final used = Entitlements.fromMap({'free_exams_used_count': 2, 'credits': 0}, freeExamsAllowed: 2);
      expect(used.hasFreeExam, isFalse);
      expect(used.canStartExam, isFalse);
    });

    test('allowance zero: a new account has no free exam', () {
      final e = Entitlements.fromMap(null, freeExamsAllowed: 0);
      expect(e.hasFreeExam, isFalse);
      expect(e.canStartExam, isFalse);
      expect(e.freeExamsRemaining, 0);
      expect(Entitlements.fromMap({'credits': 1}, freeExamsAllowed: 0).canStartExam, isTrue);
    });

    test('withFreeExamsAllowed keeps the document and changes only the allowance', () {
      final e = Entitlements.fromMap({'free_exams_used_count': 1, 'credits': 2});
      final more = e.withFreeExamsAllowed(3);
      expect(more.credits, 2);
      expect(more.freeExamsUsedCount, 1);
      expect(more.freeExamsRemaining, 2);
      expect(identical(e.withFreeExamsAllowed(1), e), isTrue);
    });

    test('config/pricing.free_exams_per_user mirrors the server (int 0..5, default 1)', () {
      expect(PricingConfig.fromMap(null).freeExamsPerUser, 1);
      expect(PricingConfig.fromMap({}).freeExamsPerUser, 1);
      expect(PricingConfig.fromMap({'free_exams_per_user': 3}).freeExamsPerUser, 3);
      expect(PricingConfig.fromMap({'free_exams_per_user': 0}).freeExamsPerUser, 0);
      expect(PricingConfig.fromMap({'free_exams_per_user': 2.0}).freeExamsPerUser, 2);
      expect(PricingConfig.fromMap({'freeExamsPerUser': 4}).freeExamsPerUser, 4);
      expect(PricingConfig.fromMap({'free_exams_per_user': 6}).freeExamsPerUser, 1);
      expect(PricingConfig.fromMap({'free_exams_per_user': -1}).freeExamsPerUser, 1);
      expect(PricingConfig.fromMap({'free_exams_per_user': 1.5}).freeExamsPerUser, 1);
      expect(PricingConfig.fromMap({'free_exams_per_user': '2'}).freeExamsPerUser, 1);
      expect(PricingConfig.defaults.freeExamsPerUser, 1);
    });

    test('entitlementsProvider applies the configured allowance', () async {
      final c = ProviderContainer(overrides: [
        pricingConfigProvider.overrideWith(
            (ref) => Stream.value(const PricingConfig({}, freeExamsPerUser: 0))),
      ]);
      addTearDown(c.dispose);
      await c.read(pricingConfigProvider.future);
      // No Firebase app in unit tests: the provider falls back to the
      // signed-out value, still with the configured allowance.
      final e = await c.read(entitlementsProvider.future);
      expect(e.freeExamsAllowed, 0);
      expect(e.hasFreeExam, isFalse);
    });
  });

  group('PricingConfig', () {
    test('defaults map products to 1 / 5 / 10 credits', () {
      final p = PricingConfig.defaults;
      expect(p.creditsFor('exam_single'), 1);
      expect(p.creditsFor('exam_pack_5'), 5);
      expect(p.creditsFor('exam_pack_10'), 10);
      expect(p.labelFor('exam_single', 'ru'), isNull);
      expect(p.orderFor('exam_single') < p.orderFor('exam_pack_10'), isTrue);
    });

    test('accepts {id: credits}', () {
      final p = PricingConfig.fromMap({
        'products': {'exam_pack_5': 6},
      });
      expect(p.creditsFor('exam_pack_5'), 6);
      expect(p.creditsFor('exam_single'), 1);
    });

    test('accepts {id: {credits, label, order}}', () {
      final p = PricingConfig.fromMap({
        'products': {
          'exam_pack_10': {
            'credits': 10,
            'label': {'ru': 'Пакет 10', 'ky': '10 тест топтому'},
            'order': 0,
          },
        },
      });
      expect(p.labelFor('exam_pack_10', 'ky'), '10 тест топтому');
      expect(p.labelFor('exam_pack_10', 'en'), 'Пакет 10');
      expect(p.orderFor('exam_pack_10'), 0);
    });

    test('accepts a list and ignores malformed entries', () {
      final p = PricingConfig.fromMap({
        'products': [
          {'product_id': 'exam_single', 'credits': 1, 'label': 'Один тест'},
          {'product_id': 'exam_pack_5', 'credits': -1},
          'garbage',
          {'credits': 3},
        ],
      });
      expect(p.labelFor('exam_single', 'ru'), 'Один тест');
      expect(p.creditsFor('exam_pack_5'), 5);
    });

    test('null or wrong-typed document falls back to defaults', () {
      expect(PricingConfig.fromMap(null).creditsFor('exam_pack_10'), 10);
      expect(PricingConfig.fromMap({'products': 42}).creditsFor('exam_pack_10'), 10);
    });
  });

  group('billing records', () {
    test('PurchaseRecord parses state, credits and dates', () {
      final r = PurchaseRecord.fromMap('h1', {
        'uid': 'u',
        'product_id': 'exam_pack_5',
        'order_id': 'GPA.1',
        'state': 'refunded',
        'credits_granted': 5,
        'price_display': 'US\$ 4.49',
        'created_at': Timestamp.fromMillisecondsSinceEpoch(1762078200000),
        'refund': {'at': Timestamp.fromMillisecondsSinceEpoch(1762164600000), 'source': 'rtdn'},
      });
      expect(r.state, PurchaseRecordState.refunded);
      expect(r.creditsGranted, 5);
      expect(r.createdAt, DateTime.fromMillisecondsSinceEpoch(1762078200000));
      expect(r.refundedAt, isNotNull);
    });

    test('unknown state and missing fields are tolerated', () {
      final r = PurchaseRecord.fromMap('h2', {'state': 'weird'});
      expect(r.state, PurchaseRecordState.unknown);
      expect(r.productId, '');
      expect(r.createdAt, isNull);
      expect(PurchaseRecordState.parse('GRANTED'), PurchaseRecordState.granted);
    });

    test('LedgerEntry parses reasons and deltas', () {
      final e = LedgerEntry.fromMap('l1', {
        'delta': -1,
        'balance_after': 4,
        'reason': 'exam_start',
        'ref': 'att_9',
        'at': '2026-11-02T10:00:00Z',
      });
      expect(e.delta, -1);
      expect(e.balanceAfter, 4);
      expect(e.reason, LedgerReason.examStart);
      expect(e.at, DateTime.utc(2026, 11, 2, 10));
      expect(LedgerEntry.fromMap('l2', {'reason': 'mystery'}).reason, LedgerReason.other);
      expect(LedgerEntry.fromMap('l3', {}).balanceAfter, isNull);
    });
  });

  group('PagedListController', () {
    test('loads pages until hasMore is false', () async {
      final pages = {
        null: const PageChunk<int>([1, 2], nextCursor: 'c1', hasMore: true),
        'c1': const PageChunk<int>([3], nextCursor: 'c2', hasMore: false),
      };
      final c = PagedListController<int>((cursor) async => pages[cursor]!);
      await c.refresh();
      expect(c.items, [1, 2]);
      expect(c.hasMore, isTrue);
      await c.loadMore();
      expect(c.items, [1, 2, 3]);
      expect(c.hasMore, isFalse);
      await c.loadMore();
      expect(c.items, [1, 2, 3]);
      c.dispose();
    });

    test('keeps items and exposes the error when a page fails', () async {
      var fail = false;
      final c = PagedListController<int>((cursor) async {
        if (fail) throw Exception('offline');
        return const PageChunk<int>([1], nextCursor: 'c', hasMore: true);
      });
      await c.refresh();
      fail = true;
      await c.loadMore();
      expect(c.items, [1]);
      expect(c.error, isNotNull);
      fail = false;
      await c.loadMore();
      expect(c.items, [1, 1]);
      expect(c.error, isNull);
      c.dispose();
    });

    test('empty first page → isEmpty', () async {
      final c = PagedListController<int>((_) async => const PageChunk<int>([], hasMore: false));
      await c.refresh();
      expect(c.isEmpty, isTrue);
      c.dispose();
    });
  });
}
