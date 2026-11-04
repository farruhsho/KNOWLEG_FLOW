import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/backend/backend_contract.dart';
import '../domain/firestore_values.dart';

/// Input of the `billingVerifyPurchase` callable (ARCHITECTURE §3).
class VerifyPurchaseRequest {
  final String productId;
  final String purchaseToken;
  final String? orderId;
  final String? priceDisplay;

  const VerifyPurchaseRequest({
    required this.productId,
    required this.purchaseToken,
    this.orderId,
    this.priceDisplay,
  });

  Map<String, dynamic> toPayload() => {
        'productId': productId,
        'purchaseToken': purchaseToken,
        if (orderId != null && orderId!.isNotEmpty) 'orderId': orderId,
        if (priceDisplay != null && priceDisplay!.isNotEmpty)
          'priceDisplay': priceDisplay,
      };
}

enum VerifyStatus { granted, alreadyProcessed, pending, invalid }

/// Output of `billingVerifyPurchase`: `{status, credits}`.
class VerifyPurchaseResult {
  final VerifyStatus status;

  /// As reported by the server. The UI never trusts it for access — the
  /// balance shown always comes from `entitlements/{uid}`.
  final int credits;

  const VerifyPurchaseResult(this.status, {this.credits = 0});

  /// Whether the server has recorded the purchase and it is now safe to
  /// finish (acknowledge) it on the device.
  bool get isSettled =>
      status == VerifyStatus.granted || status == VerifyStatus.alreadyProcessed;

  /// Throws [FormatException] when the response is not understood, so an
  /// unexpected backend reply is never mistaken for a grant.
  factory VerifyPurchaseResult.fromResponse(Object? data) {
    final map = FirestoreValues.readMap(data);
    if (map == null) throw const FormatException('billingVerifyPurchase: not a map');
    final VerifyStatus status;
    switch (map['status']?.toString()) {
      case 'granted':
        status = VerifyStatus.granted;
      case 'already_processed':
        status = VerifyStatus.alreadyProcessed;
      case 'pending':
        status = VerifyStatus.pending;
      case 'invalid':
        status = VerifyStatus.invalid;
      default:
        throw FormatException('billingVerifyPurchase: unknown status ${map['status']}');
    }
    return VerifyPurchaseResult(status, credits: FirestoreValues.readInt(map['credits']));
  }
}

enum VerifyFailureKind {
  /// The server checked the token and refused it. Do not retry.
  invalid,

  /// The purchase was made under a different app account. Do not retry here.
  accountMismatch,

  /// Google Play still reports the payment as pending.
  pending,

  /// Network, timeout, cold start, auth refresh… Retry later.
  retryable,
}

class PurchaseVerificationException implements Exception {
  final VerifyFailureKind kind;
  final String? code;
  final Object? cause;

  const PurchaseVerificationException(this.kind, {this.code, this.cause});

  /// Maps a callable error (`HttpsError` with `details.reason`) to a kind.
  factory PurchaseVerificationException.from(Object error) {
    if (error is PurchaseVerificationException) return error;
    if (error is FirebaseFunctionsException) {
      switch (BackendReasons.of(error)) {
        case BackendReasons.purchaseInvalid:
        case BackendReasons.validationFailed:
          return PurchaseVerificationException(VerifyFailureKind.invalid,
              code: error.code, cause: error);
        case BackendReasons.purchaseAccountMismatch:
          return PurchaseVerificationException(VerifyFailureKind.accountMismatch,
              code: error.code, cause: error);
        case BackendReasons.purchasePending:
          return PurchaseVerificationException(VerifyFailureKind.pending,
              code: error.code, cause: error);
      }
      return PurchaseVerificationException(VerifyFailureKind.retryable,
          code: error.code, cause: error);
    }
    return PurchaseVerificationException(VerifyFailureKind.retryable, cause: error);
  }

  @override
  String toString() => 'PurchaseVerificationException($kind, $code)';
}

/// Server-side verification of a Play purchase token.
abstract interface class PurchaseVerifier {
  /// Returns the server verdict or throws [PurchaseVerificationException].
  Future<VerifyPurchaseResult> verify(VerifyPurchaseRequest request);
}

class CallablePurchaseVerifier implements PurchaseVerifier {
  const CallablePurchaseVerifier();

  @override
  Future<VerifyPurchaseResult> verify(VerifyPurchaseRequest request) async {
    try {
      final result = await BackendFunctions.callable(
        BackendFunctions.billingVerifyPurchase,
        timeout: const Duration(seconds: 45),
      ).call<Object?>(request.toPayload());
      return VerifyPurchaseResult.fromResponse(result.data);
    } on FormatException catch (e) {
      throw PurchaseVerificationException(VerifyFailureKind.retryable, cause: e);
    } catch (e) {
      throw PurchaseVerificationException.from(e);
    }
  }
}
