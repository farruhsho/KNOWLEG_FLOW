import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/backend/backend_contract.dart';
import '../../../core/backend/callable_platform.dart';
import '../../../core/routes/admin_session.dart';
import '../../../providers/auth_provider.dart' show authServiceProvider;
import '../domain/account_deletion.dart';

/// Re-authentication + server-side account deletion (Google Play User Data
/// policy). The `accountDelete` callable requires a sign-in from the last
/// 5 minutes (`auth_time`, decision D9), removes the Auth user and then
/// cascades the user's data; purchase records are kept anonymised.
class AccountDeletionService {
  AccountDeletionService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    Future<void> Function()? appSignOut,
  })  : _authOverride = auth,
        _googleOverride = googleSignIn,
        _appSignOut = appSignOut;

  final FirebaseAuth? _authOverride;
  final GoogleSignIn? _googleOverride;

  /// The app-wide sign-out (AuthService.signOut), so its clean-up runs.
  final Future<void> Function()? _appSignOut;
  GoogleSignIn? _google;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _google ??= _googleOverride ?? GoogleSignIn();

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  List<ReauthMethod> methods() {
    final u = currentUser;
    if (u == null) return const [];
    return reauthMethodsFor(u.providerData.map((p) => p.providerId), email: u.email);
  }

  Future<void> reauthWithPassword(String password) async {
    final u = currentUser;
    final email = u?.email;
    if (u == null || email == null) throw const AccountDeleteException(AccountDeleteFailure.signedOut);
    try {
      await u.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } catch (e) {
      throw AccountDeleteException(AccountDeleteFailure.from(e), e);
    }
  }

  Future<void> reauthWithGoogle() async {
    final u = currentUser;
    if (u == null) throw const AccountDeleteException(AccountDeleteFailure.signedOut);
    try {
      if (kIsWeb) {
        await u.reauthenticateWithPopup(GoogleAuthProvider());
        return;
      }
      final account = await _googleSignIn.signIn();
      if (account == null) throw const AccountDeleteException(AccountDeleteFailure.canceled);
      final tokens = await account.authentication;
      await u.reauthenticateWithCredential(GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      ));
    } catch (e) {
      throw AccountDeleteException(AccountDeleteFailure.from(e), e);
    }
  }

  /// Calls `accountDelete`, then signs out locally. Throws
  /// [AccountDeleteException]; on [AccountDeleteFailure.requiresRecentLogin]
  /// the caller should re-authenticate and try again.
  ///
  /// The server checks the token's `auth_time`, which only a sign-in or a
  /// `reauthenticateWith*` call moves forward — refreshing the ID token does
  /// not. Callers therefore re-authenticate right before calling this.
  Future<void> deleteAccount() async {
    final u = currentUser;
    if (u == null) throw const AccountDeleteException(AccountDeleteFailure.signedOut);
    try {
      await BackendFunctions.callable(
        BackendFunctions.accountDelete,
        timeout: const Duration(seconds: 120),
      ).call<Object?>(const <String, dynamic>{});
    } catch (e) {
      throw AccountDeleteException(AccountDeleteFailure.from(e), e);
    }

    // The server already removed the Auth user; this only covers a backend
    // that deleted the data but not the login. Errors are expected and ignored.
    try {
      await _auth.currentUser?.delete();
    } catch (_) {}
    adminVerified.value = false;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// "Sign in again" path for accounts the app cannot re-authenticate in
  /// place (no password/Google method), or when the server still reports
  /// REQUIRES_RECENT_LOGIN after a re-auth: sign out so the user can sign in
  /// fresh and come back. Never throws.
  Future<void> signOutForFreshSignIn() async {
    final appSignOut = _appSignOut;
    if (appSignOut != null) {
      try {
        await appSignOut();
        return;
      } catch (_) {
        // Fall through to the local sign-out.
      }
    }
    adminVerified.value = false;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
  }
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  (ref) => AccountDeletionService(appSignOut: () => ref.read(authServiceProvider).signOut()),
);

/// Whether `accountDelete` can be called from this platform (App Check, D7).
/// Elsewhere (Windows/Linux, web without a reCAPTCHA key) the page explains
/// that deletion must be done from the Android app instead of failing.
final accountDeletionAvailableProvider =
    Provider<bool>((ref) => callablesSupportedOnThisPlatform);
