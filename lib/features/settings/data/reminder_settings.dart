import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/firebase_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';

/// Result of trying to turn the daily reminder on.
enum ReminderEnableResult { enabled, permissionDenied, unsupported, failed }

/// Daily study reminder preference (GAM-13, client part).
///
/// The OS permission is requested only when the user turns the reminder on
/// (Settings or the dashboard card), never at start-up. When enabled, the
/// device's FCM token and the preference are stored on `users/{uid}` so a
/// scheduled backend job can send the reminder.
class ReminderSettings {
  ReminderSettings(this._prefs, this._uid);

  final SharedPreferences _prefs;
  final String? _uid;

  static const _enabledKey = 'daily_reminder_enabled';
  static const _promptDismissedKey = 'daily_reminder_prompt_dismissed';

  bool get enabled => _prefs.getBool(_enabledKey) ?? false;

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
    await _prefs.setBool(_enabledKey, true);
    await _prefs.setBool(_promptDismissedKey, true);
    await _syncToProfile(enabled: true);
    FirebaseService.logEvent('reminder_enabled');
    return ReminderEnableResult.enabled;
  }

  Future<void> disable() async {
    await _prefs.setBool(_enabledKey, false);
    await _syncToProfile(enabled: false);
  }

  Future<void> _syncToProfile({required bool enabled}) async {
    final uid = _uid;
    if (uid == null || !FirebaseService.isInitialized) return;
    try {
      final token = enabled ? await FirebaseService.getFCMToken() : null;
      await FirebaseService.firestore.collection('users').doc(uid).set(
        {
          'daily_reminder_enabled': enabled,
          if (token != null) 'fcm_tokens': FieldValue.arrayUnion([token]),
          'reminder_timezone': 'Asia/Bishkek',
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 8));
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'reminder_sync');
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
