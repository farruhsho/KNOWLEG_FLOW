import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/firebase_service.dart';
import '../features/onboarding/domain/onboarding_answers.dart';
import 'locale_provider.dart';

/// Onboarding state, persisted in SharedPreferences.
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(ref.watch(sharedPreferencesProvider));
});

/// Whether the intro/questionnaire was completed (or skipped) on this device.
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  return ref.watch(onboardingServiceProvider).isCompleted;
});

class OnboardingService {
  OnboardingService(this._prefs);

  final SharedPreferences _prefs;

  static const String _onboardingKey = 'onboarding_completed';
  static const String _pendingKey = 'onboarding_pending_answers_v1';

  bool get isCompleted => _prefs.getBool(_onboardingKey) ?? false;

  Future<bool> isOnboardingCompleted() async => isCompleted;

  Future<void> setOnboardingCompleted() =>
      _prefs.setBool(_onboardingKey, true);

  Future<void> resetOnboarding() => _prefs.setBool(_onboardingKey, false);

  /// Answers waiting to be written to `users/{uid}` (null if none).
  OnboardingAnswers? get pendingAnswers {
    final raw = _prefs.getString(_pendingKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return OnboardingAnswers.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> savePendingAnswers(OnboardingAnswers answers) =>
      _prefs.setString(_pendingKey, jsonEncode(answers.toJson()));

  Future<void> clearPendingAnswers() => _prefs.remove(_pendingKey);

  /// Writes the pending answers to `users/{uid}` (merge) and clears them.
  /// Returns true when there was nothing to do or the write succeeded.
  /// Never throws: a failed write stays pending for the next sign-in/start.
  Future<bool> flushPendingAnswers(
    String uid, {
    FirebaseFirestore? firestore,
  }) async {
    final answers = pendingAnswers;
    if (answers == null) return true;
    try {
      final db = firestore ?? FirebaseService.firestore;
      // Offline the write is queued by Firestore and the future does not
      // complete; keep the answers pending and retry on the next start.
      await db
          .collection('users')
          .doc(uid)
          .set(answers.toUserFields(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
      await clearPendingAnswers();
      FirebaseService.logEvent('onboarding_saved');
      return true;
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'onboarding_flush');
      return false;
    }
  }
}
