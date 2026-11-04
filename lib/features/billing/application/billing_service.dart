import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/backend/backend_contract.dart';
import '../data/purchase_verifier.dart';
import '../data/store_gateway.dart';
import '../domain/obfuscated_account_id.dart';

/// Where the purchase the user is looking at currently stands.
enum PurchasePhase {
  idle,

  /// Google Play's purchase sheet is being opened / is open.
  launching,

  /// The token is with our server (`billingVerifyPurchase`).
  verifying,

  /// Play reports the payment as pending (e.g. cash/bank payment not yet
  /// made). Nothing is granted until the server confirms.
  pendingPayment,
  granted,
  failed,
  canceled,

  /// The user asked to re-check unfinished purchases.
  restoring,
}

/// Why a purchase step did not succeed. Mapped to a friendly message in UI.
enum BillingIssue {
  notSignedIn,
  storeUnavailable,
  productUnavailable,
  launchFailed,
  alreadyOwned,
  storeError,

  /// The server could not be reached. The purchase stays unfinished on the
  /// device and is re-sent on the next start-up / restore.
  verificationDeferred,
  invalid,
  accountMismatch,
}

@immutable
class PurchaseFlowState {
  final PurchasePhase phase;
  final String? productId;
  final BillingIssue? issue;

  const PurchaseFlowState({this.phase = PurchasePhase.idle, this.productId, this.issue});

  bool get isBusy =>
      phase == PurchasePhase.launching ||
      phase == PurchasePhase.verifying ||
      phase == PurchasePhase.restoring;

  @override
  bool operator ==(Object other) =>
      other is PurchaseFlowState &&
      other.phase == phase &&
      other.productId == productId &&
      other.issue == issue;

  @override
  int get hashCode => Object.hash(phase, productId, issue);

  @override
  String toString() => 'PurchaseFlowState($phase, $productId, $issue)';
}

enum BillingNoticeKind { granted, pending, failed, canceled, restoreStarted, restoreFinished }

/// One-off event for transient UI (snackbars).
@immutable
class BillingNotice {
  final BillingNoticeKind kind;
  final String? productId;
  final BillingIssue? issue;

  /// True when the user is actively waiting for this result (they tapped buy
  /// or restore). Background re-sends at start-up are not user initiated.
  final bool userInitiated;

  const BillingNotice(this.kind, {this.productId, this.issue, this.userInitiated = true});

  @override
  String toString() => 'BillingNotice($kind, $productId, $issue, user: $userInitiated)';
}

/// Result of loading the products from Google Play.
@immutable
class StoreCatalog {
  final bool available;
  final List<ProductDetails> products;
  final List<String> notFoundIds;

  const StoreCatalog({required this.available, this.products = const [], this.notFoundIds = const []});

  const StoreCatalog.unavailable() : this(available: false);

  bool get isEmpty => products.isEmpty;
}

class BillingCatalogException implements Exception {
  final String message;
  const BillingCatalogException(this.message);
  @override
  String toString() => 'BillingCatalogException($message)';
}

/// Google Play purchase flow with server-side verification
/// (ARCHITECTURE §5). Invariants:
///
/// * The client never grants anything. Credits appear only when the backend
///   writes `entitlements/{uid}`; this class merely forwards tokens.
/// * A purchase is finished on the device (`completePurchase`) only after the
///   server answered `granted` or `already_processed`. Pending, invalid and
///   mismatched purchases are left unfinished, so Google refunds them
///   automatically if they are never verified.
/// * Unfinished purchases are re-sent on start-up and whenever a user signs
///   in; the backend is idempotent.
class BillingService {
  BillingService({
    required StoreGateway store,
    required PurchaseVerifier verifier,
    required String? Function() currentUid,
    Stream<String?>? uidChanges,
    Duration launchTimeout = const Duration(minutes: 2),
  })  : _store = store,
        _verifier = verifier,
        _currentUid = currentUid,
        _uidChanges = uidChanges,
        _launchTimeout = launchTimeout;

  final StoreGateway _store;
  final PurchaseVerifier _verifier;
  final String? Function() _currentUid;
  final Stream<String?>? _uidChanges;
  final Duration _launchTimeout;

  /// Current state of the foreground purchase, for the store page.
  final ValueNotifier<PurchaseFlowState> flow = ValueNotifier(const PurchaseFlowState());

  final StreamController<BillingNotice> _notices = StreamController.broadcast();
  Stream<BillingNotice> get notices => _notices.stream;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<String?>? _uidSub;
  Future<void> _queue = Future.value();
  Timer? _launchTimer;
  bool _started = false;
  bool _disposed = false;
  String? _lastUid;

  /// Product the user is buying right now (tags stream updates as foreground).
  String? _foregroundProductId;

  /// Set while a user-requested restore is running.
  bool _userRestore = false;

  final Set<String> _inFlightTokens = {};
  final Set<String> _settledTokens = {};
  final Map<String, ProductDetails> _productsById = {};

  bool get isStarted => _started;

  /// Subscribes to the purchase stream (once per app run) and re-sends
  /// unfinished purchases. Safe to call repeatedly.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _purchaseSub = _store.purchaseStream.listen(
      (updates) => _queue = _queue
          .then((_) => handlePurchaseUpdates(updates))
          .catchError((Object e) => debugPrint('billing: update handling failed: $e')),
      onError: (Object e, StackTrace st) => debugPrint('billing: purchaseStream error $e'),
    );
    final uidChanges = _uidChanges;
    if (uidChanges != null) {
      _uidSub = uidChanges.listen(_onUid, onError: (Object _) {});
    } else {
      _onUid(_currentUid());
    }
  }

  void _onUid(String? uid) {
    if (uid == null) {
      _lastUid = null;
      return;
    }
    if (uid == _lastUid) return;
    _lastUid = uid;
    unawaited(_resendUnfinished());
  }

  Future<void> _resendUnfinished() async {
    if (!await _safeIsAvailable()) return;
    try {
      await _store.restorePurchases();
    } catch (e) {
      debugPrint('billing: background restore failed: $e');
    }
  }

  Future<bool> _safeIsAvailable() async {
    try {
      return await _store.isAvailable();
    } catch (e) {
      debugPrint('billing: isAvailable failed: $e');
      return false;
    }
  }

  /// Queries Google Play for [BillingProducts.all]. Throws
  /// [BillingCatalogException] when Play answered with an error.
  Future<StoreCatalog> loadCatalog() async {
    if (!await _safeIsAvailable()) return const StoreCatalog.unavailable();
    final ProductDetailsResponse response;
    try {
      response = await _store.queryProductDetails(BillingProducts.all);
    } catch (e) {
      throw BillingCatalogException(e.toString());
    }
    if (response.error != null && response.productDetails.isEmpty) {
      throw BillingCatalogException(response.error!.message);
    }
    final products = response.productDetails
        .where((p) => BillingProducts.all.contains(p.id))
        .toList();
    for (final p in products) {
      _productsById[p.id] = p;
    }
    return StoreCatalog(
      available: true,
      products: products,
      notFoundIds: response.notFoundIDs,
    );
  }

  /// Starts a Google Play purchase. The result arrives on the purchase stream.
  Future<void> buy(ProductDetails product) async {
    if (_disposed || flow.value.isBusy) return;
    if (!_started) await start();
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      _fail(product.id, BillingIssue.notSignedIn, userInitiated: true);
      return;
    }
    if (!BillingProducts.all.contains(product.id)) {
      _fail(product.id, BillingIssue.productUnavailable, userInitiated: true);
      return;
    }
    if (!await _safeIsAvailable()) {
      _fail(product.id, BillingIssue.storeUnavailable, userInitiated: true);
      return;
    }
    _productsById[product.id] = product;
    _foregroundProductId = product.id;
    _setFlow(PurchaseFlowState(phase: PurchasePhase.launching, productId: product.id));
    _armLaunchTimeout(product.id);
    try {
      final launched = await _store.buyConsumable(PurchaseParam(
        productDetails: product,
        applicationUserName: obfuscatedAccountId(uid),
      ));
      if (!launched && _isStillLaunching(product.id)) {
        _foregroundProductId = null;
        _fail(product.id, BillingIssue.launchFailed, userInitiated: true);
      }
    } catch (e) {
      debugPrint('billing: buyConsumable failed: $e');
      if (!_isStillLaunching(product.id)) return;
      _foregroundProductId = null;
      if (_looksAlreadyOwned(e.toString())) {
        _fail(product.id, BillingIssue.alreadyOwned, userInitiated: true);
        unawaited(_resendUnfinished());
      } else {
        _fail(product.id, BillingIssue.launchFailed, userInitiated: true);
      }
    }
  }

  /// "Restore purchases": re-sends every unfinished purchase to the server.
  Future<void> restore() async {
    if (_disposed || flow.value.isBusy) return;
    if (!_started) await start();
    if (_currentUid() == null) {
      _fail(null, BillingIssue.notSignedIn, userInitiated: true);
      return;
    }
    if (!await _safeIsAvailable()) {
      _fail(null, BillingIssue.storeUnavailable, userInitiated: true);
      return;
    }
    _userRestore = true;
    _setFlow(const PurchaseFlowState(phase: PurchasePhase.restoring));
    _emit(const BillingNotice(BillingNoticeKind.restoreStarted));
    try {
      await _store.restorePurchases();
      // Let the restored updates that Play just queued reach the handler.
      await Future<void>.delayed(Duration.zero);
      await _queue;
      if (flow.value.phase == PurchasePhase.restoring) {
        _setFlow(const PurchaseFlowState());
      }
      _emit(const BillingNotice(BillingNoticeKind.restoreFinished));
    } catch (e) {
      debugPrint('billing: restore failed: $e');
      _fail(null, BillingIssue.storeError, userInitiated: true);
    } finally {
      _userRestore = false;
    }
  }

  /// Purchase-update state machine. Public for tests; in the app it is fed by
  /// the purchase stream (serialised, one batch at a time).
  @visibleForTesting
  Future<void> handlePurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final p in updates) {
      if (_disposed) return;
      await _handle(p);
    }
  }

  Future<void> _handle(PurchaseDetails p) async {
    final foreground = _isForeground(p);
    switch (p.status) {
      case PurchaseStatus.pending:
        if (!BillingProducts.all.contains(p.productID)) return;
        if (foreground || !flow.value.isBusy) {
          _cancelLaunchTimeout();
          _setFlow(PurchaseFlowState(phase: PurchasePhase.pendingPayment, productId: p.productID));
        }
        if (foreground) _emit(BillingNotice(BillingNoticeKind.pending, productId: p.productID));
        return;

      case PurchaseStatus.canceled:
        if (!foreground) return;
        _cancelLaunchTimeout();
        _foregroundProductId = null;
        _setFlow(PurchaseFlowState(phase: PurchasePhase.canceled, productId: _nonEmpty(p.productID)));
        _emit(BillingNotice(BillingNoticeKind.canceled, productId: _nonEmpty(p.productID)));
        return;

      case PurchaseStatus.error:
        // Never finish an errored purchase: on Play there is nothing to
        // acknowledge, and acknowledging something we did not grant would
        // stop Google's automatic refund.
        if (!foreground) return;
        _cancelLaunchTimeout();
        _foregroundProductId = null;
        final owned = _looksAlreadyOwned('${p.error?.message} ${p.error?.details}');
        _fail(_nonEmpty(p.productID), owned ? BillingIssue.alreadyOwned : BillingIssue.storeError,
            userInitiated: true);
        if (owned) unawaited(_resendUnfinished());
        return;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        if (!BillingProducts.all.contains(p.productID)) {
          debugPrint('billing: ignoring unknown product ${p.productID}');
          return;
        }
        await _verifyAndComplete(p, foreground: foreground);
        return;
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails p, {required bool foreground}) async {
    final token = p.verificationData.serverVerificationData;
    if (token.isEmpty) {
      if (foreground) _fail(p.productID, BillingIssue.invalid, userInitiated: true);
      return;
    }
    if (!_inFlightTokens.add(token)) return;
    try {
      final uid = _currentUid();
      if (uid == null || uid.isEmpty) {
        // Re-sent automatically once someone signs in (_onUid).
        if (foreground) _fail(p.productID, BillingIssue.notSignedIn, userInitiated: true);
        return;
      }
      if (foreground) {
        _cancelLaunchTimeout();
        _setFlow(PurchaseFlowState(phase: PurchasePhase.verifying, productId: p.productID));
      }

      final VerifyPurchaseResult result;
      try {
        result = await _verifier.verify(VerifyPurchaseRequest(
          productId: p.productID,
          purchaseToken: token,
          orderId: p.purchaseID,
          priceDisplay: _productsById[p.productID]?.price,
        ));
      } on PurchaseVerificationException catch (e) {
        _onVerifyFailure(p, e.kind, foreground: foreground);
        return;
      } catch (e) {
        _onVerifyFailure(p, PurchaseVerificationException.from(e).kind, foreground: foreground);
        return;
      }

      switch (result.status) {
        case VerifyStatus.granted:
        case VerifyStatus.alreadyProcessed:
          await _completeQuietly(p);
          final firstTime = _settledTokens.add(token);
          if (foreground) _foregroundProductId = null;
          if (foreground || !flow.value.isBusy) {
            _setFlow(PurchaseFlowState(phase: PurchasePhase.granted, productId: p.productID));
          }
          // A background re-send of something already processed is routine
          // and silent; a fresh grant is always worth telling the user.
          final announce = foreground
              ? firstTime
              : (result.status == VerifyStatus.granted && firstTime);
          if (announce) {
            _emit(BillingNotice(BillingNoticeKind.granted,
                productId: p.productID, userInitiated: foreground));
          }
        case VerifyStatus.pending:
          _onVerifyFailure(p, VerifyFailureKind.pending, foreground: foreground);
        case VerifyStatus.invalid:
          _onVerifyFailure(p, VerifyFailureKind.invalid, foreground: foreground);
      }
    } finally {
      _inFlightTokens.remove(token);
    }
  }

  void _onVerifyFailure(PurchaseDetails p, VerifyFailureKind kind, {required bool foreground}) {
    switch (kind) {
      case VerifyFailureKind.pending:
        if (foreground || !flow.value.isBusy) {
          _setFlow(PurchaseFlowState(phase: PurchasePhase.pendingPayment, productId: p.productID));
        }
        if (foreground) _emit(BillingNotice(BillingNoticeKind.pending, productId: p.productID));
      case VerifyFailureKind.invalid:
        if (foreground) {
          _foregroundProductId = null;
          _fail(p.productID, BillingIssue.invalid, userInitiated: true);
        }
      case VerifyFailureKind.accountMismatch:
        if (foreground) {
          _foregroundProductId = null;
          _fail(p.productID, BillingIssue.accountMismatch, userInitiated: true);
        }
      case VerifyFailureKind.retryable:
        if (foreground) {
          _foregroundProductId = null;
          _fail(p.productID, BillingIssue.verificationDeferred, userInitiated: true);
        }
    }
  }

  /// Finishes the purchase on the device. Errors are expected and ignored:
  /// the server has usually consumed the token already, after which Play
  /// rejects a client-side acknowledge.
  Future<void> _completeQuietly(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await _store.completePurchase(p);
    } catch (e) {
      debugPrint('billing: completePurchase ignored error: $e');
    }
  }

  bool _isForeground(PurchaseDetails p) {
    final fg = _foregroundProductId;
    if (fg != null && (p.productID.isEmpty || p.productID == fg)) return true;
    return _userRestore && p.status == PurchaseStatus.restored;
  }

  bool _isStillLaunching(String productId) =>
      flow.value.phase == PurchasePhase.launching && flow.value.productId == productId;

  static bool _looksAlreadyOwned(String text) {
    final t = text.toLowerCase();
    return t.contains('itemalreadyowned') || t.contains('item_already_owned') || t.contains('already owned');
  }

  static String? _nonEmpty(String s) => s.isEmpty ? null : s;

  void _fail(String? productId, BillingIssue issue, {required bool userInitiated}) {
    _cancelLaunchTimeout();
    _setFlow(PurchaseFlowState(phase: PurchasePhase.failed, productId: productId, issue: issue));
    _emit(BillingNotice(BillingNoticeKind.failed,
        productId: productId, issue: issue, userInitiated: userInitiated));
  }

  void _armLaunchTimeout(String productId) {
    _cancelLaunchTimeout();
    _launchTimer = Timer(_launchTimeout, () {
      // Play never reported back (sheet killed, process restarted…): do not
      // leave the buttons disabled forever. A late update is still handled.
      if (_isStillLaunching(productId)) {
        _foregroundProductId = null;
        _setFlow(const PurchaseFlowState());
      }
    });
  }

  void _cancelLaunchTimeout() {
    _launchTimer?.cancel();
    _launchTimer = null;
  }

  void _setFlow(PurchaseFlowState s) {
    if (_disposed) return;
    flow.value = s;
  }

  void _emit(BillingNotice n) {
    if (_disposed || _notices.isClosed) return;
    _notices.add(n);
  }

  /// Clears a finished/failed status line (e.g. when leaving the store page).
  void acknowledgeStatus() {
    if (flow.value.isBusy || flow.value.phase == PurchasePhase.pendingPayment) return;
    _setFlow(const PurchaseFlowState());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelLaunchTimeout();
    unawaited(_purchaseSub?.cancel());
    unawaited(_uidSub?.cancel());
    unawaited(_notices.close());
    flow.dispose();
  }
}
