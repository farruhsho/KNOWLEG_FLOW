import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/network/firebase_service.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run heavy initializations in parallel to reduce startup time
  await Future.wait([
    // Set preferred orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    // Initialize Hive for local storage
    Hive.initFlutter(),
  ]);

  // Initialize Firebase in the background after the app starts
  // This prevents blocking the UI thread
  FirebaseService.initialize().catchError((e) {
    debugPrint('Firebase initialization failed: $e');
    // Continue without Firebase for development
  });

  runApp(
    const ProviderScope(
      child: OrtMasterApp(),
    ),
  );
}

class OrtMasterApp extends ConsumerWidget {
  const OrtMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = AppRouter.createRouter();
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'ORT Master KG',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('ru', ''),
        Locale('ky', ''),
      ],
      locale: locale,

      // Routing
      routerConfig: router,
    );
  }
}
