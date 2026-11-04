import 'package:firebase_auth/firebase_auth.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';

/// Validation problems for the auth forms (SEC-005R). Pure so they can be
/// unit-tested; [AuthMessages] turns them into localized text.
enum AuthFieldError {
  emailEmpty,
  emailInvalid,
  passwordEmpty,
  passwordTooShort,
  passwordTooWeak,
  passwordMismatch,
  nameEmpty,
  nameTooShort,
}

abstract final class AuthValidators {
  static const int minPasswordLength = 8;

  // Pragmatic e-mail check: local@domain.tld, no spaces.
  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
  );

  static AuthFieldError? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return AuthFieldError.emailEmpty;
    if (!_email.hasMatch(v)) return AuthFieldError.emailInvalid;
    return null;
  }

  /// Sign-in only checks presence: existing accounts may have older,
  /// shorter passwords.
  static AuthFieldError? loginPassword(String? value) {
    if (value == null || value.isEmpty) return AuthFieldError.passwordEmpty;
    return null;
  }

  /// New passwords: at least 8 characters with a letter and a digit.
  static AuthFieldError? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return AuthFieldError.passwordEmpty;
    if (v.length < minPasswordLength) return AuthFieldError.passwordTooShort;
    final hasLetter = RegExp(r'[A-Za-zА-Яа-яЁёҢңӨөҮү]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    if (!hasLetter || !hasDigit) return AuthFieldError.passwordTooWeak;
    return null;
  }

  static AuthFieldError? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return AuthFieldError.passwordEmpty;
    if (value != password) return AuthFieldError.passwordMismatch;
    return null;
  }

  static AuthFieldError? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return AuthFieldError.nameEmpty;
    if (v.length < 2) return AuthFieldError.nameTooShort;
    return null;
  }
}

/// Categories of auth failures shown to the user.
enum AuthFailure {
  invalidCredentials,
  invalidEmail,
  userDisabled,
  tooManyRequests,
  emailInUse,
  weakPassword,
  operationNotAllowed,
  network,
  googleUnavailable,
  accountExistsWithDifferentCredential,
  userNotFound,
  unknown,
}

/// Maps a thrown error to an [AuthFailure]. Returns null for a user
/// cancellation (nothing should be shown).
AuthFailure? classifyAuthError(Object error) {
  if (error is SignInCancelledException) return null;
  if (error is SignInUnavailableException) return AuthFailure.googleUnavailable;
  if (error is FirebaseAuthException) return authFailureForCode(error.code);
  return AuthFailure.unknown;
}

AuthFailure? authFailureForCode(String code) {
  switch (code) {
    // With e-mail enumeration protection on, Firebase reports wrong e-mail
    // and wrong password both as invalid-credential.
    case 'invalid-credential':
    case 'wrong-password':
    case 'invalid-login-credentials':
      return AuthFailure.invalidCredentials;
    case 'user-not-found':
      return AuthFailure.userNotFound;
    case 'invalid-email':
      return AuthFailure.invalidEmail;
    case 'user-disabled':
      return AuthFailure.userDisabled;
    case 'too-many-requests':
      return AuthFailure.tooManyRequests;
    case 'email-already-in-use':
      return AuthFailure.emailInUse;
    case 'weak-password':
      return AuthFailure.weakPassword;
    case 'operation-not-allowed':
      return AuthFailure.operationNotAllowed;
    case 'network-request-failed':
      return AuthFailure.network;
    case 'account-exists-with-different-credential':
      return AuthFailure.accountExistsWithDifferentCredential;
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
    case 'web-context-canceled':
      return null;
    default:
      return AuthFailure.unknown;
  }
}

/// Localized texts for validation errors and auth failures.
extension AuthMessages on AppLocalizations {
  String shellFieldErrorText(AuthFieldError error) {
    switch (error) {
      case AuthFieldError.emailEmpty:
        return shellAuthEmailRequired;
      case AuthFieldError.emailInvalid:
        return shellAuthEmailInvalid;
      case AuthFieldError.passwordEmpty:
        return shellAuthPasswordRequired;
      case AuthFieldError.passwordTooShort:
        return shellAuthPasswordTooShort(AuthValidators.minPasswordLength);
      case AuthFieldError.passwordTooWeak:
        return shellAuthPasswordTooWeak;
      case AuthFieldError.passwordMismatch:
        return shellAuthPasswordMismatch;
      case AuthFieldError.nameEmpty:
        return shellAuthNameRequired;
      case AuthFieldError.nameTooShort:
        return shellAuthNameTooShort;
    }
  }

  String shellAuthFailureText(AuthFailure failure) {
    switch (failure) {
      case AuthFailure.invalidCredentials:
        return shellAuthErrorInvalidCredentials;
      case AuthFailure.userNotFound:
        return shellAuthErrorUserNotFound;
      case AuthFailure.invalidEmail:
        return shellAuthEmailInvalid;
      case AuthFailure.userDisabled:
        return shellAuthErrorUserDisabled;
      case AuthFailure.tooManyRequests:
        return shellAuthErrorTooManyRequests;
      case AuthFailure.emailInUse:
        return shellAuthErrorEmailInUse;
      case AuthFailure.weakPassword:
        return shellAuthPasswordTooWeak;
      case AuthFailure.operationNotAllowed:
        return shellAuthErrorNotAllowed;
      case AuthFailure.network:
        return shellAuthErrorNetwork;
      case AuthFailure.googleUnavailable:
        return shellAuthErrorGoogleUnavailable;
      case AuthFailure.accountExistsWithDifferentCredential:
        return shellAuthErrorDifferentCredential;
      case AuthFailure.unknown:
        return shellAuthErrorUnknown;
    }
  }

  /// Validator adapter for `TextFormField.validator`.
  String? shellValidate(AuthFieldError? error) =>
      error == null ? null : shellFieldErrorText(error);
}
