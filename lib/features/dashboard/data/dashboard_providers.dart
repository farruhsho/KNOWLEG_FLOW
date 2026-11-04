import 'dart:async';
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
  final attempts = FirebaseService.firestore.collection(Collections.examAttempts);
  List<AttemptDoc> docs(QuerySnapshot<Map<String, dynamic>> s) =>
      [for (final d in s.docs) (id: d.id, data: d.data())];
  return latestCompletedAttempt(
    // Composite index (uid ASC, status ASC, completed_at DESC).
    primary: () => attempts
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('completed_at', descending: true)
        .limit(1)
        .snapshots()
        .map(docs),
    // Index (uid ASC, completed_at DESC). Only completed attempts have a
    // completed_at, so the newest ones are completed; still live.
    fallback: () => attempts
        .where('uid', isEqualTo: uid)
        .orderBy('completed_at', descending: true)
        .limit(_fallbackLimit)
        .snapshots()
        .map(docs),
    // No composite index at all: one unordered read, sorted here.
    lastResort: () => attempts.where('uid', isEqualTo: uid).limit(50).get().then(docs),
  );
});

const _fallbackLimit = 10;

/// One `exam_attempts` document: id + data.
typedef AttemptDoc = ({String id, Map<String, dynamic> data});

/// Newest completed attempt among [docs] (by completed_at), or null.
LatestExamSummary? pickLatestCompleted(Iterable<AttemptDoc> docs) {
  LatestExamSummary? best;
  for (final d in docs) {
    final s = LatestExamSummary.fromDoc(d.id, d.data);
    if (s == null) continue;
    final at = s.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bestAt = best?.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (best == null || at.isAfter(bestAt)) best = s;
  }
  return best;
}

bool _missingIndex(Object e) => e is FirebaseException && e.code == 'failed-precondition';

/// Live latest completed attempt (EXAM-04 / GAM-X4 / UX-09).
///
/// Uses [primary] (needs the composite index). If that index is missing it
/// stays live on [fallback] (ordered by completed_at, existing index)
/// instead of a single stale read; [lastResort] is used only if neither
/// index exists.
Stream<LatestExamSummary?> latestCompletedAttempt({
  required Stream<List<AttemptDoc>> Function() primary,
  required Stream<List<AttemptDoc>> Function() fallback,
  required Future<List<AttemptDoc>> Function() lastResort,
}) =>
    _switchOnMissingIndex(
      primary,
      () => _switchOnMissingIndex(fallback, () => Stream.fromFuture(lastResort())),
    ).map(pickLatestCompleted);

/// Events of [first]; if it fails because an index is missing, continues
/// with [next]. Unlike an `async*` + `await for` chain, cancelling the result
/// cancels the live Firestore listener immediately.
Stream<T> _switchOnMissingIndex<T>(Stream<T> Function() first, Stream<T> Function() next) {
  late final StreamController<T> out;
  StreamSubscription<T>? sub;
  void listen(Stream<T> source, {required bool canSwitch}) {
    sub = source.listen(
      out.add,
      onError: (Object e, StackTrace st) {
        if (canSwitch && _missingIndex(e)) {
          final old = sub;
          listen(next(), canSwitch: false);
          old?.cancel();
        } else {
          out.addError(e, st);
        }
      },
      onDone: out.close,
    );
  }

  out = StreamController<T>(
    onListen: () => listen(first(), canSwitch: true),
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
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
