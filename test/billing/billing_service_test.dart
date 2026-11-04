import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:knowledge_flow/features/billing/application/billing_service.dart';
import 'package:knowledge_flow/features/billing/data/purchase_verifier.dart';
import 'package:knowledge_flow/features/billing/domain/obfuscated_account_id.dart';

import 'billing_fakes.dart';

void main() {
  late FakeStore store;
  late FakeVerifier verifier;
  late BillingService service;
  late List<BillingNotice> notices;
  String? uid;

  BillingService make({Stream<String?>? uidChanges}) {
    final s = BillingService(
      store: store,
      verifier: verifier,
      currentUid: () => uid,
      uidChanges: uidChanges,
    );
    s.notices.listen(notices.add);
    return s;
  }

  setUp(() {
    uid = 'user-1';
    store = FakeStore();
    verifier = FakeVerifier();
    notices = [];
    service = make();
  });

  tearDown(() async {
    service.dispose();
    await store.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('purchase update state machine', () {
    test('purchased → server granted → completePurchase, flow granted', () async {
      await service.loadCatalog(); // caches the Play price for priceDisplay
      final p = purchase(productId: 'exam_pack_5', token: 'tok-A', orderId: 'GPA.42');
      await service.handlePurchaseUpdates([p]);

      expect(verifier.calls, hasLength(1));
      final req = verifier.calls.single;
      expect(req.productId, 'exam_pack_5');
      expect(req.purchaseToken, 'tok-A');
      expect(req.orderId, 'GPA.42');
      expect(req.priceDisplay, 'US\$ 4.49');
      expect(store.completed, [p]);
      expect(service.flow.value.phase, PurchasePhase.granted);
      expect(notices.map((n) => n.kind), contains(BillingNoticeKind.granted));
    });

    test('pending payment is never verified or completed', () async {
      await service.handlePurchaseUpdates([purchase(status: PurchaseStatus.pending)]);
      expect(verifier.calls, isEmpty);
      expect(store.completed, isEmpty);
      expect(service.flow.value.phase, PurchasePhase.pendingPayment);
    });

    test('server says pending → not completed, shown as pending', () async {
      verifier.script
        ..clear()
        ..add(const VerifyPurchaseResult(VerifyStatus.pending));
      await service.handlePurchaseUpdates([purchase()]);
      expect(store.completed, isEmpty);
      expect(service.flow.value.phase, PurchasePhase.pendingPayment);
    });

    test('PURCHASE_PENDING error → pending, not completed', () async {
      verifier.script
        ..clear()
        ..add(const PurchaseVerificationException(VerifyFailureKind.pending));
      await service.handlePurchaseUpdates([purchase()]);
      expect(store.completed, isEmpty);
      expect(service.flow.value.phase, PurchasePhase.pendingPayment);
    });

    test('invalid purchase is not completed (Play auto-refunds it)', () async {
      // Foreground: the user is buying this product.
      store.launchResult = true;
      final pd = store.products.firstWhere((p) => p.id == 'exam_single');
      await service.buy(pd);
      verifier.script
        ..clear()
        ..add(const VerifyPurchaseResult(VerifyStatus.invalid));
      await service.handlePurchaseUpdates([purchase()]);
      expect(store.completed, isEmpty);
      expect(service.flow.value.phase, PurchasePhase.failed);
      expect(service.flow.value.issue, BillingIssue.invalid);
    });

    test('account mismatch is not completed and not retried as success', () async {
      await service.buy(store.products.firstWhere((p) => p.id == 'exam_single'));
      verifier.script
        ..clear()
        ..add(FirebaseFunctionsException(
            code: 'permission-denied', message: 'x', details: {'reason': 'PURCHASE_ACCOUNT_MISMATCH'}));
      await service.handlePurchaseUpdates([purchase()]);
      expect(store.completed, isEmpty);
      expect(service.flow.value.issue, BillingIssue.accountMismatch);
    });

    test('network failure defers; a later restore re-sends and completes', () async {
      await service.buy(store.products.firstWhere((p) => p.id == 'exam_single'));
      final p = purchase(token: 'tok-net');
      verifier.script
        ..clear()
        ..addAll([
          FirebaseFunctionsException(code: 'unavailable', message: 'offline'),
          const VerifyPurchaseResult(VerifyStatus.granted, credits: 1),
        ]);
      await service.handlePurchaseUpdates([p]);
      expect(store.completed, isEmpty);
      expect(service.flow.value.issue, BillingIssue.verificationDeferred);

      store.owned = [p];
      await service.start();
      await service.restore();
      await settle();
      expect(verifier.calls, hasLength(2));
      expect(store.completed, hasLength(1));
      expect(service.flow.value.phase, PurchasePhase.granted);
    });

    test('already_processed completes; completePurchase errors are ignored', () async {
      verifier.script
        ..clear()
        ..add(const VerifyPurchaseResult(VerifyStatus.alreadyProcessed));
      store.throwOnComplete = StateError('item not owned (server consumed)');
      await service.handlePurchaseUpdates([purchase()]);
      expect(store.completed, hasLength(1));
      expect(service.flow.value.phase, PurchasePhase.granted);
    });

    test('acknowledged purchase (pendingCompletePurchase=false) is not completed again', () async {
      await service.handlePurchaseUpdates([purchase(pendingComplete: false)]);
      expect(verifier.calls, hasLength(1));
      expect(store.completed, isEmpty);
    });

    test('store error during a foreground purchase → failed, never completed', () async {
      await service.buy(store.products.firstWhere((p) => p.id == 'exam_single'));
      await service.handlePurchaseUpdates([
        purchase(
          productId: '',
          token: '',
          status: PurchaseStatus.error,
          pendingComplete: true,
          error: IAPError(source: 'google_play', code: 'purchase_error', message: 'BillingResponse.error'),
        ),
      ]);
      expect(store.completed, isEmpty);
      expect(verifier.calls, isEmpty);
      expect(service.flow.value.issue, BillingIssue.storeError);
    });

    test('itemAlreadyOwned triggers a re-send of unfinished purchases', () async {
      await service.buy(store.products.firstWhere((p) => p.id == 'exam_single'));
      await settle();
      final before = store.restoreCalls;
      await service.handlePurchaseUpdates([
        purchase(
          productId: '',
          token: '',
          status: PurchaseStatus.error,
          error: IAPError(source: 'google_play', code: 'purchase_error', message: 'BillingResponse.itemAlreadyOwned'),
        ),
      ]);
      await settle();
      expect(service.flow.value.issue, BillingIssue.alreadyOwned);
      expect(store.restoreCalls, before + 1);
    });

    test('canceled by the user → canceled state', () async {
      await service.buy(store.products.firstWhere((p) => p.id == 'exam_pack_10'));
      await service.handlePurchaseUpdates(
          [purchase(productId: 'exam_pack_10', status: PurchaseStatus.canceled)]);
      expect(service.flow.value.phase, PurchasePhase.canceled);
      expect(store.completed, isEmpty);
    });

    test('unknown product ids are ignored', () async {
      await service.handlePurchaseUpdates([purchase(productId: 'premium_forever')]);
      expect(verifier.calls, isEmpty);
      expect(store.completed, isEmpty);
    });

    test('the same token arriving twice concurrently is verified once', () async {
      verifier.gate = Completer<void>();
      final a = service.handlePurchaseUpdates([purchase(token: 'dup')]);
      final b = service.handlePurchaseUpdates([purchase(token: 'dup')]);
      await settle();
      verifier.gate!.complete();
      await Future.wait([a, b]);
      expect(verifier.calls, hasLength(1));
    });

    test('purchase seen while signed out is not sent; re-sent after sign-in', () async {
      service.dispose();
      uid = null;
      final uids = StreamController<String?>.broadcast();
      service = make(uidChanges: uids.stream);
      await service.start();
      final p = purchase(token: 'later');
      await service.handlePurchaseUpdates([p]);
      expect(verifier.calls, isEmpty);

      store.owned = [p];
      uid = 'user-1';
      uids.add('user-1');
      await settle();
      await settle();
      expect(verifier.calls, hasLength(1));
      expect(store.completed, hasLength(1));
      await uids.close();
    });
  });

  group('start-up and notices', () {
    test('start re-sends unfinished purchases once per signed-in uid', () async {
      service.dispose();
      final uids = StreamController<String?>.broadcast();
      service = make(uidChanges: uids.stream);
      await service.start();
      uids.add('user-1');
      await settle();
      uids.add('user-1');
      await settle();
      expect(store.restoreCalls, 1);
      uids.add(null);
      uids.add('user-2');
      await settle();
      expect(store.restoreCalls, 2);
      await uids.close();
    });

    test('start is idempotent', () async {
      await service.start();
      await service.start();
      await settle();
      expect(store.restoreCalls, 1);
    });

    test('background grant is announced; background already_processed is silent', () async {
      await service.handlePurchaseUpdates([purchase(token: 'bg1', status: PurchaseStatus.restored)]);
      expect(notices.where((n) => n.kind == BillingNoticeKind.granted), hasLength(1));
      expect(notices.single.userInitiated, isFalse);

      notices.clear();
      verifier.script
        ..clear()
        ..add(const VerifyPurchaseResult(VerifyStatus.alreadyProcessed));
      await service.handlePurchaseUpdates([purchase(token: 'bg2', status: PurchaseStatus.restored)]);
      expect(notices, isEmpty);
    });

    test('background failures produce no user-facing failure notice', () async {
      verifier.script
        ..clear()
        ..add(FirebaseFunctionsException(code: 'unavailable', message: 'offline'));
      await service.handlePurchaseUpdates([purchase(status: PurchaseStatus.restored)]);
      expect(notices.where((n) => n.kind == BillingNoticeKind.failed), isEmpty);
    });
  });

  group('buy', () {
    test('passes sha256(uid) as applicationUserName', () async {
      final pd = store.products.firstWhere((p) => p.id == 'exam_pack_5');
      await service.buy(pd);
      expect(store.buys, hasLength(1));
      expect(store.buys.single.productDetails.id, 'exam_pack_5');
      expect(store.buys.single.applicationUserName, obfuscatedAccountId('user-1'));
      expect(store.buys.single.applicationUserName, isNot(contains('user-1')));
      expect(service.flow.value.phase, PurchasePhase.launching);
    });

    test('signed out → no purchase is launched', () async {
      uid = null;
      await service.buy(store.products.first);
      expect(store.buys, isEmpty);
      expect(service.flow.value.issue, BillingIssue.notSignedIn);
    });

    test('store unavailable → no purchase is launched', () async {
      store.available = false;
      await service.buy(store.products.first);
      expect(store.buys, isEmpty);
      expect(service.flow.value.issue, BillingIssue.storeUnavailable);
    });

    test('launch failure is reported', () async {
      store.launchResult = false;
      await service.buy(store.products.first);
      expect(service.flow.value.issue, BillingIssue.launchFailed);
    });

    test('a second buy while one is running is ignored', () async {
      await service.buy(store.products.first);
      await service.buy(store.products.last);
      expect(store.buys, hasLength(1));
    });
  });

  group('catalog', () {
    test('unavailable store → StoreCatalog.unavailable', () async {
      store.available = false;
      final c = await service.loadCatalog();
      expect(c.available, isFalse);
    });

    test('Play error with no products throws', () async {
      store.queryError = IAPError(source: 'google_play', code: 'x', message: 'boom');
      await expectLater(service.loadCatalog(), throwsA(isA<BillingCatalogException>()));
    });

    test('returns only known products', () async {
      store.products = [
        ...FakeStore.defaultProducts(),
        ProductDetails(id: 'other', title: '', description: '', price: '1', rawPrice: 1, currencyCode: 'USD'),
      ];
      final c = await service.loadCatalog();
      expect(c.products.map((p) => p.id).toSet(), {'exam_single', 'exam_pack_5', 'exam_pack_10'});
    });
  });

  group('VerifyPurchaseResult / errors', () {
    test('parses statuses', () {
      expect(VerifyPurchaseResult.fromResponse({'status': 'granted', 'credits': 5}).status, VerifyStatus.granted);
      expect(VerifyPurchaseResult.fromResponse({'status': 'already_processed'}).isSettled, isTrue);
      expect(VerifyPurchaseResult.fromResponse({'status': 'pending'}).isSettled, isFalse);
      expect(VerifyPurchaseResult.fromResponse({'status': 'invalid'}).isSettled, isFalse);
    });

    test('unknown response is never treated as a grant', () {
      expect(() => VerifyPurchaseResult.fromResponse({'status': 'ok'}), throwsFormatException);
      expect(() => VerifyPurchaseResult.fromResponse('granted'), throwsFormatException);
      expect(() => VerifyPurchaseResult.fromResponse(null), throwsFormatException);
    });

    test('maps backend reasons', () {
      PurchaseVerificationException m(String reason) => PurchaseVerificationException.from(
          FirebaseFunctionsException(code: 'failed-precondition', message: '', details: {'reason': reason}));
      expect(m('PURCHASE_INVALID').kind, VerifyFailureKind.invalid);
      expect(m('PURCHASE_ACCOUNT_MISMATCH').kind, VerifyFailureKind.accountMismatch);
      expect(m('PURCHASE_PENDING').kind, VerifyFailureKind.pending);
      expect(
        PurchaseVerificationException.from(FirebaseFunctionsException(code: 'internal', message: '')).kind,
        VerifyFailureKind.retryable,
      );
      expect(PurchaseVerificationException.from(Exception('socket')).kind, VerifyFailureKind.retryable);
    });

    test('request payload omits empty optional fields', () {
      expect(
        const VerifyPurchaseRequest(productId: 'exam_single', purchaseToken: 't').toPayload(),
        {'productId': 'exam_single', 'purchaseToken': 't'},
      );
      expect(
        const VerifyPurchaseRequest(productId: 'exam_single', purchaseToken: 't', orderId: 'GPA', priceDisplay: '\$1')
            .toPayload(),
        {'productId': 'exam_single', 'purchaseToken': 't', 'orderId': 'GPA', 'priceDisplay': '\$1'},
      );
    });
  });
}
