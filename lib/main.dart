import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/navigation/boot_screens.dart';
import 'core/navigation/route_guards.dart';
import 'core/navigation/router_refresh.dart';
import 'core/network/firebase_service.dart';
import 'core/routes/admin_session.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/billing/billing_routes.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read before anything renders: the boot screen's MaterialApp reports '/'
  // to the browser and would wipe a `#/…` deep link (RouteGuards.coldStartLocation).
  final initialRoute =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;

  // Both are local and fast; everything that touches the network runs after
  // the first frame (BOOT-01).
  final sharedPreferences = await SharedPreferences.getInstance();
  // Hive backs the exam package's offline answer store (box 'exam_sessions').
  await Hive.initFlutter();

  unawaited(SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]));

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        initialRouteProvider.overrideWithValue(initialRoute),
      ],
      child: const OrtMasterApp(),
    ),
  );
}

/// Firebase bootstrap. The app shows a branded boot screen while it runs and
/// an error screen with "Retry" if it fails (BOOT-02) instead of hanging on a
/// spinner. Retry = `ref.invalidate(firebaseBootstrapProvider)`.
final firebaseBootstrapProvider = FutureProvider<void>((ref) async {
  await FirebaseService.initialize();
  // Remote Config etc. must never delay the first real frame.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => FirebaseService.runDeferredStartupTasks(),
  );
});

/// The router must be created exactly once. Re-creating it inside build()
/// (as before) reset the whole navigation stack to the splash screen every
/// time the locale or theme changed. It is first read only after Firebase is
/// initialized, so the auth guard can use FirebaseAuth safely.
/// The platform's initial route, captured in main() before the boot screen.
final initialRouteProvider = Provider<String?>((ref) => null);

final appRouterProvider = Provider<GoRouter>((ref) {
  final authChanges = StreamListenable(FirebaseService.auth.authStateChanges());
  final router = AppRouter.createRouter(
    refreshListenable: Listenable.merge([authChanges, adminVerified]),
    initialLocation: RouteGuards.coldStartLocation(ref.read(initialRouteProvider)),
  );
  ref.onDispose(() {
    router.dispose();
    authChanges.dispose();
  });
  return router;
});

const List<LocalizationsDelegate<dynamic>> kAppLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const List<Locale> kAppSupportedLocales = [
  Locale('ru'),
  Locale('ky'),
  Locale('en'),
];

class OrtMasterApp extends ConsumerWidget {
  const OrtMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(firebaseBootstrapProvider);
    if (boot.isLoading) {
      return const _BootApp(child: BootSplashScreen());
    }
    if (boot.hasError) {
      return _BootApp(
        child: BootErrorScreen(
          onRetry: () => ref.invalidate(firebaseBootstrapProvider),
        ),
      );
    }
    return const _RouterApp();
  }
}

class _RouterApp extends ConsumerWidget {
  const _RouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'ORT Master KG',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: kAppLocalizationsDelegates,
      supportedLocales: kAppSupportedLocales,
      locale: locale,
      routerConfig: router,
      builder: (context, child) =>
          wrapWithBillingListener(child ?? const SizedBox.shrink()),
    );
  }
}

/// Minimal app used before the router exists (boot splash / boot error).
class _BootApp extends ConsumerWidget {
  const _BootApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ORT Master KG',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeProvider),
      localizationsDelegates: kAppLocalizationsDelegates,
      supportedLocales: kAppSupportedLocales,
      locale: ref.watch(localeProvider),
      home: child,
    );
  }
}
