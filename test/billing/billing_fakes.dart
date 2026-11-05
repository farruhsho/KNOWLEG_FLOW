import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:knowledge_flow/features/billing/data/purchase_verifier.dart';
import 'package:knowledge_flow/features/billing/data/store_gateway.dart';

/// In-memory Google Play stand-in.
class FakeStore implements StoreGateway {
  FakeStore({this.available = true, List<ProductDetails>? products, this.queryError})
      : products = products ?? defaultProducts();

  bool available;
  List<ProductDetails> products;
  IAPError? queryError;
  bool launchResult = true;
  Object? throwOnBuy;
  Object? throwOnComplete;

  final StreamController<List<PurchaseDetails>> _ctrl = StreamController.broadcast();
  final List<PurchaseParam> buys = [];
  final List<PurchaseDetails> completed = [];
  int restoreCalls = 0;

  /// What [restorePurchases] re-emits (like Play's owned, unconsumed items).
  List<PurchaseDetails> owned = [];

  static List<ProductDetails> defaultProducts() => [
        ProductDetails(
            id: 'exam_pack_10', title: '10', description: '', price: 'US\$ 7.99', rawPrice: 7.99, currencyCode: 'USD'),
        ProductDetails(
            id: 'exam_single', title: '1', description: '', price: 'US\$ 0.99', rawPrice: 0.99, currencyCode: 'USD'),
        ProductDetails(
            id: 'exam_pack_5', title: '5', description: '', price: 'US\$ 4.49', rawPrice: 4.49, currencyCode: 'USD'),
      ];

  void emit(List<PurchaseDetails> updates) => _ctrl.add(updates);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _ctrl.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async => ProductDetailsResponse(
        productDetails: queryError == null ? products.where((p) => ids.contains(p.id)).toList() : const [],
        notFoundIDs: const [],
        error: queryError,
      );

  @override
  Future<bool> buyConsumable(PurchaseParam param) async {
    buys.add(param);
    if (throwOnBuy != null) throw throwOnBuy!;
    return launchResult;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
    if (throwOnComplete != null) throw throwOnComplete!;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
    if (owned.isNotEmpty) {
      for (final p in owned) {
        p.status = PurchaseStatus.restored;
      }
      _ctrl.add(List.of(owned));
    }
  }

  Future<void> close() => _ctrl.close();
}

/// Scriptable server verifier.
class FakeVerifier implements PurchaseVerifier {
  final List<VerifyPurchaseRequest> calls = [];

  /// Returned / thrown in order; the last one repeats.
  final List<Object> script;
  Completer<void>? gate;

  FakeVerifier([List<Object>? script])
      : script = script ?? [const VerifyPurchaseResult(VerifyStatus.granted, credits: 1)];

  @override
  Future<VerifyPurchaseResult> verify(VerifyPurchaseRequest request) async {
    calls.add(request);
    if (gate != null) await gate!.future;
    final next = script.length > 1 ? script.removeAt(0) : script.first;
    if (next is VerifyPurchaseResult) return next;
    throw next;
  }
}

PurchaseDetails purchase({
  String productId = 'exam_single',
  String token = 'tok-1',
  String? orderId = 'GPA.1',
  PurchaseStatus status = PurchaseStatus.purchased,
  bool pendingComplete = true,
  IAPError? error,
}) {
  final p = PurchaseDetails(
    purchaseID: orderId,
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '{}',
      serverVerificationData: token,
      source: 'google_play',
    ),
    transactionDate: '1762078200000',
    status: status,
  );
  p.pendingCompletePurchase = pendingComplete;
  p.error = error;
  return p;
}
