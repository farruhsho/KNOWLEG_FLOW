import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/backend/backend_contract.dart';
import '../../core/utils/app_log.dart';
import '../models/mistake_model.dart';

/// "Ошибки и повторение" queue in `user_mistakes/{uid}/items/{questionId}`.
///
/// Practice items are written by the client in full (only
/// `source == 'practice'` may be created by the rules). Exam items are
/// created by the backend; the owner may only move their review schedule
/// forward, i.e. change [examWritableFields] (firestore.rules, GAM-X1).
class MistakesService {
  MistakesService._();
  static final MistakesService instance = MistakesService._();

  /// How many open items the queue reads at most. Ordered by
  /// `next_review_at`, so the due ones are always among them.
  static const openLimit = 300;

  /// The only fields the rules let the owner change on an exam item.
  static const examWritableFields = {
    'resolved',
    'next_review_at',
    'interval_days',
    'last_reviewed_at',
    'review_count',
    'updated_at',
  };

  CollectionReference<Map<String, dynamic>> _items(String uid) => FirebaseFirestore.instance
      .collection(Collections.userMistakes)
      .doc(uid)
      .collection(Collections.userMistakeItems);

  /// Unresolved items, soonest review first. Served by the composite index
  /// (resolved ASC, next_review_at ASC); every writer sets next_review_at.
  static Query<Map<String, dynamic>> openQuery(CollectionReference<Map<String, dynamic>> items) =>
      items.where('resolved', isEqualTo: false).orderBy('next_review_at').limit(openLimit);

  /// All unresolved items, soonest review first.
  Stream<List<MistakeItem>> watchOpen(String uid) {
    return openQuery(_items(uid)).snapshots().map((snap) {
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

  /// Marks [item] as resolved. Practice items are merged in full; exam items
  /// get only the fields the rules allow.
  Future<void> markResolved(String uid, MistakeItem item) async {
    if (item.source == MistakeSource.exam) return markExamResolved(uid, item);
    if (!item.clientWritable) return;
    unawaited(_items(uid).doc(item.questionId).set({
      'resolved': true,
    }, SetOptions(merge: true)).catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'learn.mistakes.resolve');
    }));
  }

  /// Applies the SRS step after re-practising a practice [item]. Exam items
  /// cannot be re-practised in the app; see [reviewExamItem].
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

  /// The student reviewed an exam mistake (in the attempt review): move it
  /// one step along 1 → 3 → 7 → 14 → 30 days, resolving it after the last.
  Future<void> reviewExamItem(String uid, MistakeItem item, {DateTime? now}) async {
    if (item.source != MistakeSource.exam) return;
    await _updateExam(uid, item, examReviewPatch(item, now ?? DateTime.now()), 'learn.mistakes.exam_review');
  }

  /// The student says an exam mistake is understood: take it off the queue.
  Future<void> markExamResolved(String uid, MistakeItem item) async {
    if (item.source != MistakeSource.exam) return;
    await _updateExam(uid, item, examResolvePatch(), 'learn.mistakes.exam_resolve');
  }

  Future<void> _updateExam(String uid, MistakeItem item, Map<String, Object> patch, String reason) async {
    // update(), not set(merge): the document must already exist (the rules
    // never let the client create an exam item).
    unawaited(_items(uid).doc(item.questionId).update(patch).catchError((Object e, StackTrace st) {
      reportError(e, st, reason: reason);
    }));
  }

  /// Update for a reviewed exam item. Only [examWritableFields].
  static Map<String, Object> examReviewPatch(MistakeItem item, DateTime now) {
    final next = MistakeSrs.afterCorrect(item, now);
    return {
      'next_review_at': Timestamp.fromDate(next.nextReviewAt ?? now),
      'interval_days': next.intervalDays,
      'resolved': next.resolved,
      'last_reviewed_at': FieldValue.serverTimestamp(),
      'review_count': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  /// Update for an exam item the student resolved. Only [examWritableFields].
  static Map<String, Object> examResolvePatch() => {
        'resolved': true,
        'last_reviewed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
}
