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
      expect(isDeleteConfirmationValid('   ', 'УДАЛИТЬ'), isFalse);
      expect(isDeleteConfirmationValid('УДАЛИ', 'УДАЛИТЬ'), isFalse);
      expect(isDeleteConfirmationValid('УДАЛИТЬ!', 'УДАЛИТЬ'), isFalse);
      expect(isDeleteConfirmationValid('ОЧУР', 'ӨЧҮРҮҮ'), isFalse);
    });

    test('Kyrgyz word can be typed on a Russian keyboard (UX-10)', () {
      // Ө, Ү, Ң are missing from the ЙЦУКЕН layout: О, У, Н are accepted.
      expect(isDeleteConfirmationValid('ОЧУРУУ', 'ӨЧҮРҮҮ'), isTrue);
      expect(isDeleteConfirmationValid('очуруу', 'ӨЧҮРҮҮ'), isTrue);
      expect(isDeleteConfirmationValid('өчуруу', 'ӨЧҮРҮҮ'), isTrue);
      expect(normalizeDeleteConfirmation(' өчүрүү '), 'ОЧУРУУ');
      expect(normalizeDeleteConfirmation('ҢЁ'), 'НЕ');
      // Every character of the plain form exists on a Russian keyboard.
      const russianLayout = 'ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁ ';
      final plain = normalizeDeleteConfirmation('ӨЧҮРҮҮ');
      expect(plain.split('').every(russianLayout.contains), isTrue);
    });

    test('locale-independent words are accepted everywhere', () {
      expect(isDeleteConfirmationValid('delete', 'ӨЧҮРҮҮ'), isTrue);
      expect(isDeleteConfirmationValid('удалить', 'ӨЧҮРҮҮ'), isTrue);
      expect(isDeleteConfirmationValid('DELETE', 'УДАЛИТЬ'), isTrue);
      expect(isDeleteConfirmationValid('очуруу', 'DELETE'), isTrue);
    });

    test('plain-form hint only when the word has special letters', () {
      expect(deleteConfirmationPlainForm('ӨЧҮРҮҮ'), 'ОЧУРУУ');
      expect(deleteConfirmationPlainForm('УДАЛИТЬ'), isNull);
      expect(deleteConfirmationPlainForm('DELETE'), isNull);
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
      // D9: only the explicit reason starts the re-auth + retry path.
      expect(m('failed-precondition', details: {'reason': 'REQUIRES_RECENT_LOGIN'}),
          AccountDeleteFailure.requiresRecentLogin);
      // A bare `unauthenticated` (e.g. no App Check token) is not a
      // recent-login problem: re-auth would loop forever (SEC-APPCHECK-01).
      expect(m('unauthenticated'), AccountDeleteFailure.unauthenticated);
      expect(m('unauthenticated', details: {'reason': 'SOMETHING_ELSE'}),
          AccountDeleteFailure.unauthenticated);
      // No more guessing from the message text or legacy reason names.
      expect(m('failed-precondition', message: 'Recent sign-in required'), AccountDeleteFailure.unknown);
      expect(m('failed-precondition', details: {'reason': 'RECENT_LOGIN_REQUIRED'}),
          AccountDeleteFailure.unknown);
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
