import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/backend/backend_contract.dart';
import '../../../core/routes/admin_session.dart';
import '../domain/account_deletion.dart';

/// Re-authentication + server-side account deletion (Google Play User Data
/// policy). The `accountDelete` callable cascades the user's data and removes
/// the Auth user with the Admin SDK; purchase records are kept anonymised.
class AccountDeletionService {
  AccountDeletionService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _authOverride = auth,
        _googleOverride = googleSignIn;

  final FirebaseAuth? _authOverride;
  final GoogleSignIn? _googleOverride;
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
  Future<void> deleteAccount() async {
    final u = currentUser;
    if (u == null) throw const AccountDeleteException(AccountDeleteFailure.signedOut);
    try {
      // Fresh token so the backend sees a recent auth_time.
      await u.getIdToken(true);
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
}

final accountDeletionServiceProvider =
    Provider<AccountDeletionService>((ref) => AccountDeletionService());
