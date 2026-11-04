import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_contract.dart';
import '../../../core/network/firebase_service.dart';
import '../../../providers/auth_provider.dart';
import '../../exam/exam_routes.dart';
import '../domain/dashboard_models.dart';

/// "Now", overridable in tests.
final dashboardClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Live `user_stats/{uid}` (null = no document yet, i.e. a new user).
final userStatsProvider = StreamProvider<UserStats?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return FirebaseService.firestore
      .collection(Collections.userStats)
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? UserStats.fromMap(s.data()) : null);
});

/// Latest completed exam attempt of the user, or null.
final latestExamProvider = StreamProvider<LatestExamSummary?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return _latestCompletedAttempt(FirebaseService.firestore, uid);
});

Stream<LatestExamSummary?> _latestCompletedAttempt(
  FirebaseFirestore db,
  String uid,
) async* {
  final attempts = db.collection(Collections.examAttempts);
  try {
    // Needs the composite index (uid ASC, status ASC, completed_at DESC).
    final query = attempts
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('completed_at', descending: true)
        .limit(1);
    await for (final snap in query.snapshots()) {
      if (snap.docs.isEmpty) {
        yield null;
      } else {
        final doc = snap.docs.first;
        yield LatestExamSummary.fromDoc(doc.id, doc.data());
      }
    }
  } on FirebaseException catch (e) {
    if (e.code != 'failed-precondition') rethrow;
    // Index not deployed yet: single-field query, sorted on the client.
    final snap = await attempts.where('uid', isEqualTo: uid).limit(50).get();
    final completed = snap.docs
        .map((d) => LatestExamSummary.fromDoc(d.id, d.data()))
        .whereType<LatestExamSummary>()
        .toList()
      ..sort((a, b) => (b.completedAt ?? DateTime(0))
          .compareTo(a.completedAt ?? DateTime(0)));
    yield completed.isEmpty ? null : completed.first;
  }
}

/// The recommendation shown in the "Next step" card. Loading while either
/// source is loading; errors propagate so the card can offer a retry.
final nextStepProvider = Provider<AsyncValue<NextStep>>((ref) {
  final stats = ref.watch(userStatsProvider);
  final latest = ref.watch(latestExamProvider);
  if (latest.hasError) {
    return AsyncValue.error(latest.error!, latest.stackTrace ?? StackTrace.empty);
  }
  if (latest.isLoading && !latest.hasValue) return const AsyncValue.loading();
  return AsyncValue.data(decideNextStep(
    examsCompleted: stats.valueOrNull?.examsCompleted ?? 0,
    latest: latest.valueOrNull,
  ));
});

/// Section/subject titles from the bundled ORT blueprints, keyed by section
/// id and subject area (e.g. 'math' → {'ru': 'Математика', …}).
final examAreaTitlesProvider =
    FutureProvider<Map<String, Map<String, String>>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/exam_blueprints.json');
  return parseAreaTitles(raw);
});

Map<String, Map<String, String>> parseAreaTitles(String raw) {
  final result = <String, Map<String, String>>{};
  final decoded = jsonDecode(raw);
  final blueprints = decoded is Map ? decoded['blueprints'] : null;
  if (blueprints is! List) return result;
  for (final bp in blueprints.whereType<Map>()) {
    final sections = bp['sections'];
    if (sections is! List) continue;
    for (final section in sections.whereType<Map>()) {
      final title = section['title'];
      if (title is! Map) continue;
      final titles = {
        for (final e in title.entries)
          if (e.value is String) e.key.toString(): e.value as String,
      };
      for (final key in [section['id'], section['subject_area']]) {
        if (key is String && key.isNotEmpty) result.putIfAbsent(key, () => titles);
      }
    }
  }
  return result;
}

/// Slot for the exam package's resume banner, so widget tests can replace
/// it without Firebase.
final examResumeBannerBuilderProvider =
    Provider<Widget Function()>((ref) => buildExamResumeBanner);
