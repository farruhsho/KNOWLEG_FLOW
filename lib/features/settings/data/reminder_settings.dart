import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/firebase_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';

/// Result of trying to turn the daily reminder on.
enum ReminderEnableResult { enabled, permissionDenied, unsupported, failed }

/// Field names on `users/{uid}` read by the backend's `sendStudyReminders`
/// job (decision D12). Keep in sync with functions/src.
abstract final class ReminderFields {
  static const enabled = 'daily_reminder_enabled';
  static const tokens = 'fcm_tokens';
  static const timezone = 'reminder_timezone';
  static const bishkek = 'Asia/Bishkek';
}

/// Firebase side of [ReminderSettings]; replaced by a fake in tests.
class ReminderBackend {
  const ReminderBackend();

  /// Whether Firebase is up (no writes are attempted otherwise).
  bool get isReady => FirebaseService.isInitialized;

  /// This device's FCM registration token, or null.
  Future<String?> deviceToken() => FirebaseService.getFCMToken();

  /// Invalidates this device's FCM token.
  Future<void> deleteDeviceToken() => FirebaseService.deleteFCMToken();

  /// Merges [patch] into `users/{uid}`.
  Future<void> mergeProfile(String uid, Map<String, Object> patch) =>
      FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .set(patch, SetOptions(merge: true));

  void recordError(Object error, StackTrace stack) =>
      FirebaseService.recordNonFatal(error, stack, reason: 'reminder_sync');
}

/// Daily study reminder preference (GAM-13 client part, AUTH-SET-01).
///
/// The OS permission is requested only when the user turns the reminder on
/// (Settings or the dashboard card), never at start-up. When enabled, the
/// device's FCM token and the preference are stored on `users/{uid}`; the
/// scheduled `sendStudyReminders` function sends the reminder to every token
/// of an account whose `daily_reminder_enabled` is true.
///
/// `daily_reminder_enabled` is account-wide. Turning the reminder on sets it
/// ([enable], or [refreshRegistration] re-registering a rotated token on a
/// device where it is on); only the explicit switch in Settings ([disable])
/// clears it. Signing out only removes this device's token from
/// `fcm_tokens` (REM-01), so a shared device never gets another account's
/// reminders while the account's other devices keep theirs.
class ReminderSettings {
  ReminderSettings(this._prefs, this._uid, {ReminderBackend backend = const ReminderBackend()})
      : _backend = backend;

  final SharedPreferences _prefs;
  final String? _uid;
  final ReminderBackend _backend;

  /// Device-level key used before the preference was scoped per account.
  static const _legacyEnabledKey = 'daily_reminder_enabled';
  static const _promptDismissedKey = 'daily_reminder_prompt_dismissed';

  /// The preference is per account on this device: another account signing
  /// in here does not inherit it.
  static String enabledKeyFor(String uid) => '$_legacyEnabledKey:$uid';

  bool get enabled {
    final uid = _uid;
    if (uid == null) return false;
    // Builds that stored a device-level flag: it belongs to the account that
    // is signed in now (it is dropped on the next change or sign-out).
    return _prefs.getBool(enabledKeyFor(uid)) ?? _prefs.getBool(_legacyEnabledKey) ?? false;
  }

  Future<void> _setEnabled(bool value) async {
    await _prefs.remove(_legacyEnabledKey);
    final uid = _uid;
    if (uid == null) return;
    await _prefs.setBool(enabledKeyFor(uid), value);
  }

  /// Whether the dashboard should still offer to enable reminders.
  bool get shouldPrompt =>
      !enabled &&
      !(_prefs.getBool(_promptDismissedKey) ?? false) &&
      FirebaseService.supportsMessaging;

  Future<void> dismissPrompt() => _prefs.setBool(_promptDismissedKey, true);

  Future<ReminderEnableResult> enable() async {
    if (!FirebaseService.supportsMessaging) {
      return ReminderEnableResult.unsupported;
    }
    final permission = await FirebaseService.requestNotificationPermission();
    switch (permission) {
      case NotificationPermissionResult.granted:
        break;
      case NotificationPermissionResult.denied:
        return ReminderEnableResult.permissionDenied;
      case NotificationPermissionResult.unsupported:
        return ReminderEnableResult.unsupported;
      case NotificationPermissionResult.error:
        return ReminderEnableResult.failed;
    }
    await _setEnabled(true);
    await _prefs.setBool(_promptDismissedKey, true);
    await _syncToProfile(enabled: true);
    FirebaseService.logEvent('reminder_enabled');
    return ReminderEnableResult.enabled;
  }

  /// The explicit account-wide switch (Settings): turns the reminder off for
  /// the account (`daily_reminder_enabled: false`) and removes this device's
  /// token.
  Future<void> disable() async {
    await _setEnabled(false);
    await _syncToProfile(enabled: false);
  }

  /// Runs before sign-out (AuthService): if this device receives the
  /// account's reminders, remove only this device's token from `fcm_tokens`
  /// ([signOutPatch]). `daily_reminder_enabled` is left alone: it is
  /// account-wide, and the account's other devices keep getting reminders
  /// (REM-01). Best-effort and bounded in time so sign-out never hangs
  /// offline (the write stays queued for the account).
  Future<void> onSignOut() async {
    if (!enabled) return;
    // This device stops receiving this account's reminder; after signing in
    // again the toggle shows off here until the user turns it back on.
    await _setEnabled(false);
    // Whoever signs in next re-registers their own (new) token.
    _refreshedThisSession = false;
    final uid = _uid;
    if (uid != null) {
      await _prefs.remove('$_registeredTokenKey:$uid');
      if (_backend.isReady) {
        final token = await _deviceToken();
        if (token != null) {
          await _write(uid, signOutPatch(token), const Duration(seconds: 3),
              registeredToken: null);
        }
      }
    }
    // Invalidate the token itself too, in case the write above only reaches
    // the server after this account signs in again.
    await _backend.deleteDeviceToken();
  }

  /// Fields written to `users/{uid}` on sign-out (pure, for tests): only
  /// this device's [token] is removed, never `daily_reminder_enabled`.
  static Map<String, Object> signOutPatch(String token) => {
        ReminderFields.tokens: FieldValue.arrayRemove([token]),
      };

  /// Fields the explicit toggle writes to `users/{uid}` (pure, for tests).
  /// Enabling adds this device's [token]; disabling turns the account-wide
  /// flag off and removes the token. Sign-out uses [signOutPatch] instead.
  static Map<String, Object> profilePatch({required bool enabled, String? token}) {
    if (enabled) {
      return {
        ReminderFields.enabled: true,
        if (token != null) ReminderFields.tokens: FieldValue.arrayUnion([token]),
        ReminderFields.timezone: ReminderFields.bishkek,
      };
    }
    return {
      ReminderFields.enabled: false,
      if (token != null) ReminderFields.tokens: FieldValue.arrayRemove([token]),
    };
  }

  static const _registeredTokenKey = 'daily_reminder_token';
  static bool _refreshedThisSession = false;

  /// FCM tokens rotate and the backend prunes invalid ones, so while the
  /// reminder is on, re-register this device's current token once per app
  /// session (a write only when the token changed).
  Future<void> refreshRegistration() async {
    final uid = _uid;
    if (_refreshedThisSession || uid == null || !enabled) return;
    if (!_backend.isReady || !FirebaseService.supportsMessaging) return;
    _refreshedThisSession = true;
    final token = await _deviceToken();
    if (token == null || _prefs.getString('$_registeredTokenKey:$uid') == token) return;
    await _write(uid, profilePatch(enabled: true, token: token), const Duration(seconds: 8),
        registeredToken: token);
  }

  Future<void> _syncToProfile({
    required bool enabled,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uid = _uid;
    if (uid == null || !_backend.isReady) return;
    final token = await _deviceToken();
    await _write(uid, profilePatch(enabled: enabled, token: token), timeout,
        registeredToken: enabled ? token : null);
  }

  Future<String?> _deviceToken() => _backend
      .deviceToken()
      .timeout(const Duration(seconds: 5), onTimeout: () => null);

  Future<void> _write(
    String uid,
    Map<String, Object> patch,
    Duration timeout, {
    required String? registeredToken,
  }) async {
    try {
      await _backend.mergeProfile(uid, patch).timeout(timeout);
      final key = '$_registeredTokenKey:$uid';
      if (registeredToken == null) {
        await _prefs.remove(key);
      } else {
        await _prefs.setString(key, registeredToken);
      }
    } catch (e, s) {
      _backend.recordError(e, s);
    }
  }
}

final reminderSettingsProvider = Provider<ReminderSettings>((ref) {
  return ReminderSettings(
    ref.watch(sharedPreferencesProvider),
    ref.watch(currentUidProvider),
  );
});

/// Current toggle state; invalidate after changing it.
final reminderEnabledProvider = Provider<bool>(
  (ref) => ref.watch(reminderSettingsProvider).enabled,
);
