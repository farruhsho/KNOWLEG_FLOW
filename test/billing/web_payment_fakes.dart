import 'package:knowledge_flow/features/billing/data/web_payment_gateway.dart';

/// Scriptable stand-in for `paymentCreateOrder` / `paymentGetOrder` and the
/// same-tab redirect. Never touches a payment provider.
class FakeWebGateway implements WebPaymentGateway {
  final created = <({String productId, String returnUrl})>[];
  final opened = <Uri>[];
  final polled = <String>[];

  /// Thrown by [createOrder] when set.
  Object? createError;
  WebOrder Function(String productId)? onCreate;

  /// Answers of [getOrder], in order; the last one repeats. An [Exception]
  /// entry is thrown.
  List<Object> orderScript = const [];

  @override
  Future<WebOrder> createOrder({required String productId, required String returnUrl}) async {
    created.add((productId: productId, returnUrl: returnUrl));
    if (createError != null) throw createError!;
    return (onCreate ??
        (id) => WebOrder(
              orderId: 'ord_${created.length}',
              checkoutUrl: Uri.parse('https://pay.example.kg/checkout/ord_${created.length}'),
              amountSom: 100,
              credits: 1,
            ))(productId);
  }

  @override
  Future<WebOrderState> getOrder(String orderId) async {
    polled.add(orderId);
    if (orderScript.isEmpty) {
      throw const WebPaymentException(WebPaymentIssue.network);
    }
    final i = (polled.length - 1).clamp(0, orderScript.length - 1);
    final answer = orderScript[i];
    if (answer is Exception) throw answer;
    return answer as WebOrderState;
  }

  @override
  Future<void> openCheckout(Uri checkoutUrl) async => opened.add(checkoutUrl);
}

class MemoryPendingOrderStore implements PendingWebOrderStore {
  String? value;

  MemoryPendingOrderStore([this.value]);

  @override
  Future<void> save(String orderId) async => value = orderId;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> clear() async => value = null;
}
