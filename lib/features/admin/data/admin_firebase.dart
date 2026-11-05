import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_contract.dart';

/// Firebase handles used by the admin CMS. Overridable in tests.
final adminFirestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final adminAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final adminStorageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);
final adminFunctionsProvider =
    Provider<FirebaseFunctions>((ref) => BackendFunctions.instance);

/// Legacy collections the CMS edits (names kept exactly as in production).
abstract final class AdminCollections {
  static const users = 'users';
  static const subjects = 'subjects';
  static const lessons = 'lessons';
  static const questions = 'questions';
  static const examQuestions = 'exam_questions';
  static const examQuestionKeys = 'exam_question_keys';
  static const examPassages = 'exam_passages';
  static const examVariants = 'exam_variants';
  static const examBlueprints = 'exam_blueprints';
  static const entitlements = 'entitlements';
  static const ledger = 'ledger';
  static const userStats = 'user_stats';
  static const purchases = 'purchases';
  static const config = 'config';
  static const pricingDoc = 'pricing';
  static const adminLogs = 'admin_logs';

  // Phase 3 (ARCHITECTURE §9). Shared names live in `Collections`
  // (backend_contract.dart); these are the ones only the CMS reads.
  static const promoCodes = 'promo_codes';
  static const promoRedemptions = 'redemptions'; // sub-collection of promo_codes
  static const achievementsDoc = 'achievements'; // config/achievements
}

/// Page of documents for cursor pagination (FB-17: never scan collections).
class AdminPage<T> {
  final List<T> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
  const AdminPage(this.items, this.cursor, this.hasMore);
}

/// Runs [query] with `limit(pageSize + 1)` after [after] and maps the docs.
Future<AdminPage<T>> fetchPage<T>(
  Query<Map<String, dynamic>> query, {
  required DocumentSnapshot<Map<String, dynamic>>? after,
  required int pageSize,
  required T Function(DocumentSnapshot<Map<String, dynamic>> doc) map,
}) async {
  var q = query;
  if (after != null) q = q.startAfterDocument(after);
  final snap = await q.limit(pageSize + 1).get();
  final docs = snap.docs;
  final hasMore = docs.length > pageSize;
  final pageDocs = hasMore ? docs.sublist(0, pageSize) : docs;
  return AdminPage(
    [for (final d in pageDocs) map(d)],
    pageDocs.isEmpty ? after : pageDocs.last,
    hasMore,
  );
}
