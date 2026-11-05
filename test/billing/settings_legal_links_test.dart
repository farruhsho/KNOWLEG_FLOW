import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';
import 'package:knowledge_flow/features/billing/application/billing_providers.dart';
import 'package:knowledge_flow/features/billing/domain/billing_mode.dart';
import 'package:knowledge_flow/features/legal/legal_routes.dart';
import 'package:knowledge_flow/features/settings/data/reminder_settings.dart';
import 'package:knowledge_flow/features/settings/presentation/pages/settings_page.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The public offer and refund policy are reachable from settings only in
/// the web build (site payments); never in play / external builds.
void main() {
  Future<void> pumpSettings(WidgetTester tester, BillingMode mode) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: RoutePaths.settings,
      routes: [
        GoRoute(path: RoutePaths.settings, builder: (_, __) => const SettingsPage()),
        ...legalRoutes,
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocaleProvider.overrideWithValue(const Locale('ru')),
        reminderEnabledProvider.overrideWithValue(false),
        billingModeProvider.overrideWithValue(mode),
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
  }

  testWidgets('web: offer and refund policy open as in-app pages', (tester) async {
    await pumpSettings(tester, BillingMode.web);
    final offer = find.byKey(const ValueKey('settings_legal_offer'));
    await tester.scrollUntilVisible(offer, 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('settings_legal_refund')), findsOneWidget);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings_legal_refund')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal_draft_note')), findsOneWidget);
    expect(find.text('Правила возврата'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final mode in [BillingMode.play, BillingMode.external]) {
    testWidgets('${mode.name}: no payment terms in settings', (tester) async {
      await pumpSettings(tester, mode);
      expect(find.byKey(const ValueKey('settings_legal_offer')), findsNothing);
      expect(find.byKey(const ValueKey('settings_legal_refund')), findsNothing);
      expect(find.text('Публичная оферта'), findsNothing);
    });
  }
}
