import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';
import 'package:knowledge_flow/features/billing/application/billing_providers.dart';
import 'package:knowledge_flow/features/billing/data/web_payment_gateway.dart';
import 'package:knowledge_flow/features/billing/domain/billing_mode.dart';
import 'package:knowledge_flow/features/billing/domain/entitlements.dart';
import 'package:knowledge_flow/features/billing/presentation/pages/pay_return_page.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'web_payment_fakes.dart';

/// RoutePaths.payReturn (ARCHITECTURE §10.3): polls `paymentGetOrder` (fake
/// gateway, fake timers) and reports what the server says.
void main() {
  late FakeWebGateway gateway;
  late MemoryPendingOrderStore pending;

  setUp(() {
    gateway = FakeWebGateway();
    pending = MemoryPendingOrderStore();
  });

  const pendingState = WebOrderState(status: 'pending', credits: 1, balance: 0);

  Future<void> pumpPage(
    WidgetTester tester, {
    String location = '${RoutePaths.payReturn}?order=ord_7',
    BillingMode mode = BillingMode.web,
    Uri? pageUri,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: RoutePaths.payReturn,
          builder: (_, s) => PayReturnPage(
            orderId: s.uri.queryParameters['order'],
            pollInterval: const Duration(seconds: 3),
            maxWait: const Duration(seconds: 9),
          ),
        ),
        GoRoute(path: RoutePaths.exams, builder: (_, __) => const Text('EXAMS_TAB')),
        GoRoute(path: RoutePaths.store, builder: (_, __) => const Text('STORE_PAGE')),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        billingModeProvider.overrideWithValue(mode),
        webPaymentGatewayProvider.overrideWithValue(gateway),
        pendingWebOrderStoreProvider.overrideWithValue(pending),
        webPageUriProvider.overrideWithValue(
            pageUri ?? Uri.parse('https://ort.example.kg/#/pay/return')),
        entitlementsProvider.overrideWith((ref) => Stream.value(const Entitlements(
            freeExamUsed: true, credits: 3, lifetimeCreditsPurchased: 3))),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: [AppTokens.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('pending → pending → paid: credits, new balance, «Начать пробный»',
      (tester) async {
    pending.value = 'ord_7';
    gateway.orderScript = const [
      pendingState,
      pendingState,
      WebOrderState(status: 'paid', credits: 5, balance: 7),
    ];
    await pumpPage(tester);
    expect(find.byKey(const ValueKey('pay_return_checking')), findsOneWidget);
    expect(gateway.polled, ['ord_7']);
    await tester.pump(const Duration(seconds: 3));
    expect(gateway.polled, hasLength(2));
    expect(find.text('Проверяем оплату…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const ValueKey('pay_return_paid')), findsOneWidget);
    expect(find.text('Оплата прошла'), findsOneWidget);
    expect(find.text('Начислено 5 кредитов.'), findsOneWidget);
    expect(find.text('Баланс: 7 кредитов'), findsOneWidget);
    expect(pending.value, isNull, reason: 'the finished order is forgotten');
    await tester.tap(find.byKey(const ValueKey('pay_return_start_exam')));
    await tester.pumpAndSettle();
    expect(find.text('EXAMS_TAB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed and expired orders are reported, no credits', (tester) async {
    gateway.orderScript = const [WebOrderState(status: 'failed', credits: 1, balance: 3)];
    await pumpPage(tester);
    await tester.pump();
    expect(find.text('Оплата не прошла'), findsOneWidget);
    expect(find.textContaining('Кредиты не начислены'), findsOneWidget);

    gateway
      ..polled.clear()
      ..orderScript = const [WebOrderState(status: 'expired', credits: 1)];
    await pumpPage(tester, location: '${RoutePaths.payReturn}?order=ord_8');
    await tester.pump();
    expect(find.text('Заказ истёк'), findsOneWidget);
  });

  testWidgets('still pending after the window: honest message and «Проверить ещё раз»',
      (tester) async {
    gateway.orderScript = const [pendingState];
    await pumpPage(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(gateway.polled, hasLength(3), reason: '9 s window / 3 s interval');
    expect(find.byKey(const ValueKey('pay_return_pending')), findsOneWidget);
    expect(find.textContaining('Кредиты начислятся автоматически'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(gateway.polled, hasLength(3), reason: 'polling stopped');

    gateway.orderScript = const [WebOrderState(status: 'paid', credits: 1, balance: 4)];
    await tester.tap(find.byKey(const ValueKey('pay_return_check_again')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Оплата прошла'), findsOneWidget);
    expect(find.text('Баланс: 4 кредита'), findsOneWidget);
  });

  testWidgets('order id from the page query (provider put it before the #)', (tester) async {
    gateway.orderScript = const [WebOrderState(status: 'paid', credits: 1, balance: 1)];
    await pumpPage(tester,
        location: RoutePaths.payReturn,
        pageUri: Uri.parse('https://ort.example.kg/?order=ord_q#/pay/return'));
    await tester.pump();
    expect(gateway.polled, ['ord_q']);
  });

  testWidgets('order id saved before the redirect when the URL has none', (tester) async {
    pending.value = 'ord_saved';
    gateway.orderScript = const [WebOrderState(status: 'paid', credits: 1, balance: 1)];
    await pumpPage(tester, location: '${RoutePaths.payReturn}?order={orderId}');
    await tester.pump();
    expect(gateway.polled, ['ord_saved'], reason: 'an unfilled template is ignored');
  });

  testWidgets('no order anywhere: explains instead of polling', (tester) async {
    await pumpPage(tester, location: RoutePaths.payReturn);
    await tester.pump();
    expect(find.byKey(const ValueKey('pay_return_no_order')), findsOneWidget);
    expect(gateway.polled, isEmpty);
  });

  testWidgets('ORDER_NOT_FOUND (someone else\'s or unknown order)', (tester) async {
    gateway.orderScript = const [WebPaymentException(WebPaymentIssue.orderNotFound)];
    await pumpPage(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey('pay_return_not_found')), findsOneWidget);
  });

  testWidgets('connection errors are retried within the window, then «Проверить ещё раз»',
      (tester) async {
    gateway.orderScript = const [WebPaymentException(WebPaymentIssue.network)];
    await pumpPage(tester);
    expect(find.byKey(const ValueKey('pay_return_checking')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const ValueKey('pay_return_error')), findsOneWidget);
    expect(find.byKey(const ValueKey('pay_return_check_again')), findsOneWidget);
  });

  testWidgets('not a web build: neutral page, the server is never asked', (tester) async {
    gateway.orderScript = const [WebOrderState(status: 'paid', credits: 1, balance: 1)];
    await pumpPage(tester, mode: BillingMode.external);
    await tester.pump(const Duration(seconds: 5));
    expect(gateway.polled, isEmpty);
    expect(find.textContaining('Оплат'), findsNothing);
    expect(find.textContaining('кредит'), findsNothing);
  });
}
