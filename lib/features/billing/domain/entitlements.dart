import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/backend/backend_contract.dart';
import '../application/billing_providers.dart' show pricingConfigProvider;
import 'firestore_values.dart';
import 'pricing_config.dart';

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

  /// Free exams already consumed (`free_exams_used_count`). Older documents
  /// only carry the `free_exam_used` flag, which counts as one.
  final int freeExamsUsedCount;

  /// Free exams per account from `config/pricing.free_exams_per_user`
  /// (server default 1, valid 0..5). Not part of the entitlement document:
  /// [entitlementsProvider] fills it in from the pricing config.
  final int freeExamsAllowed;

  /// When the first free exam was consumed (null while none was used).
  final DateTime? freeExamUsedAt;

  /// Last server write; null for the synthetic [initial] value.
  final DateTime? updatedAt;

  const Entitlements({
    required this.freeExamUsed,
    required this.credits,
    required this.lifetimeCreditsPurchased,
    int? freeExamsUsedCount,
    this.freeExamsAllowed = PricingConfig.defaultFreeExamsPerUser,
    this.freeExamUsedAt,
    this.updatedAt,
  }) : freeExamsUsedCount = freeExamsUsedCount ?? (freeExamUsed ? 1 : 0);

  /// A brand-new account has no document yet: the free exam is available.
  static const initial =
      Entitlements(freeExamUsed: false, credits: 0, lifetimeCreditsPurchased: 0);

  /// Free exams the server would still grant (never negative).
  int get freeExamsRemaining {
    final left = freeExamsAllowed - freeExamsUsedCount;
    return left < 0 ? 0 : left;
  }

  /// Mirrors the server rule `free_exams_used_count < free_exams_per_user`
  /// (functions/src/domain/entitlements.ts `decideExamStart`).
  bool get hasFreeExam => freeExamsRemaining > 0;

  /// Whether starting a new attempt would succeed without a purchase.
  /// Display hint only — the server decides.
  bool get canStartExam => hasFreeExam || credits > 0;

  /// Same document with another free-exam allowance.
  Entitlements withFreeExamsAllowed(int allowed) => allowed == freeExamsAllowed
      ? this
      : Entitlements(
          freeExamUsed: freeExamUsed,
          credits: credits,
          lifetimeCreditsPurchased: lifetimeCreditsPurchased,
          freeExamsUsedCount: freeExamsUsedCount,
          freeExamsAllowed: allowed,
          freeExamUsedAt: freeExamUsedAt,
          updatedAt: updatedAt,
        );

  /// Tolerant parser: snake_case is canonical (ARCHITECTURE §1.5); camelCase
  /// is accepted for documents written by early tooling. Numbers stored as
  /// strings are accepted, negative balances are shown as 0.
  ///
  /// The used-count follows the server's `parseEntitlement`:
  /// `max(free_exams_used_count, free_exam_used ? 1 : 0)`.
  factory Entitlements.fromMap(
    Map<String, dynamic>? data, {
    int freeExamsAllowed = PricingConfig.defaultFreeExamsPerUser,
  }) {
    if (data == null) return initial.withFreeExamsAllowed(freeExamsAllowed);
    Object? pick(String snake, String camel) =>
        data.containsKey(snake) ? data[snake] : data[camel];

    final credits = FirestoreValues.readInt(pick('credits', 'credits'));
    final lifetime = FirestoreValues.readInt(
        pick('lifetime_credits_purchased', 'lifetimeCreditsPurchased'));
    final usedFlag =
        FirestoreValues.readBool(pick('free_exam_used', 'freeExamUsed'));
    final rawCount = FirestoreValues.readInt(
        pick('free_exams_used_count', 'freeExamsUsedCount'),
        fallback: usedFlag ? 1 : 0);
    final floor = usedFlag ? 1 : 0;
    final usedCount = rawCount < floor ? floor : rawCount;
    return Entitlements(
      freeExamUsed: usedFlag || usedCount > 0,
      credits: credits < 0 ? 0 : credits,
      lifetimeCreditsPurchased: lifetime < 0 ? 0 : lifetime,
      freeExamsUsedCount: usedCount,
      freeExamsAllowed: freeExamsAllowed,
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
      other.freeExamsUsedCount == freeExamsUsedCount &&
      other.freeExamsAllowed == freeExamsAllowed &&
      other.freeExamUsedAt == freeExamUsedAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(freeExamUsed, credits, lifetimeCreditsPurchased,
      freeExamsUsedCount, freeExamsAllowed, freeExamUsedAt, updatedAt);

  @override
  String toString() =>
      'Entitlements(freeExamsUsed: $freeExamsUsedCount/$freeExamsAllowed, credits: $credits, lifetime: $lifetimeCreditsPurchased)';
}

/// Live entitlements of the current user. Emits [Entitlements.initial] when
/// signed out or before the backend has created the document.
///
/// The free-exam allowance comes from `config/pricing.free_exams_per_user`
/// (via [pricingConfigProvider]); only a change of that number re-subscribes.
final entitlementsProvider = StreamProvider<Entitlements>((ref) {
  final freeAllowed = ref.watch(pricingConfigProvider.select(
      (p) => p.valueOrNull?.freeExamsPerUser ?? PricingConfig.defaultFreeExamsPerUser));
  final FirebaseAuth auth;
  try {
    auth = FirebaseAuth.instance;
  } catch (_) {
    // Firebase failed to initialise (offline dev build): nothing to read.
    return Stream.value(Entitlements.initial.withFreeExamsAllowed(freeAllowed));
  }
  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream.value(Entitlements.initial.withFreeExamsAllowed(freeAllowed));
    }
    return FirebaseFirestore.instance
        .collection(Collections.entitlements)
        .doc(user.uid)
        .snapshots()
        .map((s) => Entitlements.fromMap(s.data(), freeExamsAllowed: freeAllowed));
  });
});
