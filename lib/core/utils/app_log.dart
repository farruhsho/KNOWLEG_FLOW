import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Non-fatal error reporting. Replaces the old `print('❌ ...')` pattern that
/// hid permission/index/schema failures: errors now reach Crashlytics (when
/// Firebase is up) and the debug console, and callers still surface a real
/// error state to the user.
void reportError(Object error, StackTrace? stack, {required String reason}) {
  debugPrint('[$reason] $error');
  try {
    if (Firebase.apps.isEmpty) return;
    if (kIsWeb) return; // Crashlytics has no web implementation.
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(error, stack, reason: reason, fatal: false)
          .catchError((Object _) {}),
    );
  } catch (_) {
    // Reporting must never throw (e.g. in unit tests without plugins).
  }
}
