import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/backend/backend_contract.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_log.dart';
import '../models/mistake_model.dart';
import '../models/practice_session_model.dart';
import '../models/user_progress_model.dart';
import 'activity_reporter.dart';
import 'gamification_service.dart';

/// Records finished learning activity as ONE non-blocking operation
/// (GAM-12, FB-25, EXAM-14):
///
/// 1. one `WriteBatch` with `FieldValue.increment` for the legacy
///    `user_progress` aggregates plus the practice mistakes
///    (`user_mistakes/{uid}/items/{questionId}`, source `practice`);
///    the batch is committed without awaiting the server, so Firestore's
///    offline cache applies it immediately and syncs later;
/// 2. the `recordActivity` callable for **server-side** XP (queued and
///    retried when offline);
/// 3. cosmetic daily-quest progress (best effort).
///
/// The returned future resolves with the server's answer (or null) and is
/// only for optional display ("+12 XP"); never await it before navigating.
class LearningActivityService {
  LearningActivityService._();
  static final LearningActivityService instance = LearningActivityService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<ActivityResult?> recordPracticeSession(String uid, PracticeSessionResult s) {
    try {
      _commitPracticeBatch(uid, s);
    } catch (e, st) {
      reportError(e, st, reason: 'learn.practice.batch');
    }
    unawaited(GamificationService()
        .recordPracticeQuests(
          uid,
          answered: s.answered,
          bestCorrectRun: s.bestCorrectRun,
        )
        .catchError((Object e, StackTrace st) => reportError(e, st, reason: 'learn.practice.quests')));
    if (s.answered == 0) return Future.value(null);
    return ActivityReporter.instance.report(ActivityEvent(
      kind: ActivityKinds.practiceAnswered,
      refId: s.sessionId,
      count: s.answered,
      correct: s.correct,
      seconds: s.elapsedSeconds,
    ));
  }

  void _commitPracticeBatch(String uid, PracticeSessionResult s) {
    const inc = FieldValue.increment;
    final batch = _db.batch();
    final now = DateTime.now();

    final bySubject = <String, PracticeTally>{};
    final byTopic = <String, PracticeTally>{};
    final wrongByTopic = <String, int>{};
    for (final a in s.answers) {
      if (a.isSkipped) continue;
      final subject = a.question.subjectId.isNotEmpty ? a.question.subjectId : (s.subjectId ?? '');
      if (subject.isNotEmpty) bySubject[subject] = _add(bySubject[subject], a.isCorrect);
      final topic = a.question.topicId;
      if (topic != null && topic.isNotEmpty) {
        byTopic[topic] = _add(byTopic[topic], a.isCorrect);
        if (a.isWrong) wrongByTopic[topic] = (wrongByTopic[topic] ?? 0) + 1;
      }
    }

    Map<String, dynamic> tallyMap(Map<String, PracticeTally> m) => {
          for (final e in m.entries)
            ProgressKeys.encode(e.key): {'answered': inc(e.value.answered), 'correct': inc(e.value.correct)},
        };

    batch.set(
      _db.collection(AppConstants.collectionUserProgress).doc(uid),
      {
        // Legacy aggregate: one finished practice set.
        'testsCompleted': inc(1),
        'lastActivityDate': FieldValue.serverTimestamp(),
        'practice_sessions': inc(1),
        'practice_answered': inc(s.answered),
        'practice_correct': inc(s.correct),
        'practice_skipped': inc(s.skipped),
        'practice_seconds': inc(s.elapsedSeconds),
        if (bySubject.isNotEmpty) 'practice_by_subject': tallyMap(bySubject),
        if (byTopic.isNotEmpty) 'practice_by_topic': tallyMap(byTopic),
        if (wrongByTopic.isNotEmpty)
          'errorsByTopic': {
            for (final e in wrongByTopic.entries) ProgressKeys.encode(e.key): inc(e.value),
          },
      },
      SetOptions(merge: true),
    );

    final schedule = MistakeSrs.firstSchedule(now);
    final items = _db.collection(Collections.userMistakes).doc(uid).collection(Collections.userMistakeItems);
    for (final a in s.answers.where((a) => a.isWrong)) {
      final q = a.question;
      batch.set(
        items.doc(q.id),
        {
          'question_id': q.id,
          'source': 'practice',
          'subject_id': q.subjectId.isNotEmpty ? q.subjectId : (s.subjectId ?? ''),
          'section_id': q.sectionId,
          'topic_id': q.topicId,
          'wrong_count': inc(1),
          'last_wrong_at': FieldValue.serverTimestamp(),
          'next_review_at': Timestamp.fromDate(schedule.nextReviewAt),
          'interval_days': schedule.intervalDays,
          'resolved': false,
        },
        SetOptions(merge: true),
      );
    }

    // Not awaited: with offline persistence the cache is updated now and the
    // server acknowledgement may take arbitrarily long (GAM-12).
    unawaited(batch.commit().catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'learn.practice.commit');
    }));
  }

  static PracticeTally _add(PracticeTally? t, bool correct) => PracticeTally(
        answered: (t?.answered ?? 0) + 1,
        correct: (t?.correct ?? 0) + (correct ? 1 : 0),
      );

  /// Lesson completion: idempotent arrayUnion on `user_progress` plus the
  /// server XP event (refId = lessonId → XP at most once per lesson).
  /// [seconds]: time spent on the lesson screen (study-time stats, §9.5).
  Future<ActivityResult?> recordLessonCompleted(String uid, String lessonId, {int? seconds}) {
    unawaited(_db.collection(AppConstants.collectionUserProgress).doc(uid).set({
      'completedLessons': FieldValue.arrayUnion([lessonId]),
      'lastActivityDate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'learn.lesson.commit');
    }));
    return ActivityReporter.instance.report(ActivityEvent(
      kind: ActivityKinds.lessonCompleted,
      refId: lessonId,
      seconds: seconds,
    ));
  }
}
