import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/network/firebase_service.dart';
import '../core/routes/admin_session.dart';
import '../features/settings/data/reminder_settings.dart';
import '../firebase_options.dart';
import '../shared/models/user_model.dart';
import 'onboarding_provider.dart';

/// Firebase auth state (sign-in / sign-out).
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.auth.authStateChanges();
});

/// Uid of the signed-in user, or null. Downstream providers watch this
/// instead of [authStateProvider] so token refreshes (same uid) do not
/// rebuild them.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider.select((s) => s.valueOrNull?.uid));
});

/// The signed-in user's `users/{uid}` profile (null while signed out or
/// before the document exists).
final userModelProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return FirebaseService.firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snapshot) =>
          snapshot.exists ? UserModel.fromFirestore(snapshot) : null);
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final onboarding = ref.watch(onboardingServiceProvider);
  return AuthService(
    // Answers given in onboarding before sign-in are saved to the profile.
    onSignedIn: (user) => onboarding.flushPendingAnswers(user.uid),
    // Unregister this device from the account's study reminders (D12): only
    // its token is removed; the account-wide flag stays on (REM-01).
    beforeSignOut: () => ref.read(reminderSettingsProvider).onSignOut(),
  );
});

/// Thrown when the user closes the Google account picker.
class SignInCancelledException implements Exception {
  const SignInCancelledException();
  @override
  String toString() => 'SignInCancelledException';
}

/// Thrown when Google sign-in is not available on this platform/build.
class SignInUnavailableException implements Exception {
  const SignInUnavailableException();
  @override
  String toString() => 'SignInUnavailableException';
}

/// Google sign-in availability (AUTH-02).
///
/// iOS needs the reversed client id URL scheme and `GIDClientID` in
/// Info.plist; without them the native SDK raises an exception that crashes
/// the app. Until the owner adds that configuration the iOS button is hidden;
/// a configured build enables it with
/// `--dart-define=GOOGLE_SIGN_IN_IOS_CONFIGURED=true`.
/// Web uses Firebase's popup flow; desktop has no implementation.
abstract final class GoogleSignInSupport {
  static const bool iosConfigured =
      bool.fromEnvironment('GOOGLE_SIGN_IN_IOS_CONFIGURED');

  static bool get isAvailable {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return true;
      case TargetPlatform.iOS:
        return iosConfigured;
      default:
        return false;
    }
  }
}

/// Authentication + profile bootstrap.
///
/// Rules (AUTH-01 / AUTH-03):
///  * Sign-in succeeds as soon as Firebase Auth succeeds. Creating or
///    touching `users/{uid}` is best-effort and never turns a successful
///    sign-in into an error.
///  * Profile creation is idempotent ([ensureProfile]).
///  * The client never writes `role` (UserModel.toFirestore excludes it) and
///    no longer writes the unruled `gamification/{uid}` document.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    Future<void> Function(User user)? onSignedIn,
    Future<void> Function()? beforeSignOut,
  })  : _authOverride = auth,
        _firestoreOverride = firestore,
        _onSignedIn = onSignedIn,
        _beforeSignOut = beforeSignOut;

  /// Runs (best-effort) after every successful sign-in / sign-up.
  final Future<void> Function(User user)? _onSignedIn;

  /// Runs (best-effort) while still signed in, right before sign-out.
  final Future<void> Function()? _beforeSignOut;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  GoogleSignIn? _googleSignInInstance;

  FirebaseAuth get _auth => _authOverride ?? FirebaseService.auth;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseService.firestore;

  GoogleSignIn get _googleSignIn => _googleSignInInstance ??= GoogleSignIn(
        clientId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? DefaultFirebaseOptions.ios.iosClientId
            : null,
      );

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      unawaited(_afterSignIn(user, fallbackName: email.split('@').first));
    }
    FirebaseService.logEvent('login', {'method': 'password'});
    return credential;
  }

  /// Creates an email/password account. The profile document, display name
  /// and verification e-mail are best-effort.
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String preferredLanguage = 'ru',
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      unawaited(_afterSignUp(user, name: name, language: preferredLanguage));
    }
    FirebaseService.logEvent('sign_up', {'method': 'password'});
    return credential;
  }

  Future<void> _afterSignUp(
    User user, {
    required String name,
    required String language,
  }) async {
    await ensureProfile(user, name: name, preferredLanguage: language);
    try {
      await user.updateDisplayName(name);
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'update_display_name');
    }
    await sendEmailVerification();
    await _runOnSignedIn(user);
  }

  Future<void> _afterSignIn(User user, {String? fallbackName}) async {
    await ensureProfile(user, name: fallbackName);
    await _runOnSignedIn(user);
  }

  /// Background work for a session restored on a cold start: make sure the
  /// profile exists, then save pending onboarding answers. Sequential on
  /// purpose — creating the profile after the answers were merged would
  /// overwrite them with defaults. Never throws.
  Future<void> bootstrapSession(User user) => _afterSignIn(user);

  Future<void> _runOnSignedIn(User user) async {
    try {
      await _onSignedIn?.call(user);
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'post_sign_in');
    }
  }

  /// Sign in with Google. Throws [SignInCancelledException] when the picker
  /// is closed and [SignInUnavailableException] where it is not supported.
  Future<UserCredential> signInWithGoogle() async {
    if (!GoogleSignInSupport.isAvailable) {
      throw const SignInUnavailableException();
    }

    final UserCredential userCredential;
    if (kIsWeb) {
      userCredential = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw const SignInCancelledException();
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      userCredential = await _auth.signInWithCredential(credential);
    }

    final user = userCredential.user;
    if (user != null) {
      unawaited(_afterSignIn(user, fallbackName: user.displayName));
    }
    FirebaseService.logEvent('login', {'method': 'google'});
    return userCredential;
  }

  /// Creates `users/{uid}` if it is missing, otherwise refreshes
  /// `last_active`. Idempotent and never throws.
  Future<void> ensureProfile(
    User user, {
    String? name,
    String? preferredLanguage,
  }) async {
    FirebaseService.setUserIdentifier(user.uid);
    try {
      final ref = _userDoc(user.uid);
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        final now = DateTime.now();
        final profile = UserModel(
          uid: user.uid,
          name: (name?.trim().isNotEmpty ?? false)
              ? name!.trim()
              : (user.displayName ?? user.email?.split('@').first ?? ''),
          email: user.email ?? '',
          phone: user.phoneNumber,
          grade: 11,
          preferredLanguage: preferredLanguage ?? 'ru',
          subscription: const SubscriptionModel(),
          linkedAccounts: const LinkedAccounts(),
          createdAt: now,
          lastActive: now,
        );
        await ref.set(profile.toFirestore());
      } else {
        await ref.update({'last_active': FieldValue.serverTimestamp()});
      }
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'ensure_profile');
    }
  }

  /// Merges editable profile fields into `users/{uid}`. Only non-privileged
  /// fields may be passed (rules reject role/subscription changes).
  Future<void> updateProfileFields(Map<String, dynamic> fields) async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in');
    assert(!fields.containsKey('role') && !fields.containsKey('subscription'));
    await _userDoc(user.uid).set(fields, SetOptions(merge: true));
    final name = fields['name'];
    if (name is String && name.trim().isNotEmpty && name != user.displayName) {
      try {
        await user.updateDisplayName(name.trim());
      } catch (e, s) {
        FirebaseService.recordNonFatal(e, s, reason: 'update_display_name');
      }
    }
  }

  /// Sends the address-verification e-mail. Returns false on failure.
  Future<bool> sendEmailVerification() async {
    final user = currentUser;
    if (user == null || user.emailVerified || user.email == null) return false;
    try {
      await user.sendEmailVerification();
      return true;
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'send_email_verification');
      return false;
    }
  }

  /// Reloads the user and reports whether the e-mail is now verified.
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Sign out
  Future<void> signOut() async {
    final hook = _beforeSignOut;
    try {
      // Needs the user's credentials (e.g. removing this device's reminder
      // token from users/{uid}), so it runs before Auth signs out.
      if (hook != null) await hook().timeout(const Duration(seconds: 10));
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'before_sign_out');
    }
    // Drop any verified-admin session so /admin/* re-gates after sign-out.
    adminVerified.value = false;
    FirebaseService.setUserIdentifier(null);
    try {
      if (!kIsWeb && GoogleSignInSupport.isAvailable) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google sign-out skipped: $e');
    }
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Update user's preferred (content) language. Best-effort.
  Future<void> updatePreferredLanguage(String languageCode) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await _userDoc(user.uid).set(
        {'preferred_language': languageCode},
        SetOptions(merge: true),
      );
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'update_language');
    }
  }

  /// Update last active timestamp. Best-effort.
  Future<void> updateLastActive() async {
    final user = currentUser;
    if (user == null) return;
    try {
      await _userDoc(user.uid).update({'last_active': Timestamp.now()});
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'update_last_active');
    }
  }
}
