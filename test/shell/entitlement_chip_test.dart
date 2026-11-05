import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';
import 'package:knowledge_flow/features/billing/application/billing_providers.dart';
import 'package:knowledge_flow/features/billing/domain/billing_mode.dart';
import 'package:knowledge_flow/features/billing/domain/entitlements.dart';
import 'package:knowledge_flow/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

const _empty = Entitlements(freeExamUsed: true, credits: 0, lifetimeCreditsPurchased: 1);

/// Home-screen entitlement chip on its own, with stub store / exams routes.
Future<void> _pump(WidgetTester tester, Entitlements ent, BillingMode mode) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: EntitlementChip()),
      ),
      GoRoute(path: RoutePaths.store, builder: (_, __) => const Text('STORE PAGE')),
      GoRoute(path: RoutePaths.exams, builder: (_, __) => const Text('EXAMS TAB')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      entitlementsProvider.overrideWith((ref) => Stream.value(ent)),
      billingModeProvider.overrideWithValue(mode),
    ],
    child: MaterialApp.router(
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(extensions: [AppTokens.light]),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}

/// BILL-EXT-01 / F3: in BILLING_MODE=external the home screen must not offer
/// a purchase or route to the store.
void main() {
  testWidgets('play build: an empty balance offers the store', (tester) async {
    await _pump(tester, _empty, BillingMode.play);
    expect(find.widgetWithText(ActionChip, 'Купить пробный экзамен'), findsOneWidget);
    await tester.tap(find.text('Купить пробный экзамен'));
    await tester.pumpAndSettle();
    expect(find.text('STORE PAGE'), findsOneWidget);
  });

  testWidgets('external build: neutral balance chip, not tappable, no store route',
      (tester) async {
    await _pump(tester, _empty, BillingMode.external);
    expect(find.textContaining('Купить'), findsNothing);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    final chip = find.byKey(const ValueKey('entitlement_balance_chip'));
    expect(chip, findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text('Нет доступных пробных экзаменов')),
        findsOneWidget);

    await tester.tap(chip, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('STORE PAGE'), findsNothing);
    expect(find.byKey(const ValueKey('entitlement_balance_chip')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('external build: credits still open the exams tab, never the store',
      (tester) async {
    await _pump(
      tester,
      const Entitlements(freeExamUsed: true, credits: 2, lifetimeCreditsPurchased: 2),
      BillingMode.external,
    );
    await tester.tap(find.text('Доступно пробных экзаменов: 2'));
    await tester.pumpAndSettle();
    expect(find.text('EXAMS TAB'), findsOneWidget);
    expect(find.text('STORE PAGE'), findsNothing);
  });

  test('canSellProvider is false only in BILLING_MODE=external', () {
    for (final (mode, sells) in [(BillingMode.play, true), (BillingMode.external, false)]) {
      final c = ProviderContainer(overrides: [billingModeProvider.overrideWithValue(mode)]);
      addTearDown(c.dispose);
      expect(c.read(canSellProvider), sells, reason: '$mode');
    }
  });
}
