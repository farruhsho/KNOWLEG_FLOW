import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_log.dart';
import '../models/lesson_model.dart';
import '../models/question_model.dart';
import '../models/subject_model.dart';
import '../models/user_progress_model.dart';
import 'data_exception.dart';
import 'question_pool.dart';

/// Real Firestore data for the learning feature.
///
/// There is **no fabricated fallback content** any more (FB-15, CMS-09):
/// reads either return real documents, an empty list/null (genuinely no
/// data), or throw a [DataException] the UI turns into an error state with a
/// retry. Individual malformed documents are skipped and reported instead of
/// replacing the whole list.
class FirebaseDataService {
  static final FirebaseDataService _instance = FirebaseDataService._internal();
  factory FirebaseDataService() => _instance;
  FirebaseDataService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final Random _random = Random();

  // ========== SUBJECTS ==========

  /// All active subjects, ordered by `order`. Throws [DataException].
  Future<List<SubjectModel>> getSubjects() async {
    try {
      final snapshot = await _firestore.collection(AppConstants.collectionSubjects).get();
      final subjects = _parseAll(snapshot.docs, (d) => SubjectModel.fromFirestore(d.data(), id: d.id), 'subject')
          .where((s) => s.isActive)
          .toList()
        ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.id.compareTo(b.id));
      return subjects;
    } catch (e, st) {
      reportError(e, st, reason: 'learn.getSubjects');
      throw DataException.from(e);
    }
  }

  /// A subject by id, or null when it does not exist. Throws [DataException].
  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      final doc = await _firestore.collection(AppConstants.collectionSubjects).doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return SubjectModel.fromFirestore(data, id: doc.id);
    } catch (e, st) {
      reportError(e, st, reason: 'learn.getSubjectById');
      throw DataException.from(e);
    }
  }

  // ========== LESSONS ==========

  /// Lessons of a subject ordered by `order`. Reads both `subject_id`
  /// (canonical) and `subjectId` (seed/legacy) and merges them, without an
  /// orderBy so no composite index is required. Throws [DataException].
  Future<List<LessonModel>> getLessonsBySubject(String subjectId) async {
    try {
      final col = _firestore.collection(AppConstants.collectionLessons);
      final snaps = await Future.wait([
        col.where('subject_id', isEqualTo: subjectId).get(),
        col.where('subjectId', isEqualTo: subjectId).get(),
      ]);
      final byId = <String, LessonModel>{};
      for (final snap in snaps) {
        for (final l in _parseAll(snap.docs, (d) => LessonModel.fromFirestore(d.data(), id: d.id), 'lesson')) {
          if (l.isActive) byId[l.id] = l;
        }
      }
      return byId.values.toList()..sort(_lessonOrder);
    } catch (e, st) {
      reportError(e, st, reason: 'learn.getLessonsBySubject');
      throw DataException.from(e);
    }
  }

  /// Up to [limit] active lessons across all subjects, in a stable order
  /// (subject, order, id). Used by the daily lesson rotation.
  Future<List<LessonModel>> getAllLessons({int limit = 300}) async {
    try {
      final snap = await _firestore.collection(AppConstants.collectionLessons).limit(limit).get();
      return _parseAll(snap.docs, (d) => LessonModel.fromFirestore(d.data(), id: d.id), 'lesson')
          .where((l) => l.isActive)
          .toList()
        ..sort((a, b) {
          final s = a.subjectId.compareTo(b.subjectId);
          return s != 0 ? s : _lessonOrder(a, b);
        });
    } catch (e, st) {
      reportError(e, st, reason: 'learn.getAllLessons');
      throw DataException.from(e);
    }
  }

  /// A lesson by id, or null when it does not exist. Throws [DataException].
  Future<LessonModel?> getLessonById(String id) async {
    try {
      final doc = await _firestore.collection(AppConstants.collectionLessons).doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return LessonModel.fromFirestore(data, id: doc.id);
    } catch (e, st) {
      reportError(e, st, reason: 'learn.getLessonById');
      throw DataException.from(e);
    }
  }

  /// Lesson id assigned for [dayKey] in `daily_lessons/{YYYY-MM-DD}` by the
  /// content team, or null (then the client rotation decides).
  Future<String?> getAssignedDailyLessonId(String dayKey) async {
    try {
      final doc = await _firestore.collection('daily_lessons').doc(dayKey).get();
      final data = doc.data();
      if (data == null) return null;
      final id = data['lesson_id'] ?? data['lessonId'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (e, st) {
      // Optional collection: missing rules/doc must not block the lesson.
      reportError(e, st, reason: 'learn.getAssignedDailyLessonId');
      return null;
    }
  }

  static int _lessonOrder(LessonModel a, LessonModel b) =>
      a.order != b.order ? a.order.compareTo(b.order) : a.id.compareTo(b.id);

  // ========== QUESTIONS ==========

  /// Random practice questions, paginated from a random document-id pivot.
  ///
  /// * filters by subject on both `subject_id` and `subjectId` (FB-04);
  /// * skips inactive / unverified-AI / draft questions (FB-18, EXAM-12);
  /// * skips questions without a valid answer key (FB-05);
  /// * returns fewer than [count] (possibly none) when the bank is small —
  ///   never fabricated items. Throws [DataException].
  Future<List<QuestionModel>> getQuestions({
    int count = AppConstants.practiceSessionSize,
    String? subjectId,
    int? difficulty,
  }) async {
    try {
      final col = _firestore.collection(AppConstants.collectionQuestions);
      final bases = <Query<Map<String, dynamic>>>[
        if (subjectId == null) col,
        if (subjectId != null) col.where('subject_id', isEqualTo: subjectId),
        if (subjectId != null) col.where('subjectId', isEqualTo: subjectId),
      ].map((q) => difficulty == null ? q : q.where('difficulty', isEqualTo: difficulty)).toList();

      final pivot = QuestionPool.randomPivot(_random);
      final pageSize = max(count * 4, AppConstants.practiceCandidatePool);
      final pools = await Future.wait(bases.map((q) => _collectFrom(q, pivot, pageSize, count)));
      final pool = pools.expand((p) => p);
      return QuestionPool.sample(pool, count, _random, idOf: (q) => q.id);
    } catch (e, st) {
      reportError(e, st, reason: 'learn.getQuestions');
      throw DataException.from(e);
    }
  }

  /// Walks the id-ordered index from [pivot], wrapping around once, until
  /// enough servable questions are collected or the range is exhausted.
  Future<List<QuestionModel>> _collectFrom(
    Query<Map<String, dynamic>> base,
    String pivot,
    int pageSize,
    int wanted,
  ) async {
    final out = <QuestionModel>[];
    final ordered = base.orderBy(FieldPath.documentId);
    const maxPages = 3;

    Future<void> walk(Query<Map<String, dynamic>> start, {String? endBefore}) async {
      var query = start;
      for (var page = 0; page < maxPages && out.length < wanted * 2; page++) {
        var q = query.limit(pageSize);
        if (endBefore != null) q = q.endBefore([endBefore]);
        final snap = await q.get();
        for (final d in snap.docs) {
          if (!QuestionPool.isServable(d.data())) continue;
          final question = QuestionModel.tryFromFirestore(d);
          if (question != null) out.add(question);
        }
        if (snap.docs.length < pageSize) return;
        query = ordered.startAfterDocument(snap.docs.last);
      }
    }

    await walk(ordered.startAt([pivot]));
    if (out.length < wanted * 2) {
      await walk(ordered, endBefore: pivot);
    }
    return out;
  }

  /// Questions by id in the given order; missing, inactive or ungradable
  /// ones are dropped. Throws [DataException].
  Future<List<QuestionModel>> getQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final col = _firestore.collection(AppConstants.collectionQuestions);
      final docs = await Future.wait(ids.toSet().map((id) => col.doc(id).get()));
      final byId = <String, QuestionModel>{};
      for (final d in docs) {
        final data = d.data();
        if (data == null || !QuestionPool.isServable(data)) continue;
        final q = QuestionModel.tryFromFirestore(d);
        if (q != null) byId[q.id] = q;
      }
      return [for (final id in ids) if (byId[id] != null) byId[id]!];
    } catch (e, st) {
      reportError(e, st, reason: 'learn.getQuestionsByIds');
      throw DataException.from(e);
    }
  }

  /// A question by id, or null. Throws [DataException].
  Future<QuestionModel?> getQuestionById(String id) async {
    final list = await getQuestionsByIds([id]);
    return list.isEmpty ? null : list.first;
  }

  // ========== USER PROGRESS ==========

  /// Practice aggregates of a user. A missing document reads as empty
  /// progress (nothing is written). Returns null only on read errors
  /// (reported), so legacy callers keep working.
  Future<UserProgressModel?> getUserProgress(String userId) async {
    try {
      final doc = await _firestore.collection(AppConstants.collectionUserProgress).doc(userId).get();
      final data = doc.data();
      if (!doc.exists || data == null) return UserProgressModel.empty(userId);
      return UserProgressModel.fromFirestore(data, doc.id);
    } catch (e, st) {
      reportError(e, st, reason: 'learn.getUserProgress');
      return null;
    }
  }

  /// Live practice aggregates (cache first, then server).
  Stream<UserProgressModel> watchUserProgress(String userId) {
    return _firestore
        .collection(AppConstants.collectionUserProgress)
        .doc(userId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      return data == null ? UserProgressModel.empty(userId) : UserProgressModel.fromFirestore(data, doc.id);
    });
  }

  /// Сохранить прогресс пользователя (legacy full-document merge).
  Future<void> saveUserProgress(UserProgressModel progress) async {
    await _firestore
        .collection(AppConstants.collectionUserProgress)
        .doc(progress.userId)
        .set(progress.toFirestore(), SetOptions(merge: true));
  }

  /// Marks a lesson completed with an atomic arrayUnion (no read-modify-write).
  /// The returned future completes when the server acknowledges; callers on
  /// the UI path should not await it (the local cache updates immediately).
  Future<void> markLessonCompleted(String userId, String lessonId) {
    return _firestore.collection(AppConstants.collectionUserProgress).doc(userId).set({
      'completedLessons': FieldValue.arrayUnion([lessonId]),
      'lastActivityDate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ========== ORT TESTS (legacy admin) ==========

  /// Get all ORT tests
  Future<List<Map<String, dynamic>>> getOrtTests() async {
    try {
      final snapshot = await _firestore.collection('ort_tests').get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.data()['id'] ?? doc.id}).toList();
    } catch (e, st) {
      reportError(e, st, reason: 'learn.getOrtTests');
      return [];
    }
  }

  // ========== helpers ==========

  List<T> _parseAll<T>(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    T Function(QueryDocumentSnapshot<Map<String, dynamic>>) parse,
    String kind,
  ) {
    final out = <T>[];
    for (final d in docs) {
      try {
        out.add(parse(d));
      } catch (e, st) {
        reportError(e, st, reason: 'learn.parse.$kind:${d.id}');
      }
    }
    return out;
  }
}
