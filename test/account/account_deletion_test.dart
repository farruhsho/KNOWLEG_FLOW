import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/account/domain/account_deletion.dart';

void main() {
  group('typed confirmation', () {
    test('matches the localized word, case-insensitively', () {
      expect(isDeleteConfirmationValid('УДАЛИТЬ', 'УДАЛИТЬ'), isTrue);
      expect(isDeleteConfirmationValid(' удалить ', 'УДАЛИТЬ'), isTrue);
      expect(isDeleteConfirmationValid('өчүрүү', 'ӨЧҮРҮҮ'), isTrue);
      expect(isDeleteConfirmationValid('delete', 'DELETE'), isTrue);
    });

    test('rejects anything else', () {
      expect(isDeleteConfirmationValid('', 'УДАЛИТЬ'), isFalse);
      expect(isDeleteConfirmationValid('УДАЛИ', 'УДАЛИТЬ'), isFalse);
      expect(isDeleteConfirmationValid('УДАЛИТЬ!', 'УДАЛИТЬ'), isFalse);
    });
  });

  group('re-auth methods', () {
    test('password needs an email; google from provider id', () {
      expect(reauthMethodsFor(['password'], email: 'a@b.kg'), [ReauthMethod.password]);
      expect(reauthMethodsFor(['password']), isEmpty);
      expect(reauthMethodsFor(['google.com']), [ReauthMethod.google]);
      expect(reauthMethodsFor(['password', 'google.com'], email: 'a@b.kg'),
          [ReauthMethod.password, ReauthMethod.google]);
      expect(reauthMethodsFor(['phone']), isEmpty);
    });
  });

  group('error mapping', () {
    test('Firebase Auth errors', () {
      AccountDeleteFailure m(String code) => AccountDeleteFailure.from(FirebaseAuthException(code: code));
      expect(m('wrong-password'), AccountDeleteFailure.wrongPassword);
      expect(m('invalid-credential'), AccountDeleteFailure.wrongPassword);
      expect(m('too-many-requests'), AccountDeleteFailure.tooManyRequests);
      expect(m('network-request-failed'), AccountDeleteFailure.network);
      expect(m('requires-recent-login'), AccountDeleteFailure.requiresRecentLogin);
      expect(m('user-mismatch'), AccountDeleteFailure.userMismatch);
      expect(m('something-else'), AccountDeleteFailure.unknown);
    });

    test('callable errors', () {
      AccountDeleteFailure m(String code, {Object? details, String message = ''}) => AccountDeleteFailure.from(
          FirebaseFunctionsException(code: code, message: message, details: details));
      expect(m('unauthenticated'), AccountDeleteFailure.requiresRecentLogin);
      expect(m('failed-precondition', details: {'reason': 'REQUIRES_RECENT_LOGIN'}),
          AccountDeleteFailure.requiresRecentLogin);
      expect(m('failed-precondition', message: 'Recent sign-in required'),
          AccountDeleteFailure.requiresRecentLogin);
      expect(m('unavailable'), AccountDeleteFailure.network);
      expect(m('not-found'), AccountDeleteFailure.serviceUnavailable);
      expect(m('internal'), AccountDeleteFailure.unknown);
    });

    test('Google sign-in errors', () {
      expect(AccountDeleteFailure.from(PlatformException(code: 'sign_in_canceled')), AccountDeleteFailure.canceled);
      expect(AccountDeleteFailure.from(PlatformException(code: 'network_error')), AccountDeleteFailure.network);
      expect(AccountDeleteFailure.from(PlatformException(code: 'sign_in_failed')), AccountDeleteFailure.googleFailed);
      expect(
        AccountDeleteFailure.from(const AccountDeleteException(AccountDeleteFailure.signedOut)),
        AccountDeleteFailure.signedOut,
      );
    });
  });
}
