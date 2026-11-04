import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/core/routes/app_router.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';
import 'package:knowledge_flow/features/billing/domain/entitlements.dart';
import 'package:knowledge_flow/features/dashboard/data/dashboard_providers.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/providers/auth_provider.dart';
import 'package:knowledge_flow/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the real router + shell with every Firebase-backed provider
/// replaced by an in-memory value.
Future<GoRouter> pumpShell(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  SharedPreferences.setMockInitialValues({LocalePrefsKeys.current: 'ru'});
  final prefs = await SharedPreferences.getInstance();
  final router = AppRouter.createRouter(
    isSignedIn: () => true,
    adminSession: ValueNotifier<bool>(false),
    initialLocation: RoutePaths.home,
    enableAnalytics: false,
  );
  addTearDown(router.dispose);

  final theme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    extensions: [
      brightness == Brightness.dark ? AppTokens.dark : AppTokens.light,
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        userModelProvider.overrideWith((ref) => Stream.value(null)),
        userStatsProvider.overrideWith((ref) => Stream.value(null)),
        latestExamProvider.overrideWith((ref) => Stream.value(null)),
        entitlementsProvider
            .overrideWith((ref) => Stream.value(Entitlements.initial)),
        examResumeBannerBuilderProvider
            .overrideWithValue(() => const SizedBox.shrink()),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: theme,
          locale: ref.watch(localeProvider),
          supportedLocales: const [Locale('ru'), Locale('ky'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

int selectedTab(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  testWidgets('shell renders five destinations and the real home screen',
      (tester) async {
    setPhoneSize(tester);
    await pumpShell(tester);

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final label in ['Главная', 'Учёба', 'Экзамены', 'Прогресс', 'Профиль']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(selectedTab(tester), 0);

    // Honest empty state + first-mock recommendation for a new user.
    expect(find.text('Привет!'), findsOneWidget);
    expect(find.text('Начните серию сегодня'), findsOneWidget);
    expect(find.text('Следующий шаг'), findsOneWidget);
    expect(find.text('Доступен бесплатный пробный экзамен'), findsOneWidget);
    // No fabricated numbers from the old dashboard.
    expect(find.text('145'), findsNothing);
    expect(find.text('+12%'), findsNothing);
  });

  testWidgets('back on a secondary tab returns to Home; on Home it asks first',
      (tester) async {
    setPhoneSize(tester);
    await pumpShell(tester);

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 4);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Выйти из приложения?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из приложения?'), findsNothing);
    expect(selectedTab(tester), 0);
  });

  testWidgets('legacy /dashboard link lands on the home tab', (tester) async {
    setPhoneSize(tester);
    final router = await pumpShell(tester);

    router.go(RoutePaths.exams);
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 2);

    router.go('/dashboard');
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 0);
    expect(find.text('Страница не найдена'), findsNothing);
  });

  testWidgets('quiz results without extra does not crash', (tester) async {
    setPhoneSize(tester);
    final router = await pumpShell(tester);
    router.go(RoutePaths.quizResults);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(selectedTab(tester), 0);
  });

  testWidgets('home renders in dark mode on a small phone', (tester) async {
    setPhoneSize(tester);
    await pumpShell(tester, brightness: Brightness.dark);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Справочник'), findsOneWidget);
  });
}
