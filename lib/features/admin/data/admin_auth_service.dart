import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/admin_access_provider.dart';
import '../domain/admin_role.dart';
import 'admin_firebase.dart';

/// Thrown when the signed-in account is not an admin.
class NotAnAdminException implements Exception {
  const NotAnAdminException();
}

/// Admin sign-in: Firebase Auth email/password, then role resolution from the
/// custom claim with the legacy `users.role == 'admin'` fallback.
///
/// Unlike the student AuthService it never creates or touches profile
/// documents, so a failed admin login leaves no side effects.
class AdminAuthService {
  AdminAuthService(this._auth, this._firestore, this._ref);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Ref _ref;

  User? get currentUser => _auth.currentUser;

  /// Signs in and starts the admin session. Signs the user out again and
  /// throws [NotAnAdminException] when the account has no admin role.
  Future<AdminSession> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) throw const NotAnAdminException();
    return verify(user, signOutIfNotAdmin: true);
  }

  /// Re-verifies an already signed-in user (cold start: Firebase Auth kept the
  /// user, but [adminVerified] was reset).
  ///
  /// [signOutIfNotAdmin] is `true` only for a fresh credential sign-in: a
  /// student who merely opens the admin login and taps "continue" must not be
  /// signed out of the student app.
  Future<AdminSession> verify(User user, {bool signOutIfNotAdmin = false}) async {
    // Force refresh so a role granted or revoked by adminSetRole is seen now.
    final token = await user.getIdTokenResult(true);
    final claim = token.claims?['role'];
    Object? legacy;
    if (AdminRole.fromWire(claim) == null) {
      final doc =
          await _firestore.collection(AdminCollections.users).doc(user.uid).get();
      legacy = doc.data()?['role'];
    }
    final role = resolveAdminRole(claimRole: claim, legacyUserRole: legacy);
    if (role == null) {
      if (signOutIfNotAdmin) {
        await signOut();
      } else {
        _ref.read(adminSessionProvider.notifier).clear();
      }
      throw const NotAnAdminException();
    }
    final session = AdminSession(
      uid: user.uid,
      email: user.email,
      role: role,
      fromLegacyField: AdminRole.fromWire(claim) == null,
    );
    _ref.read(adminSessionProvider.notifier).start(session);
    return session;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() async {
    _ref.read(adminSessionProvider.notifier).clear();
    await _auth.signOut();
  }
}

final adminAuthServiceProvider = Provider<AdminAuthService>((ref) => AdminAuthService(
      ref.watch(adminAuthProvider),
      ref.watch(adminFirestoreProvider),
      ref,
    ));
