import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/backend/backend_contract.dart';
import 'firestore_values.dart';

/// Server-owned exam access for the signed-in user (`entitlements/{uid}`).
/// Written only by Cloud Functions; the client just reads it.
///
/// Nothing in the client unlocks content from this object on its own: the
/// backend (`examStart`) re-checks the same document inside a transaction.
/// The UI uses it only to show the balance and to decide which button to
/// offer.
class Entitlements {
  final bool freeExamUsed;
  final int credits;
  final int lifetimeCreditsPurchased;

  /// When the one free exam was consumed (null while still available).
  final DateTime? freeExamUsedAt;

  /// Last server write; null for the synthetic [initial] value.
  final DateTime? updatedAt;

  const Entitlements({
    required this.freeExamUsed,
    required this.credits,
    required this.lifetimeCreditsPurchased,
    this.freeExamUsedAt,
    this.updatedAt,
  });

  /// A brand-new account has no document yet: the free exam is available.
  static const initial =
      Entitlements(freeExamUsed: false, credits: 0, lifetimeCreditsPurchased: 0);

  bool get hasFreeExam => !freeExamUsed;

  /// Whether starting a new attempt would succeed without a purchase.
  /// Display hint only — the server decides.
  bool get canStartExam => hasFreeExam || credits > 0;

  /// Tolerant parser: snake_case is canonical (ARCHITECTURE §1.5); camelCase
  /// is accepted for documents written by early tooling. Numbers stored as
  /// strings are accepted, negative balances are shown as 0.
  factory Entitlements.fromMap(Map<String, dynamic>? data) {
    if (data == null) return initial;
    Object? pick(String snake, String camel) =>
        data.containsKey(snake) ? data[snake] : data[camel];

    final credits = FirestoreValues.readInt(pick('credits', 'credits'));
    final lifetime = FirestoreValues.readInt(
        pick('lifetime_credits_purchased', 'lifetimeCreditsPurchased'));
    return Entitlements(
      freeExamUsed:
          FirestoreValues.readBool(pick('free_exam_used', 'freeExamUsed')),
      credits: credits < 0 ? 0 : credits,
      lifetimeCreditsPurchased: lifetime < 0 ? 0 : lifetime,
      freeExamUsedAt:
          FirestoreValues.readDate(pick('free_exam_used_at', 'freeExamUsedAt')),
      updatedAt: FirestoreValues.readDate(pick('updated_at', 'updatedAt')),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Entitlements &&
      other.freeExamUsed == freeExamUsed &&
      other.credits == credits &&
      other.lifetimeCreditsPurchased == lifetimeCreditsPurchased &&
      other.freeExamUsedAt == freeExamUsedAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
      freeExamUsed, credits, lifetimeCreditsPurchased, freeExamUsedAt, updatedAt);

  @override
  String toString() =>
      'Entitlements(freeExamUsed: $freeExamUsed, credits: $credits, lifetime: $lifetimeCreditsPurchased)';
}

/// Live entitlements of the current user. Emits [Entitlements.initial] when
/// signed out or before the backend has created the document.
final entitlementsProvider = StreamProvider<Entitlements>((ref) {
  final FirebaseAuth auth;
  try {
    auth = FirebaseAuth.instance;
  } catch (_) {
    // Firebase failed to initialise (offline dev build): nothing to read.
    return Stream.value(Entitlements.initial);
  }
  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(Entitlements.initial);
    return FirebaseFirestore.instance
        .collection(Collections.entitlements)
        .doc(user.uid)
        .snapshots()
        .map((s) => Entitlements.fromMap(s.data()));
  });
});
