import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/backend/callable_platform.dart';

void main() {
  group('callablesSupportedOn (App Check, D7)', () {
    test('mobile and macOS have an App Check provider', () {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]) {
        expect(callablesSupportedOn(isWeb: false, platform: p), isTrue, reason: '$p');
      }
    });

    test('Windows and Linux have none', () {
      for (final p in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.fuchsia]) {
        expect(callablesSupportedOn(isWeb: false, platform: p), isFalse, reason: '$p');
      }
    });

    test('web only with a reCAPTCHA Enterprise site key', () {
      expect(callablesSupportedOn(isWeb: true, platform: TargetPlatform.windows), isFalse);
      expect(callablesSupportedOn(isWeb: true, platform: TargetPlatform.android, webSiteKey: '  '), isFalse);
      expect(callablesSupportedOn(isWeb: true, platform: TargetPlatform.windows, webSiteKey: '6Lc_key'), isTrue);
    });
  });
}
