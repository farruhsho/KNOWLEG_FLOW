import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// The slice of `InAppPurchase` the billing flow needs, behind an interface
/// so the purchase state machine can be tested with a fake store.
abstract interface class StoreGateway {
  Future<bool> isAvailable();

  /// Lifetime stream of purchase updates (never closes while the app runs).
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);

  /// Always a consumable purchase with `autoConsume: false`: the backend
  /// consumes after it has granted credits.
  Future<bool> buyConsumable(PurchaseParam param);

  Future<void> completePurchase(PurchaseDetails purchase);

  /// Re-emits owned (not yet consumed) purchases on [purchaseStream].
  Future<void> restorePurchases();
}

/// Google Play through `package:in_app_purchase`.
class InAppPurchaseGateway implements StoreGateway {
  InAppPurchaseGateway([InAppPurchase? iap]) : _iapOverride = iap;

  final InAppPurchase? _iapOverride;

  // Resolved lazily: touching InAppPurchase.instance registers the platform
  // implementation, which must not happen on unsupported platforms.
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) =>
      _iap.queryProductDetails(ids);

  @override
  Future<bool> buyConsumable(PurchaseParam param) =>
      _iap.buyConsumable(purchaseParam: param, autoConsume: false);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();
}

/// Used on web/desktop/iOS and in `BILLING_MODE=external` builds: the store is
/// simply unavailable and nothing is ever bought.
class UnsupportedStoreGateway implements StoreGateway {
  const UnsupportedStoreGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: const [], notFoundIDs: ids.toList());

  @override
  Future<bool> buyConsumable(PurchaseParam param) async => false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {}
}

/// Google Play Billing is only wired for Android builds.
bool get isPlayBillingPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
