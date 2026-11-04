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

/// Typed confirmation: case-insensitive, surrounding spaces ignored.
bool isDeleteConfirmationValid(String typed, String word) {
  final a = typed.trim().toUpperCase();
  return a.isNotEmpty && a == word.trim().toUpperCase();
}

enum AccountDeleteFailure {
  wrongPassword,
  tooManyRequests,
  network,
  requiresRecentLogin,
  userMismatch,
  canceled,
  googleFailed,
  serviceUnavailable,
  signedOut,
  unknown;

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
      final reason = BackendReasons.of(e);
      final msg = (e.message ?? '').toLowerCase();
      if (reason == 'REQUIRES_RECENT_LOGIN' ||
          reason == 'RECENT_LOGIN_REQUIRED' ||
          e.code == 'unauthenticated' ||
          (e.code == 'failed-precondition' && msg.contains('recent'))) {
        return requiresRecentLogin;
      }
      switch (e.code) {
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
