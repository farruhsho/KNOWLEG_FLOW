import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/backend/backend_contract.dart';
import '../../core/utils/app_log.dart';
import '../models/mistake_model.dart';

/// "Ошибки и повторение" queue in `user_mistakes/{uid}/items/{questionId}`.
///
/// Practice items are written by the client (only `source == 'practice'` is
/// allowed by the rules); exam items are written by the backend and are
/// read-only here — they are reviewed through the exam review screen.
class MistakesService {
  MistakesService._();
  static final MistakesService instance = MistakesService._();

  CollectionReference<Map<String, dynamic>> _items(String uid) => FirebaseFirestore.instance
      .collection(Collections.userMistakes)
      .doc(uid)
      .collection(Collections.userMistakeItems);

  /// All unresolved items, soonest review first.
  Stream<List<MistakeItem>> watchOpen(String uid) {
    return _items(uid).where('resolved', isEqualTo: false).limit(300).snapshots().map((snap) {
      final list = <MistakeItem>[];
      for (final d in snap.docs) {
        try {
          list.add(MistakeItem.fromMap(d.id, d.data()));
        } catch (e, st) {
          reportError(e, st, reason: 'learn.mistakes.parse');
        }
      }
      list.sort((a, b) {
        final at = a.nextReviewAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.nextReviewAt?.millisecondsSinceEpoch ?? 0;
        return at.compareTo(bt);
      });
      return list;
    });
  }

  /// Marks a practice item as resolved (exam items are server-owned).
  Future<void> markResolved(String uid, MistakeItem item) async {
    if (!item.clientWritable) return;
    unawaited(_items(uid).doc(item.questionId).set({
      'resolved': true,
    }, SetOptions(merge: true)).catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'learn.mistakes.resolve');
    }));
  }

  /// Applies the SRS step after re-practising [item].
  void applyReview(String uid, MistakeItem item, {required bool correct, DateTime? now}) {
    if (!item.clientWritable) return;
    final t = now ?? DateTime.now();
    final next = correct ? MistakeSrs.afterCorrect(item, t) : MistakeSrs.afterWrong(item, t);
    unawaited(_items(uid).doc(item.questionId).set({
      'question_id': item.questionId,
      'source': 'practice',
      'subject_id': item.subjectId,
      'section_id': item.sectionId,
      'topic_id': item.topicId,
      'wrong_count': next.wrongCount,
      'last_wrong_at': correct
          ? (item.lastWrongAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(item.lastWrongAt!))
          : FieldValue.serverTimestamp(),
      'next_review_at': Timestamp.fromDate(next.nextReviewAt ?? t),
      'interval_days': next.intervalDays,
      'resolved': next.resolved,
    }, SetOptions(merge: true)).catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'learn.mistakes.review');
    }));
  }
}
