import 'package:flutter/foundation.dart';

/// reCAPTCHA Enterprise site key for App Check on web
/// (`--dart-define=APP_CHECK_WEB_SITE_KEY=...`). Empty = App Check is not
/// activated on web (ARCHITECTURE §3, decision D7).
const String appCheckWebSiteKey = String.fromEnvironment('APP_CHECK_WEB_SITE_KEY');

/// Whether this build can obtain an App Check token, which every student
/// callable (`examStart`, `aiTutor`, `accountDelete`, `billingVerifyPurchase`,
/// …) requires while `APP_CHECK_ENFORCE` is on (the default).
///
/// * Android / iOS / macOS: Play Integrity / App Attest (debug providers in
///   debug builds).
/// * Web: only when [appCheckWebSiteKey] was provided at build time.
/// * Windows / Linux: FlutterFire has no App Check provider, so these
///   features show a "not available on this platform" state instead of
///   failing with `unauthenticated`.
bool get callablesSupportedOnThisPlatform =>
    kUseFirebaseEmulators ||
    callablesSupportedOn(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
      webSiteKey: appCheckWebSiteKey,
    );

/// Local development against the Firebase emulators
/// (`--dart-define=USE_FIREBASE_EMULATORS=true`). The app then talks only to
/// the emulator project [kFirebaseEmulatorProject] (a `demo-*` id, which can
/// never reach real Firebase services); App Check is off there
/// (functions/.env.demo-ort-e2e), so callables work on every platform.
const bool kUseFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
const String kFirebaseEmulatorProject = 'demo-ort-e2e';

/// Emulator host: `localhost` for desktop/web, `10.0.2.2` for the Android
/// emulator (`--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`).
const String kFirebaseEmulatorHost =
    String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

/// Pure form of [callablesSupportedOnThisPlatform], for tests.
bool callablesSupportedOn({
  required bool isWeb,
  required TargetPlatform platform,
  String webSiteKey = '',
}) {
  if (isWeb) return webSiteKey.trim().isNotEmpty;
  switch (platform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}
