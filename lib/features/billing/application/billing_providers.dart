import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_contract.dart';
import '../data/billing_history_repository.dart';
import '../data/purchase_verifier.dart';
import '../data/store_gateway.dart';
import '../domain/billing_mode.dart';
import '../domain/pricing_config.dart';
import 'billing_service.dart';

/// Build-time billing mode (`--dart-define=BILLING_MODE=play|external`).
final billingModeProvider = Provider<BillingMode>((ref) => BillingMode.current);

/// Whether this build may show purchase buttons, prices or "buy" wording.
/// False in `BILLING_MODE=external` (consumption-only Play build): every
/// screen must then drop its purchase call-to-action and must not route to
/// the store as a way to pay (ARCHITECTURE §5, Play payments policy).
final canSellProvider = Provider<bool>((ref) => ref.watch(billingModeProvider).sellsInApp);

/// Whether this platform can talk to Google Play Billing at all.
final playBillingPlatformProvider = Provider<bool>((ref) => isPlayBillingPlatform);

final storeGatewayProvider = Provider<StoreGateway>((ref) {
  final mode = ref.watch(billingModeProvider);
  if (!mode.sellsInApp || !ref.watch(playBillingPlatformProvider)) {
    return const UnsupportedStoreGateway();
  }
  return InAppPurchaseGateway();
});

final purchaseVerifierProvider =
    Provider<PurchaseVerifier>((ref) => const CallablePurchaseVerifier());

/// Uid of the signed-in user, read synchronously. Never throws, even when
/// Firebase failed to initialise.
final billingCurrentUidProvider = Provider<String? Function()>((ref) {
  return () {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  };
});

/// Uid changes (sign-in / sign-out). Never throws.
final billingUidChangesProvider = Provider<Stream<String?>>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges().map((u) => u?.uid);
  } catch (_) {
    return Stream<String?>.value(null);
  }
});

/// Reactive uid for widgets (null = signed out). Has its own auth
/// subscription so it always starts with the current user.
final billingUidProvider = StreamProvider<String?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges().map((u) => u?.uid);
  } catch (_) {
    return Stream<String?>.value(null);
  }
});

/// App-lifetime billing service. Started by the billing listener (and,
/// defensively, by the store page).
final billingServiceProvider = Provider<BillingService>((ref) {
  final service = BillingService(
    store: ref.watch(storeGatewayProvider),
    verifier: ref.watch(purchaseVerifierProvider),
    currentUid: ref.watch(billingCurrentUidProvider),
    uidChanges: ref.watch(billingUidChangesProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Products from Google Play. Re-queried on retry via `ref.invalidate`.
final storeCatalogProvider = FutureProvider.autoDispose<StoreCatalog>((ref) {
  return ref.watch(billingServiceProvider).loadCatalog();
});

/// Optional label/credit overrides from `config/pricing`. Falls back to the
/// built-in defaults when the document is missing, unreadable or offline.
final pricingConfigProvider = StreamProvider<PricingConfig>((ref) async* {
  yield PricingConfig.defaults;
  final FirebaseFirestore db;
  try {
    db = FirebaseFirestore.instance;
  } catch (_) {
    return;
  }
  try {
    await for (final snap
        in db.collection(Collections.config).doc('pricing').snapshots()) {
      yield PricingConfig.fromMap(snap.data());
    }
  } catch (_) {
    // Permission denied / offline: keep the defaults already emitted.
  }
});

final billingHistoryRepositoryProvider =
    Provider<BillingHistoryRepository>((ref) => BillingHistoryRepository());
