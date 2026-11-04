import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';

/// Outcome of asking the OS for notification permission.
enum NotificationPermissionResult { granted, denied, unsupported, error }

/// Firebase bootstrap plus small, failure-tolerant wrappers around the
/// Firebase singletons.
///
/// Startup contract (BOOT-01 / BOOT-02 / GAM-13 / GAM-14 / GAM-15):
///  * [initialize] awaits only what must exist before the first Firebase
///    call: `Firebase.initializeApp`, Firestore settings, App Check and the
///    crash handlers. It has a timeout and throws on failure so the boot
///    screen can show an error with a retry button instead of hanging.
///  * Remote Config is fetched after the first frame ([runDeferredStartupTasks]).
///  * Notification permission is never requested at startup; Settings and the
///    dashboard reminder card call [requestNotificationPermission] in context.
class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;

  /// True once [initialize] completed successfully.
  static bool get isInitialized => _initialized;

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
  static FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  static FirebaseCrashlytics get crashlytics => FirebaseCrashlytics.instance;
  static FirebaseMessaging get messaging => FirebaseMessaging.instance;
  static FirebaseRemoteConfig get remoteConfig => FirebaseRemoteConfig.instance;

  static bool get _isMobileOrMac =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Crashlytics only has Android/Apple implementations.
  static bool get supportsCrashlytics => _isMobileOrMac;

  /// reCAPTCHA Enterprise site key for App Check on web, passed with
  /// `--dart-define=APP_CHECK_WEB_SITE_KEY=<key>` (registered in the Firebase
  /// console). Empty = App Check is not activated on web.
  static const String appCheckWebSiteKey =
      String.fromEnvironment('APP_CHECK_WEB_SITE_KEY');

  /// Whether App Check can be activated on [platform] (pure, for tests).
  /// Android/iOS/macOS have attestation providers; web needs a site key;
  /// Windows/Linux have no provider (decision D7).
  static bool appCheckAvailable({
    required bool isWeb,
    required TargetPlatform platform,
    String webSiteKey = appCheckWebSiteKey,
  }) {
    if (isWeb) return webSiteKey.trim().isNotEmpty;
    return platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS;
  }

  /// App Check: mobile/macOS always; web only with [appCheckWebSiteKey].
  static bool get supportsAppCheck =>
      appCheckAvailable(isWeb: kIsWeb, platform: defaultTargetPlatform);

  /// Whether this build can use the **student** callables (examStart and the
  /// other exam* functions, aiTutor, recordActivity, billingVerifyPurchase,
  /// accountDelete). The backend enforces App Check on them, so without an
  /// App Check provider every call is rejected. Features backed by these
  /// callables should show a "not available on this platform" state when
  /// this is false instead of failing (SEC-APPCHECK-01 / D7).
  ///
  /// Admin callables (admin*) do not enforce App Check by default
  /// (APP_CHECK_ENFORCE_ADMIN) and need no such gate.
  static bool get supportsCallables => supportsAppCheck;

  /// Analytics has Android/Apple/web implementations.
  static bool get supportsAnalytics => kIsWeb || _isMobileOrMac;

  /// Push notifications (web would also need a VAPID key + service worker).
  static bool get supportsMessaging => _isMobileOrMac;

  static bool get supportsRemoteConfig => kIsWeb || _isMobileOrMac;

  static bool get _crashReportingEnabled =>
      _initialized && supportsCrashlytics && !kDebugMode;

  /// Initializes Firebase. Safe to call again after a failure (retry).
  static Future<void> initialize({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_initialized) return;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(timeout);
    }

    try {
      // Offline persistence. Must be set before the first Firestore call.
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore settings were not applied: $e');
    }

    await _activateAppCheck();
    await _setUpCrashReporting();

    _initialized = true;

    final pending = _pendingStartupError;
    if (pending != null) {
      _pendingStartupError = null;
      recordNonFatal(pending.$1, pending.$2, reason: 'app_check_activate');
    }
  }

  static Future<void> _activateAppCheck() async {
    if (!supportsAppCheck) return;
    try {
      await FirebaseAppCheck.instance.activate(
        providerWeb: kIsWeb ? ReCaptchaEnterpriseProvider(appCheckWebSiteKey) : null,
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
      );
    } catch (e, s) {
      // Never block startup on App Check: callables will report it instead.
      debugPrint('App Check activation failed: $e');
      _pendingStartupError = (e, s);
    }
  }

  static (Object, StackTrace)? _pendingStartupError;

  static Future<void> _setUpCrashReporting() async {
    if (!supportsCrashlytics) {
      _installDebugOnlyHandlers();
      return;
    }
    try {
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    } catch (e) {
      debugPrint('Crashlytics could not be configured: $e');
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (!_crashReportingEnabled) return;
      // Framework errors (layout overflow, GoError, …) are non-fatal.
      unawaited(crashlytics.recordFlutterError(details));
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_crashReportingEnabled) {
        unawaited(crashlytics.recordError(error, stack, fatal: true));
      } else {
        debugPrint('Uncaught async error: $error\n$stack');
      }
      return true;
    };
  }

  static void _installDebugOnlyHandlers() {
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('Uncaught async error: $error\n$stack');
      return true;
    };
  }

  /// Reports a handled failure. Never throws.
  static void recordNonFatal(Object error, StackTrace? stack, {String? reason}) {
    debugPrint('Non-fatal${reason == null ? '' : ' ($reason)'}: $error');
    if (!_crashReportingEnabled) return;
    try {
      unawaited(crashlytics.recordError(error, stack, reason: reason));
    } catch (_) {}
  }

  /// Tags crash reports with the signed-in user (null clears it).
  static void setUserIdentifier(String? uid) {
    if (!_crashReportingEnabled) return;
    try {
      unawaited(crashlytics.setUserIdentifier(uid ?? ''));
    } catch (_) {}
  }

  /// Work that must not delay the first frame. Called once after it.
  static void runDeferredStartupTasks() {
    if (!_initialized) return;
    unawaited(_initializeRemoteConfig());
  }

  static Future<void> _initializeRemoteConfig() async {
    if (!supportsRemoteConfig) return;
    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults(const {
        'next_ort_date': '',
        'registration_url': 'https://testing.kg',
        'show_announcement': false,
        'announcement_text': '',
      });
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config fetch skipped: $e');
    }
  }

  /// Asks for notification permission. Call only from a user action.
  static Future<NotificationPermissionResult>
      requestNotificationPermission() async {
    if (!_initialized || !supportsMessaging) {
      return NotificationPermissionResult.unsupported;
    }
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return NotificationPermissionResult.granted;
        case AuthorizationStatus.denied:
        case AuthorizationStatus.deniedPermanently:
        case AuthorizationStatus.notDetermined:
          return NotificationPermissionResult.denied;
      }
    } catch (e, s) {
      recordNonFatal(e, s, reason: 'notification_permission');
      return NotificationPermissionResult.error;
    }
  }

  static Future<String?> getFCMToken() async {
    if (!_initialized || !supportsMessaging) return null;
    try {
      // The registration-token API is deprecated in favour of FID-based
      // register()/onRegistered, which needs FCM direct-send support on the
      // backend. The reminder job (sendStudyReminders) targets registration
      // tokens, so keep using them until the backend moves to FIDs.
      // ignore: deprecated_member_use
      return await messaging.getToken();
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
      return null;
    }
  }

  /// Invalidates this device's FCM registration token (sign-out on a shared
  /// device). Best-effort, never throws, bounded in time.
  static Future<void> deleteFCMToken() async {
    if (!_initialized || !supportsMessaging) return;
    try {
      // Registration-token API, same as getFCMToken (see the note there).
      // ignore: deprecated_member_use
      await messaging.deleteToken().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('FCM token not deleted: $e');
    }
  }

  /// A screen-view observer for one navigator, or null where Analytics is
  /// unavailable. Each navigator needs its own instance.
  static NavigatorObserver? createAnalyticsObserver() {
    if (!_initialized || !supportsAnalytics) return null;
    try {
      return FirebaseAnalyticsObserver(
        analytics: analytics,
        onError: (e) => debugPrint('Analytics observer error: $e'),
      );
    } catch (e) {
      debugPrint('Analytics observer unavailable: $e');
      return null;
    }
  }

  static void logScreenView(String screenName) {
    if (!_initialized || !supportsAnalytics) return;
    try {
      unawaited(analytics.logScreenView(screenName: screenName));
    } catch (_) {}
  }

  static void logEvent(String name, [Map<String, Object>? parameters]) {
    if (!_initialized || !supportsAnalytics) return;
    try {
      unawaited(analytics.logEvent(name: name, parameters: parameters));
    } catch (_) {}
  }
}
