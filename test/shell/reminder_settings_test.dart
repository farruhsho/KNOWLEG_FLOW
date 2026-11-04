import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/settings/data/reminder_settings.dart';
import 'package:knowledge_flow/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal FirebaseAuth stand-in: records sign-out, nothing else is used.
class _FakeAuth implements FirebaseAuth {
  _FakeAuth(this.log);
  final List<String> log;

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async => log.add('auth.signOut');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// AUTH-SET-01 / D12: the reminder stores and removes this device's token
/// on `users/{uid}`, and sign-out unregisters the device first.
void main() {
  // Google sign-out hits a platform channel; with a binding it fails fast
  // (and is ignored) instead of erroring on a missing binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('profilePatch (fields read by sendStudyReminders)', () {
    test('enabling adds the device token', () {
      final p = ReminderSettings.profilePatch(enabled: true, token: 'tok');
      expect(p['daily_reminder_enabled'], isTrue);
      expect(p['fcm_tokens'], FieldValue.arrayUnion(['tok']));
      expect(p['reminder_timezone'], 'Asia/Bishkek');
    });

    test('disabling removes the device token and turns the flag off', () {
      final p = ReminderSettings.profilePatch(enabled: false, token: 'tok');
      expect(p['daily_reminder_enabled'], isFalse);
      expect(p['fcm_tokens'], FieldValue.arrayRemove(['tok']));
      expect(p.containsKey('reminder_timezone'), isFalse);
    });

    test('without a token only the flag is written', () {
      expect(ReminderSettings.profilePatch(enabled: false), {'daily_reminder_enabled': false});
    });
  });

  group('per-account preference on a shared device', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('another account does not inherit the toggle', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(ReminderSettings.enabledKeyFor('a'), true);
      expect(ReminderSettings(prefs, 'a').enabled, isTrue);
      expect(ReminderSettings(prefs, 'b').enabled, isFalse);
      expect(ReminderSettings(prefs, null).enabled, isFalse);
    });

    test('the old device-level flag is adopted, then dropped on change', () async {
      SharedPreferences.setMockInitialValues({'daily_reminder_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final a = ReminderSettings(prefs, 'a');
      expect(a.enabled, isTrue);
      await a.disable();
      expect(a.enabled, isFalse);
      expect(prefs.containsKey('daily_reminder_enabled'), isFalse);
    });

    test('sign-out turns the reminder off for this device', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(ReminderSettings.enabledKeyFor('a'), true);
      await ReminderSettings(prefs, 'a').onSignOut();
      expect(ReminderSettings(prefs, 'a').enabled, isFalse);
    });
  });

  group('AuthService.signOut', () {
    test('runs the device clean-up before Firebase Auth signs out', () async {
      final log = <String>[];
      final service = AuthService(
        auth: _FakeAuth(log),
        beforeSignOut: () async => log.add('beforeSignOut'),
      );
      await service.signOut();
      expect(log, ['beforeSignOut', 'auth.signOut']);
    });

    test('a failing clean-up never blocks sign-out', () async {
      final log = <String>[];
      final service = AuthService(
        auth: _FakeAuth(log),
        beforeSignOut: () async => throw StateError('offline'),
      );
      await service.signOut();
      expect(log, ['auth.signOut']);
    });
  });
}
