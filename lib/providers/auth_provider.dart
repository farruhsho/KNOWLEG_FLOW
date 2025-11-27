import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/network/firebase_service.dart';
import '../shared/models/user_model.dart';

/// Provider for the current Firebase user
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.auth.authStateChanges();
});

/// Provider for the current user model
final userModelProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return FirebaseService.firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) return null;
        return UserModel.fromFirestore(snapshot);
      });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  final FirebaseAuth _auth = FirebaseService.auth;
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user document if it doesn't exist (for existing users who registered before this feature)
    if (credential.user != null) {
      final userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _createUserDocument(
          uid: credential.user!.uid,
          email: credential.user!.email ?? email,
          name: credential.user!.displayName ?? email.split('@').first,
        );
      } else {
        // Update last active timestamp
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'last_active': Timestamp.now(),
        });
      }
    }

    return credential;
  }

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    // Create user account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user document in Firestore
    if (credential.user != null) {
      await _createUserDocument(
        uid: credential.user!.uid,
        email: email,
        name: name,
      );

      // Update display name
      await credential.user!.updateDisplayName(name);
    }

    return credential;
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      throw Exception('Google sign in cancelled');
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in with credential
    final userCredential = await _auth.signInWithCredential(credential);

    // Create user document if it doesn't exist
    if (userCredential.user != null) {
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _createUserDocument(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          name: userCredential.user!.displayName ?? 'User',
        );
      }
    }

    return userCredential;
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String name,
  }) async {
    final userModel = UserModel(
      uid: uid,
      name: name,
      email: email,
      grade: 11,
      preferredLanguage: 'ru',
      subscription: const SubscriptionModel(),
      linkedAccounts: const LinkedAccounts(),
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(uid)
        .set(userModel.toFirestore());

    // Initialize gamification data
    await _firestore
        .collection('gamification')
        .doc(uid)
        .set({
      'userId': uid,
      'level': 1,
      'xp': 0,
      'xpToNextLevel': 100,
      'coins': 0,
      'streakDays': 0,
      'lastActivityDate': Timestamp.now(),
      'statistics': {},
    });
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Update user's preferred language
  Future<void> updatePreferredLanguage(String languageCode) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'preferred_language': languageCode,
    });
  }

  /// Update last active timestamp
  Future<void> updateLastActive() async {
    final user = currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'last_active': Timestamp.now(),
    });
  }
}
