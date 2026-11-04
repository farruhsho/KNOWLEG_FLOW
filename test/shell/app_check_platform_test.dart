import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/network/firebase_service.dart';

/// SEC-APPCHECK-01 / D7: App Check (and therefore the student callables)
/// is available on Android/iOS/macOS, on web only with a reCAPTCHA
/// Enterprise site key, and never on Windows/Linux.
void main() {
  test('web needs a site key', () {
    expect(FirebaseService.appCheckAvailable(isWeb: true, platform: TargetPlatform.android, webSiteKey: ''), isFalse);
    expect(FirebaseService.appCheckAvailable(isWeb: true, platform: TargetPlatform.windows, webSiteKey: '  '), isFalse);
    expect(FirebaseService.appCheckAvailable(isWeb: true, platform: TargetPlatform.windows, webSiteKey: '6Lc_key'), isTrue);
  });

  test('native platforms', () {
    for (final p in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]) {
      expect(FirebaseService.appCheckAvailable(isWeb: false, platform: p, webSiteKey: ''), isTrue, reason: '$p');
    }
    for (final p in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.fuchsia]) {
      expect(FirebaseService.appCheckAvailable(isWeb: false, platform: p, webSiteKey: 'key'), isFalse, reason: '$p');
    }
  });

  test('supportsCallables follows the running platform', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(FirebaseService.supportsCallables, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(FirebaseService.supportsCallables, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(FirebaseService.supportsCallables, isTrue);
    expect(FirebaseService.supportsCallables, FirebaseService.supportsAppCheck);
  });
}
