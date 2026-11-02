import 'dart:math';

import '../../core/utils/json_read.dart';

/// Pure selection rules for practice questions (FB-18, EXAM-12).
///
/// Practice reads the legacy `questions` collection page by page starting
/// at a random document-id pivot (wrapping around), filters out anything
/// that must not reach students, and samples the session from the pool.
/// No new field or composite index is needed: equality filters plus an
/// order on the document id are served by Firestore's single-field indexes.
abstract final class QuestionPool {
  /// Alphabet of Firestore auto-ids; a random 20-char key is a uniformly
  /// random pivot in the id space.
  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  static String randomPivot(Random random) => String.fromCharCodes(
        List.generate(20, (_) => _alphabet.codeUnitAt(random.nextInt(_alphabet.length))),
      );

  /// Whether a raw question document may be served in practice:
  /// * not deactivated (`is_active == false`);
  /// * AI-generated drafts only once verified (`is_verified == true`);
  /// * not a draft / rejected / archived item of the review pipeline.
  /// Legacy documents without these flags are servable.
  static bool isServable(Map<String, dynamic> data) {
    if (JsonRead.boolean(data, ['is_active', 'isActive']) == false) return false;
    final ai = JsonRead.boolean(data, ['is_ai_generated', 'isAiGenerated']) ?? false;
    final verified = JsonRead.boolean(data, ['is_verified', 'isVerified']);
    if (ai && verified != true) return false;
    const blocked = {'draft', 'rejected', 'archived', 'in_review'};
    final review = JsonRead.map(data, ['review']);
    final reviewStatus = review == null ? null : JsonRead.string(review, ['status']);
    if (reviewStatus != null && blocked.contains(reviewStatus)) return false;
    final status = JsonRead.string(data, ['status']);
    if (status != null && blocked.contains(status)) return false;
    return true;
  }

  /// Random sample of up to [count] distinct items (by [idOf]).
  static List<T> sample<T>(
    Iterable<T> pool,
    int count,
    Random random, {
    required String Function(T) idOf,
  }) {
    final seen = <String>{};
    final unique = <T>[];
    for (final item in pool) {
      if (seen.add(idOf(item))) unique.add(item);
    }
    unique.shuffle(random);
    return unique.take(count).toList();
  }
}
