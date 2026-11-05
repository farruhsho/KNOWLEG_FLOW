import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/backend/backend_contract.dart';
import '../../../core/routes/route_paths.dart';
import '../domain/firestore_values.dart';

/// `paymentCreateOrder` answer (ARCHITECTURE §10.3).
@immutable
class WebOrder {
  final String orderId;
  final Uri checkoutUrl;
  final int amountSom;
  final int credits;
  final DateTime? expiresAt;

  const WebOrder({
    required this.orderId,
    required this.checkoutUrl,
    required this.amountSom,
    required this.credits,
    this.expiresAt,
  });
}

/// `paymentGetOrder` answer: order status and the account's balance.
@immutable
class WebOrderState {
  /// One of [PaymentOrderStatuses].
  final String status;
  final int credits;

  /// Credits on the account after this order (null if the server omits it).
  final int? balance;

  const WebOrderState({required this.status, required this.credits, this.balance});

  bool get isTerminal => PaymentOrderStatuses.terminal.contains(status);
  bool get isPaid => status == PaymentOrderStatuses.paid;
}

/// Why a web payment call failed.
enum WebPaymentIssue {
  /// `PAYMENTS_DISABLED`: no provider configured yet.
  paymentsDisabled,

  /// `PRODUCT_UNAVAILABLE`: the pack is disabled or unknown.
  productUnavailable,

  /// `RATE_LIMITED`: more than 10 orders today.
  rateLimited,

  /// `ORDER_NOT_FOUND`: unknown or someone else's order.
  orderNotFound,

  /// The checkout URL is not a web page we may open.
  invalidCheckout,
  unauthenticated,
  network,
  unknown,
}

class WebPaymentException implements Exception {
  final WebPaymentIssue issue;
  final String? message;

  const WebPaymentException(this.issue, [this.message]);

  @override
  String toString() => 'WebPaymentException($issue${message == null ? '' : ': $message'})';
}

/// Site payments through the server's provider adapter (§10.3). The client
/// never talks to a payment provider directly: it creates an order, sends
/// the browser to the provider's checkout page, and on return asks the
/// server what happened. Credits are granted only by the server's webhook.
abstract interface class WebPaymentGateway {
  Future<WebOrder> createOrder({required String productId, required String returnUrl});

  Future<WebOrderState> getOrder(String orderId);

  /// Navigates this browser tab to the provider's checkout page.
  Future<void> openCheckout(Uri checkoutUrl);
}

/// Where the provider sends the student back: this site's origin and the
/// app's hash route (the router uses the default `#/` URL strategy). The
/// order id does not exist before `paymentCreateOrder`; the server appends
/// `order={id}`, and the return page also reads it from the page query or
/// from [PendingWebOrderStore].
String webPaymentReturnUrl(Uri base) => '${base.origin}/#${RoutePaths.payReturn}';

/// Only https pages (and the emulator's http sandbox on localhost) may be
/// opened as a checkout.
bool isAllowedCheckoutUrl(Uri url) {
  if (url.scheme == 'https' && url.host.isNotEmpty) return true;
  if (url.scheme == 'http') {
    return url.host == 'localhost' || url.host == '127.0.0.1';
  }
  return false;
}

class CallableWebPaymentGateway implements WebPaymentGateway {
  const CallableWebPaymentGateway();

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final result = await BackendFunctions.callable(name).call<Object?>(data);
      final raw = result.data;
      if (raw is Map) {
        return {for (final e in raw.entries) e.key.toString(): e.value};
      }
      return const {};
    } on FirebaseFunctionsException catch (e) {
      throw WebPaymentException(_issue(e), e.message);
    } on TimeoutException {
      throw const WebPaymentException(WebPaymentIssue.network, 'timeout');
    } catch (e) {
      throw WebPaymentException(WebPaymentIssue.network, e.toString());
    }
  }

  static WebPaymentIssue _issue(FirebaseFunctionsException e) {
    switch (BackendReasons.of(e)) {
      case BackendReasons.paymentsDisabled:
        return WebPaymentIssue.paymentsDisabled;
      case BackendReasons.productUnavailable:
        return WebPaymentIssue.productUnavailable;
      case BackendReasons.rateLimited:
        return WebPaymentIssue.rateLimited;
      case BackendReasons.orderNotFound:
        return WebPaymentIssue.orderNotFound;
    }
    return switch (e.code) {
      'unauthenticated' => WebPaymentIssue.unauthenticated,
      'unavailable' || 'deadline-exceeded' => WebPaymentIssue.network,
      'not-found' => WebPaymentIssue.orderNotFound,
      _ => WebPaymentIssue.unknown,
    };
  }

  @override
  Future<WebOrder> createOrder({
    required String productId,
    required String returnUrl,
  }) async {
    final m = await _call(BackendFunctions.paymentCreateOrder, {
      'productId': productId,
      'returnUrl': returnUrl,
    });
    final orderId = FirestoreValues.readString(m['orderId'] ?? m['order_id']);
    final url = Uri.tryParse(
        FirestoreValues.readString(m['checkoutUrl'] ?? m['checkout_url']) ?? '');
    if (orderId == null || url == null || !isAllowedCheckoutUrl(url)) {
      throw const WebPaymentException(WebPaymentIssue.invalidCheckout);
    }
    return WebOrder(
      orderId: orderId,
      checkoutUrl: url,
      amountSom: FirestoreValues.readInt(m['amountSom'] ?? m['amount_som']),
      credits: FirestoreValues.readInt(m['credits']),
      expiresAt: FirestoreValues.readDate(m['expiresAt'] ?? m['expires_at']),
    );
  }

  @override
  Future<WebOrderState> getOrder(String orderId) async {
    final m = await _call(BackendFunctions.paymentGetOrder, {'orderId': orderId});
    final balance = m['balance'];
    return WebOrderState(
      status: FirestoreValues.readString(m['status']) ?? PaymentOrderStatuses.pending,
      credits: FirestoreValues.readInt(m['credits']),
      balance: balance == null ? null : FirestoreValues.readInt(balance),
    );
  }

  @override
  Future<void> openCheckout(Uri checkoutUrl) async {
    if (!isAllowedCheckoutUrl(checkoutUrl)) {
      throw const WebPaymentException(WebPaymentIssue.invalidCheckout);
    }
    // Same tab: the provider returns to RoutePaths.payReturn afterwards.
    final ok = await launchUrl(checkoutUrl, webOnlyWindowName: '_self');
    if (!ok) throw const WebPaymentException(WebPaymentIssue.invalidCheckout);
  }
}

/// The order being paid, kept across the full-page round trip to the
/// provider (localStorage on web) in case the return URL lost `?order=`.
abstract interface class PendingWebOrderStore {
  Future<void> save(String orderId);
  Future<String?> read();
  Future<void> clear();
}

class PrefsPendingWebOrderStore implements PendingWebOrderStore {
  static const key = 'web_pending_order_id';

  const PrefsPendingWebOrderStore();

  @override
  Future<void> save(String orderId) async =>
      (await SharedPreferences.getInstance()).setString(key, orderId);

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(key);
}
