import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../../core/backend/backend_contract.dart';

/// How the user can prove it is them before deletion.
enum ReauthMethod { password, google }

/// Sign-in methods available for re-authentication, from Firebase
/// `providerData[].providerId`.
List<ReauthMethod> reauthMethodsFor(Iterable<String> providerIds, {String? email}) {
  final ids = providerIds.toSet();
  return [
    if (ids.contains(EmailAuthProvider.PROVIDER_ID) && (email?.isNotEmpty ?? false)) ReauthMethod.password,
    if (ids.contains(GoogleAuthProvider.PROVIDER_ID)) ReauthMethod.google,
  ];
}

/// Kyrgyz letters that a standard Russian (ЙЦУКЕН) keyboard lacks, mapped to
/// the plain Cyrillic letter people type instead (UX-10).
const Map<String, String> _plainLetters = {
  'Ө': 'О',
  'Ү': 'У',
  'Ң': 'Н',
  'Ё': 'Е',
};

/// Upper-cases [s], drops surrounding spaces, collapses inner whitespace and
/// replaces Ө/Ү/Ң/Ё with О/У/Н/Е, so the Kyrgyz word can be typed on a
/// Russian keyboard.
String normalizeDeleteConfirmation(String s) {
  final upper = s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  final out = StringBuffer();
  for (final rune in upper.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_plainLetters[ch] ?? ch);
  }
  return out.toString();
}

/// Confirmation words accepted in every locale, so a user is never stuck on
/// a keyboard layout: the English and Russian words and the Kyrgyz one.
const Set<String> deleteConfirmationWordsAnyLocale = {'DELETE', 'УДАЛИТЬ', 'ӨЧҮРҮҮ'};

/// Typed confirmation: case-insensitive, surrounding spaces ignored, Kyrgyz
/// letters may be typed as their Russian-keyboard look-alikes (ОЧУРУУ for
/// ӨЧҮРҮҮ). The localized [word] and [deleteConfirmationWordsAnyLocale] are
/// accepted.
bool isDeleteConfirmationValid(String typed, String word) {
  final a = normalizeDeleteConfirmation(typed);
  if (a.isEmpty) return false;
  if (a == normalizeDeleteConfirmation(word)) return true;
  return deleteConfirmationWordsAnyLocale.any((w) => a == normalizeDeleteConfirmation(w));
}

/// The Russian-keyboard spelling of [word] when it differs from [word]
/// (e.g. ОЧУРУУ for ӨЧҮРҮҮ), else null. Shown as a hint under the field.
String? deleteConfirmationPlainForm(String word) {
  final plain = normalizeDeleteConfirmation(word);
  return plain == word.trim().toUpperCase() ? null : plain;
}

enum AccountDeleteFailure {
  wrongPassword,
  tooManyRequests,
  network,

  /// The server wants a sign-in from the last few minutes
  /// (`details.reason == REQUIRES_RECENT_LOGIN`, decision D9), or Firebase
  /// Auth itself asked for one.
  requiresRecentLogin,

  /// The callable answered `unauthenticated`: the session or the App Check
  /// token was not accepted. Not a recent-login problem, so no re-auth loop.
  unauthenticated,
  userMismatch,
  canceled,
  googleFailed,
  serviceUnavailable,
  signedOut,
  unknown;

  /// `details.reason` of `accountDelete` when the sign-in is too old (D9).
  /// Must equal the REQUIRES_RECENT_LOGIN entry of `BackendReasons` and
  /// functions/src/domain/reasons.ts.
  static const requiresRecentLoginReason = 'REQUIRES_RECENT_LOGIN';

  static AccountDeleteFailure from(Object e) {
    if (e is AccountDeleteException) return e.failure;
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
        case 'missing-password':
          return wrongPassword;
        case 'too-many-requests':
          return tooManyRequests;
        case 'network-request-failed':
          return network;
        case 'requires-recent-login':
        case 'user-token-expired':
        case 'credential-too-old-login-again':
          return requiresRecentLogin;
        case 'user-mismatch':
          return userMismatch;
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
        case 'web-context-canceled':
          return canceled;
        case 'user-not-found':
        case 'no-current-user':
          return signedOut;
      }
      return unknown;
    }
    if (e is FirebaseFunctionsException) {
      // Only the explicit reason triggers re-auth + retry. A bare
      // `unauthenticated` (e.g. a missing App Check token on web/desktop)
      // can't be fixed by signing in again and must not loop.
      if (BackendReasons.of(e) == requiresRecentLoginReason) return requiresRecentLogin;
      switch (e.code) {
        case 'unauthenticated':
          return unauthenticated;
        case 'unavailable':
        case 'deadline-exceeded':
          return network;
        case 'not-found':
        case 'unimplemented':
          return serviceUnavailable;
        case 'resource-exhausted':
          return tooManyRequests;
      }
      return unknown;
    }
    if (e is PlatformException) {
      switch (e.code) {
        case 'sign_in_canceled':
          return canceled;
        case 'network_error':
          return network;
      }
      return googleFailed;
    }
    return unknown;
  }
}

class AccountDeleteException implements Exception {
  final AccountDeleteFailure failure;
  final Object? cause;
  const AccountDeleteException(this.failure, [this.cause]);

  @override
  String toString() => 'AccountDeleteException($failure, $cause)';
}
