import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/backend/backend_contract.dart';

/// Server-owned exam access for the signed-in user (`entitlements/{uid}`).
/// Written only by Cloud Functions; the client just reads it.
class Entitlements {
  final bool freeExamUsed;
  final int credits;
  final int lifetimeCreditsPurchased;

  const Entitlements({
    required this.freeExamUsed,
    required this.credits,
    required this.lifetimeCreditsPurchased,
  });

  /// A brand-new account has no document yet: the free exam is available.
  static const initial =
      Entitlements(freeExamUsed: false, credits: 0, lifetimeCreditsPurchased: 0);

  bool get hasFreeExam => !freeExamUsed;

  /// Whether starting a new attempt would succeed without a purchase.
  bool get canStartExam => hasFreeExam || credits > 0;

  factory Entitlements.fromMap(Map<String, dynamic>? data) {
    if (data == null) return initial;
    return Entitlements(
      freeExamUsed: data['free_exam_used'] == true,
      credits: (data['credits'] as num?)?.toInt() ?? 0,
      lifetimeCreditsPurchased:
          (data['lifetime_credits_purchased'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Live entitlements of the current user. Emits [Entitlements.initial] when
/// signed out or before the backend has created the document.
final entitlementsProvider = StreamProvider<Entitlements>((ref) {
  return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(Entitlements.initial);
    return FirebaseFirestore.instance
        .collection(Collections.entitlements)
        .doc(user.uid)
        .snapshots()
        .map((s) => Entitlements.fromMap(s.data()));
  });
});
