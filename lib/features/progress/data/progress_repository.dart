import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../../core/backend/backend_contract.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/json_read.dart';
import '../../../shared/models/exam_attempt_summary.dart';
import '../../../shared/models/subject_model.dart';
import '../../../shared/models/user_progress_model.dart';
import '../../../shared/models/user_stats_model.dart';
import '../../../shared/services/data_exception.dart';
import '../../../shared/services/firebase_data_service.dart';
import '../../../shared/services/gamification_service.dart';
import '../../../shared/services/mistakes_service.dart';

/// Everything the progress screen shows, from real sources only.
class ProgressSnapshot {
  final UserStats? stats;
  final UserProgressModel? progress;
  final List<ExamAttemptSummary>? attempts; // null = could not load
  final int dueMistakes;
  final Map<String, Map<String, String>> blueprintTitles;
  final Map<String, Map<String, String>> sectionTitles;
  final List<SubjectModel> subjects;

  const ProgressSnapshot({
    required this.stats,
    required this.progress,
    required this.attempts,
    required this.dueMistakes,
    required this.blueprintTitles,
    required this.sectionTitles,
    required this.subjects,
  });

  List<ExamAttemptSummary> get completedAttempts =>
      (attempts ?? const <ExamAttemptSummary>[]).where((a) => a.isCompleted).toList()
        ..sort((a, b) => (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));

  bool get isEmpty =>
      (progress?.practiceAnswered ?? 0) == 0 &&
      (progress?.completedLessons.isEmpty ?? true) &&
      completedAttempts.isEmpty &&
      (stats?.xp ?? 0) == 0;
}

class ProgressRepository {
  final _db = FirebaseFirestore.instance;

  Future<ProgressSnapshot> load(String uid) async {
    final results = await Future.wait<Object?>([
      GamificationService().getStats(uid).then<Object?>((v) => v).catchError((Object e, StackTrace st) {
        reportError(e, st, reason: 'learn.progress.stats');
        return null;
      }),
      FirebaseDataService().getUserProgress(uid),
      _attempts(uid),
      _dueMistakes(uid),
      _blueprints(),
      FirebaseDataService().getSubjects().then<Object?>((v) => v).catchError((Object _) => <SubjectModel>[]),
    ]);
    final stats = results[0] as UserStats?;
    final progress = results[1] as UserProgressModel?;
    if (stats == null && progress == null) {
      // Nothing readable at all: surface a real error with retry.
      throw const DataException(DataFailure.unknown);
    }
    final bp = results[4] as (Map<String, Map<String, String>>, Map<String, Map<String, String>>);
    return ProgressSnapshot(
      stats: stats,
      progress: progress,
      attempts: results[2] as List<ExamAttemptSummary>?,
      dueMistakes: results[3] as int,
      blueprintTitles: bp.$1,
      sectionTitles: bp.$2,
      subjects: results[5] as List<SubjectModel>,
    );
  }

  Future<List<ExamAttemptSummary>?> _attempts(String uid) async {
    try {
      final snap = await _db.collection(Collections.examAttempts).where('uid', isEqualTo: uid).limit(100).get();
      return [for (final d in snap.docs) ExamAttemptSummary.fromMap(d.id, d.data())];
    } catch (e, st) {
      reportError(e, st, reason: 'learn.progress.attempts');
      return null;
    }
  }

  /// Due = unresolved and next_review_at <= now. Querying the due range
  /// (index resolved ASC, next_review_at ASC) counts exactly the due items,
  /// whatever the size of the queue (GAM-X1).
  Future<int> _dueMistakes(String uid) async {
    try {
      final snap = await _db
          .collection(Collections.userMistakes)
          .doc(uid)
          .collection(Collections.userMistakeItems)
          .where('resolved', isEqualTo: false)
          .where('next_review_at', isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .orderBy('next_review_at')
          .limit(MistakesService.openLimit)
          .get();
      return snap.docs.length;
    } catch (e, st) {
      reportError(e, st, reason: 'learn.progress.mistakes');
      return 0;
    }
  }

  /// Blueprint and section titles from the bundled blueprint asset.
  static Future<(Map<String, Map<String, String>>, Map<String, Map<String, String>>)> _blueprints() async {
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/data/exam_blueprints.json'));
      final list = raw is List ? raw : (JsonRead.asMap(raw)?['blueprints'] as List? ?? const []);
      final titles = <String, Map<String, String>>{};
      final sections = <String, Map<String, String>>{};
      for (final b in list.map(JsonRead.asMap).whereType<Map<String, dynamic>>()) {
        final id = JsonRead.stringOr(b, ['id']);
        final title = JsonRead.localized(b['title']);
        titles[id] = title;
        titles[id.replaceFirst(RegExp(r'_\d{4}$'), '')] = title;
        for (final s in (b['sections'] as List? ?? const []).map(JsonRead.asMap).whereType<Map<String, dynamic>>()) {
          sections.putIfAbsent(JsonRead.stringOr(s, ['id']), () => JsonRead.localized(s['title']));
        }
      }
      return (titles, sections);
    } catch (e, st) {
      reportError(e, st, reason: 'learn.progress.blueprints');
      return (<String, Map<String, String>>{}, <String, Map<String, String>>{});
    }
  }
}
