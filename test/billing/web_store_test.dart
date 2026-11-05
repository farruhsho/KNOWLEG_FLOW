import 'dart:io';

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
import 'package:knowledge_flow/features/billing/domain/pricing_config.dart';
import 'package:knowledge_flow/features/billing/presentation/pages/store_page.dart';
import 'package:knowledge_flow/features/legal/legal_documents.dart';
import 'package:knowledge_flow/features/legal/legal_routes.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'billing_fakes.dart';
import 'web_payment_fakes.dart';

/// BILLING_MODE=web (ARCHITECTURE §10.3): prices only from
/// `config/pricing.web_products`, «Оплатить» → server order → same-tab
/// checkout, legal links; `external` and `play` stay as they were.
void main() {
  final pricing = PricingConfig.fromMap({
    'products': {'exam_single': 1, 'exam_pack_5': 5, 'exam_pack_10': 10},
    'web_products': {
      'exam_pack_5': {'credits': 5, 'amount_som': 450, 'enabled': false},
      'exam_single': {'credits': 1, 'amount_som': 100, 'enabled': true},
      'exam_pack_10': {'credits': 10, 'amount_som': 800, 'enabled': true},
      'broken': {'credits': 0, 'amount_som': 50, 'enabled': true},
    },
  });

  group('domain', () {
    test('BILLING_MODE=web only takes effect in a web build', () {
      expect(BillingMode.parse('web'), BillingMode.web);
      expect(BillingMode.resolve('web', isWeb: true), BillingMode.web);
      expect(BillingMode.resolve('web', isWeb: false), BillingMode.external,
          reason: 'an Android build must never show site prices or links');
      expect(BillingMode.resolve('play', isWeb: true), BillingMode.play);
      expect(BillingMode.resolve('nonsense', isWeb: false), BillingMode.play);
      expect(BillingMode.web.sellsInApp, isTrue);
      expect(BillingMode.web.usesPlayBilling, isFalse);
      expect(BillingMode.external.sellsInApp, isFalse);
      expect(BillingMode.external.sellsOnWeb, isFalse);
    });

    test('web_products: enabled and valid only, smallest pack first', () {
      expect(pricing.enabledWebProducts.map((p) => p.productId), ['exam_single', 'exam_pack_10']);
      expect(pricing.webProducts.containsKey('broken'), isFalse);
      expect(pricing.webProducts['exam_single']!.amountSom, 100);
      expect(PricingConfig.defaults.webProducts, isEmpty, reason: 'no hard-coded prices');
      expect(PricingConfig.fromMap(null).enabledWebProducts, isEmpty);
    });

    test('return URL and allowed checkout pages', () {
      expect(webPaymentReturnUrl(Uri.parse('https://ort.example.kg/#/store')),
          'https://ort.example.kg/#/pay/return');
      expect(webPaymentReturnUrl(Uri.parse('http://localhost:5000/')),
          'http://localhost:5000/#/pay/return');
      expect(isAllowedCheckoutUrl(Uri.parse('https://pay.example.kg/c/1')), isTrue);
      expect(isAllowedCheckoutUrl(Uri.parse('http://localhost:5001/sandbox')), isTrue);
      expect(isAllowedCheckoutUrl(Uri.parse('http://pay.example.kg/c/1')), isFalse);
      expect(isAllowedCheckoutUrl(Uri.parse('javascript:alert(1)')), isFalse);
    });

    test('bundled legal texts are verbatim copies of docs/legal', () {
      expect(File(LegalDocument.offer.asset).readAsStringSync(),
          File('docs/legal/OFFER_ru.md').readAsStringSync());
      expect(File(LegalDocument.refund.asset).readAsStringSync(),
          File('docs/legal/REFUND_ru.md').readAsStringSync());
      final offer = unwrapMarkdown(File('docs/legal/OFFER_ru.md').readAsStringSync());
      expect(offer, contains('1 кредит = 1 полный пробный экзамен'));
      expect(offer, contains('100 сом'));
      expect(offer, contains('ЧЕРНОВИК ДЛЯ ЮРИСТА'));
      expect(offer, contains('учебный'));
      expect(File('docs/legal/REFUND_ru.md').readAsStringSync(),
          contains('Неиспользованные кредиты'));
    });

    test('unwrapMarkdown joins hard-wrapped lines, keeps blocks', () {
      expect(
        unwrapMarkdown('# Title\n\n1.1. One\ntwo\n\n- item\n  cont\n- next'),
        '# Title\n\n1.1. One two\n\n- item cont\n- next',
      );
    });
  });

  group('store page', () {
    late FakeStore store;
    late FakeWebGateway gateway;
    late MemoryPendingOrderStore pending;

    setUp(() {
      store = FakeStore();
      gateway = FakeWebGateway();
      pending = MemoryPendingOrderStore();
    });

    tearDown(() => store.close());

    Future<void> pumpStore(
      WidgetTester tester, {
      required BillingMode mode,
      PricingConfig? config,
      bool webAvailable = true,
      String locale = 'ru',
    }) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: RoutePaths.store,
        routes: [
          GoRoute(path: RoutePaths.store, builder: (_, __) => const StorePage()),
          ...legalRoutes,
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          billingModeProvider.overrideWithValue(mode),
          playBillingPlatformProvider.overrideWithValue(mode == BillingMode.play),
          storeGatewayProvider.overrideWithValue(store),
          purchaseVerifierProvider.overrideWithValue(FakeVerifier()),
          billingCurrentUidProvider.overrideWithValue(() => 'user-1'),
          billingUidChangesProvider.overrideWithValue(Stream<String?>.value('user-1')),
          billingUidProvider.overrideWith((ref) => Stream<String?>.value('user-1')),
          entitlementsProvider.overrideWith((ref) => Stream.value(const Entitlements(
              freeExamUsed: true, credits: 2, lifetimeCreditsPurchased: 2))),
          pricingConfigProvider.overrideWith((ref) => Stream.value(config ?? pricing)),
          webPaymentGatewayProvider.overrideWithValue(gateway),
          pendingWebOrderStoreProvider.overrideWithValue(pending),
          webPaymentsAvailableProvider.overrideWithValue(webAvailable),
          webPageUriProvider.overrideWithValue(Uri.parse('https://ort.example.kg/#/store')),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(useMaterial3: true, extensions: [AppTokens.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(locale),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    List<String> visibleStrings(WidgetTester tester) => [
          for (final w in tester.widgetList<Text>(find.byType(Text)))
            w.data ?? w.textSpan?.toPlainText() ?? '',
          for (final w in tester.widgetList<RichText>(find.byType(RichText)))
            w.text.toPlainText(),
        ];

    final purchaseWording = RegExp(
      r'купи|покуп|приобр|оплат|оферт|возврат|сайт|сатып|төлө|кайтаруу|buy|purchas|pay|offer|refund|website|http|\d\s?сом|\d\s?som',
      caseSensitive: false,
    );

    testWidgets('web: enabled products with som prices, «Оплатить», legal links',
        (tester) async {
      await pumpStore(tester, mode: BillingMode.web);
      expect(find.text('2 кредита'), findsOneWidget);
      expect(find.byKey(const ValueKey('pay_exam_single')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay_exam_pack_10')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay_exam_pack_5')), findsNothing,
          reason: 'disabled until the owner approves the price');
      expect(find.text('100 сом'), findsOneWidget);
      expect(find.text('800 сом'), findsOneWidget);
      expect(find.text('Оплатить'), findsNWidgets(2));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('legal_offer_link')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const ValueKey('legal_offer_link')), findsOneWidget);
      expect(find.byKey(const ValueKey('legal_refund_link')), findsOneWidget);
      expect(find.text('Восстановить покупки'), findsNothing, reason: 'no Google Play here');
      expect(find.textContaining('Google Play'), findsNothing);
      expect(store.restoreCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«Оплатить» → paymentCreateOrder(returnUrl) → order saved → same-tab checkout',
        (tester) async {
      await pumpStore(tester, mode: BillingMode.web);
      await tester.tap(find.byKey(const ValueKey('pay_exam_single')));
      await tester.pump();
      await tester.pump();
      expect(gateway.created.single.productId, 'exam_single');
      expect(gateway.created.single.returnUrl, 'https://ort.example.kg/#/pay/return');
      expect(pending.value, 'ord_1');
      expect(gateway.opened.single.toString(), 'https://pay.example.kg/checkout/ord_1');
      expect(find.text('Открываем страницу оплаты…'), findsOneWidget);
      // Nothing is credited on the client.
      expect(find.text('2 кредита'), findsOneWidget);
    });

    testWidgets('PAYMENTS_DISABLED: honest message, buttons usable again', (tester) async {
      gateway.createError = const WebPaymentException(WebPaymentIssue.paymentsDisabled);
      await pumpStore(tester, mode: BillingMode.web);
      await tester.tap(find.byKey(const ValueKey('pay_exam_single')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Оплата пока не подключена. Попробуйте позже.'), findsOneWidget);
      expect(gateway.opened, isEmpty);
      expect(pending.value, isNull);
      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('pay_exam_single')));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('PRODUCT_UNAVAILABLE and RATE_LIMITED are explained', (tester) async {
      gateway.createError = const WebPaymentException(WebPaymentIssue.productUnavailable);
      await pumpStore(tester, mode: BillingMode.web);
      await tester.tap(find.byKey(const ValueKey('pay_exam_pack_10')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Этот пакет сейчас недоступен. Выберите другой.'), findsOneWidget);
      gateway.createError = const WebPaymentException(WebPaymentIssue.rateLimited);
      await tester.tap(find.byKey(const ValueKey('pay_exam_single')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Слишком много заказов за сегодня. Попробуйте завтра.'), findsOneWidget);
    });

    testWidgets('nothing configured (or no App Check on this site): no products, no button',
        (tester) async {
      await pumpStore(tester, mode: BillingMode.web, config: PricingConfig.defaults);
      expect(find.byKey(const ValueKey('web_products_empty')), findsOneWidget);
      expect(find.text('Оплатить'), findsNothing);
      await pumpStore(tester, mode: BillingMode.web, webAvailable: false);
      expect(find.byKey(const ValueKey('web_products_empty')), findsOneWidget);
      expect(find.text('Оплатить'), findsNothing);
    });

    testWidgets('legal link opens the bundled public offer (draft note)', (tester) async {
      await pumpStore(tester, mode: BillingMode.web);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('legal_offer_link')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('legal_offer_link')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('legal_draft_note')), findsOneWidget);
      expect(find.text('Публичная оферта'), findsOneWidget, reason: 'app bar title');
      expect(find.textContaining('цифровую услугу', findRichText: true), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    for (final locale in ['ru', 'ky', 'en']) {
      testWidgets('[$locale] external: even with web_products configured — no prices, '
          'no pay buttons, no legal links', (tester) async {
        await pumpStore(tester, mode: BillingMode.external, locale: locale);
        expect(find.byKey(const ValueKey('pay_exam_single')), findsNothing);
        expect(find.byKey(const ValueKey('legal_offer_link')), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        final offending = visibleStrings(tester).where(purchaseWording.hasMatch).toList();
        expect(offending, isEmpty);
        expect(gateway.created, isEmpty);
      });
    }

    testWidgets('external: a legal route opened anyway says nothing about payments',
        (tester) async {
      await pumpStore(tester, mode: BillingMode.external);
      GoRouter.of(tester.element(find.byType(StorePage))).push(RoutePaths.legalOffer);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('legal_draft_note')), findsNothing);
      final offending = visibleStrings(tester).where(purchaseWording.hasMatch).toList();
      expect(offending, isEmpty);
    });

    testWidgets('play: Google Play products as before, no site payments', (tester) async {
      await pumpStore(tester, mode: BillingMode.play);
      expect(find.text('US\$ 0.99'), findsOneWidget);
      expect(find.text('Оплатить'), findsNothing);
      expect(find.byKey(const ValueKey('legal_offer_link')), findsNothing);
      expect(find.text('100 сом'), findsNothing);
    });
  });
}
