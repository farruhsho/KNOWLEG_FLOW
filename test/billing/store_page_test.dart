import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/billing/application/billing_providers.dart';
import 'package:knowledge_flow/features/billing/domain/billing_mode.dart';
import 'package:knowledge_flow/features/billing/domain/entitlements.dart';
import 'package:knowledge_flow/features/billing/domain/obfuscated_account_id.dart';
import 'package:knowledge_flow/features/billing/domain/pricing_config.dart';
import 'package:knowledge_flow/features/billing/presentation/pages/store_page.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'billing_fakes.dart';

void main() {
  late FakeStore store;
  late FakeVerifier verifier;

  setUp(() {
    store = FakeStore();
    verifier = FakeVerifier();
  });

  tearDown(() => store.close());

  Future<void> pumpStore(
    WidgetTester tester, {
    required BillingMode mode,
    Entitlements entitlements =
        const Entitlements(freeExamUsed: false, credits: 3, lifetimeCreditsPurchased: 3),
    Brightness brightness = Brightness.light,
    String? uid = 'user-1',
  }) async {
    // Small phone: 360 x 640 dp.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        billingModeProvider.overrideWithValue(mode),
        storeGatewayProvider.overrideWithValue(store),
        purchaseVerifierProvider.overrideWithValue(verifier),
        billingCurrentUidProvider.overrideWithValue(() => uid),
        billingUidChangesProvider.overrideWithValue(Stream<String?>.value(uid)),
        billingUidProvider.overrideWith((ref) => Stream<String?>.value(uid)),
        entitlementsProvider.overrideWith((ref) => Stream.value(entitlements)),
        pricingConfigProvider.overrideWith((ref) => Stream.value(PricingConfig.defaults)),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: brightness,
          extensions: [brightness == Brightness.dark ? AppTokens.dark : AppTokens.light],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: const StorePage(),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  group('external (consumption-only) mode', () {
    testWidgets('shows balance and the neutral line, no prices or buy buttons', (tester) async {
      await pumpStore(tester, mode: BillingMode.external);

      expect(find.text('3 кредита'), findsOneWidget);
      expect(find.text('Первый полный пробный экзамен — бесплатно'), findsOneWidget);
      expect(find.text('Доступ к дополнительным тестам можно приобрести на нашем сайте.'), findsOneWidget);

      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Восстановить покупки'), findsNothing);
      expect(find.textContaining('US\$'), findsNothing);
      expect(find.textContaining('сом'), findsNothing);
      expect(find.textContaining('http'), findsNothing);
      // Google Play is never touched in this mode.
      expect(store.restoreCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode without overflow', (tester) async {
      await pumpStore(tester, mode: BillingMode.external, brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  });

  group('play mode', () {
    testWidgets('lists products with the Play price and credit labels', (tester) async {
      await pumpStore(tester, mode: BillingMode.play);
      await tester.pump();

      expect(find.text('1 тест'), findsOneWidget);
      expect(find.text('5 тестов'), findsOneWidget);
      expect(find.text('10 тестов'), findsOneWidget);
      expect(find.text('US\$ 0.99'), findsOneWidget);
      expect(find.text('US\$ 4.49'), findsOneWidget);
      expect(find.text('US\$ 7.99'), findsOneWidget);
      expect(find.textContaining('100 сом'), findsNothing);
      expect(find.text('1 кредит = 1 полный пробный экзамен'), findsOneWidget);

      // Ordered single → 5 → 10 regardless of Play's order.
      final y1 = tester.getTopLeft(find.text('1 тест')).dy;
      final y5 = tester.getTopLeft(find.text('5 тестов')).dy;
      final y10 = tester.getTopLeft(find.text('10 тестов')).dy;
      expect(y1 < y5 && y5 < y10, isTrue);

      // Restore and the honest copy sit below the fold on a 360x640 phone.
      await tester.scrollUntilVisible(find.text('Восстановить покупки'), 200);
      expect(find.text('Восстановить покупки'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('не гарантируют результат'), 200);
      expect(find.textContaining('наш сервер подтвердит'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('buy → server grant → success status; nothing granted client-side', (tester) async {
      await pumpStore(tester, mode: BillingMode.play);
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('buy_exam_pack_5')));
      await tester.tap(find.byKey(const ValueKey('buy_exam_pack_5')));
      await tester.pump();
      await tester.pump();

      expect(store.buys, hasLength(1));
      expect(store.buys.single.productDetails.id, 'exam_pack_5');
      expect(store.buys.single.applicationUserName, obfuscatedAccountId('user-1'));
      expect(find.text('Открываем Google Play…'), findsOneWidget);

      store.emit([purchase(productId: 'exam_pack_5', token: 'tok-ui')]);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(verifier.calls.single.priceDisplay, 'US\$ 4.49');
      expect(store.completed, hasLength(1));
      expect(find.text('Покупка подтверждена, кредиты зачислены.'), findsOneWidget);
      // Balance still comes only from the (fake) server document.
      await tester.scrollUntilVisible(find.text('3 кредита'), -200);
      expect(find.text('3 кредита'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pending payment shows "ожидает оплаты" and is not completed', (tester) async {
      await pumpStore(tester, mode: BillingMode.play);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('buy_exam_single')));
      await tester.pump();
      store.emit([purchase(status: PurchaseStatus.pending)]);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Ожидает оплаты'), findsOneWidget);
      expect(store.completed, isEmpty);
      expect(verifier.calls, isEmpty);
    });

    testWidgets('Play unavailable shows a clear state with retry', (tester) async {
      store.available = false;
      await pumpStore(tester, mode: BillingMode.play);
      await tester.pump();
      expect(find.text('Покупки недоступны'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.byKey(const ValueKey('buy_exam_single')), findsNothing);
    });

    testWidgets('no products → empty state with retry', (tester) async {
      store.products = [];
      await pumpStore(tester, mode: BillingMode.play);
      await tester.pump();
      expect(find.text('Предложения временно недоступны. Попробуйте позже.'), findsOneWidget);
    });

    testWidgets('signed out → sign-in message instead of a balance', (tester) async {
      await pumpStore(tester, mode: BillingMode.play, uid: null);
      await tester.pump();
      expect(find.text('Войдите в аккаунт, чтобы увидеть баланс и историю.'), findsOneWidget);
      expect(find.text('3 кредита'), findsNothing);
    });

    testWidgets('dark mode on a small phone renders without overflow', (tester) async {
      await pumpStore(tester, mode: BillingMode.play, brightness: Brightness.dark);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
