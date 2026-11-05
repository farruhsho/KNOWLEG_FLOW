import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/dashboard/data/dashboard_providers.dart';

/// EXAM-04 / GAM-X4 / UX-09: the dashboard "latest exam" must stay live and
/// pick the newest completed attempt when the composite index is missing.
void main() {
  AttemptDoc attempt(String id, {String status = 'completed', DateTime? at, List<String> weak = const []}) => (
        id: id,
        data: {
          'status': status,
          'blueprint_id': 'ort_main_2026',
          if (at != null) 'completed_at': Timestamp.fromDate(at),
          'result': {'percent': 50, 'correct': 75, 'total': 150, 'weak_topics': weak},
        },
      );

  final missingIndex = FirebaseException(plugin: 'cloud_firestore', code: 'failed-precondition');
  final d1 = DateTime.utc(2026, 10, 1);
  final d2 = DateTime.utc(2026, 11, 1);
  final d3 = DateTime.utc(2026, 11, 3);

  test('pickLatestCompleted ignores unfinished attempts and sorts by completed_at', () {
    final latest = pickLatestCompleted([
      attempt('old', at: d1),
      attempt('running', status: 'in_progress'),
      attempt('new', at: d2),
    ]);
    expect(latest?.attemptId, 'new');
    expect(pickLatestCompleted([attempt('x', status: 'expired')]), isNull);
  });

  test('uses the primary query when its index exists', () async {
    final s = latestCompletedAttempt(
      primary: () => Stream.value([attempt('p', at: d2)]),
      fallback: () => fail('fallback must not run'),
      lastResort: () => fail('last resort must not run'),
    );
    expect((await s.first)?.attemptId, 'p');
  });

  test('missing composite index: stays live on the ordered fallback', () async {
    final fallback = StreamController<List<AttemptDoc>>();
    var lastResortCalls = 0;
    final results = <String?>[];
    final sub = latestCompletedAttempt(
      primary: () => Stream.error(missingIndex),
      fallback: () => fallback.stream,
      lastResort: () async {
        lastResortCalls++;
        return const [];
      },
    ).listen((v) => results.add(v?.attemptId));

    fallback.add([attempt('a', at: d1)]);
    await pumpEventQueue();
    // A new exam is completed: the listener must see it without a refresh.
    fallback.add([attempt('b', at: d3, weak: ['math.arithmetic']), attempt('a', at: d1)]);
    await pumpEventQueue();

    expect(results, ['a', 'b']);
    expect(lastResortCalls, 0);
    await sub.cancel();
    await fallback.close();
  });

  test('no index at all: one read, newest completed attempt (not the first returned)', () async {
    final s = latestCompletedAttempt(
      primary: () => Stream.error(missingIndex),
      fallback: () => Stream.error(missingIndex),
      lastResort: () async => [attempt('a', at: d1), attempt('c', at: d3), attempt('b', at: d2)],
    );
    expect(await s.toList().then((l) => l.map((e) => e?.attemptId).toList()), ['c']);
  });

  test('other errors are surfaced, not swallowed', () async {
    final s = latestCompletedAttempt(
      primary: () => Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')),
      fallback: () => fail('fallback must not run'),
      lastResort: () => fail('last resort must not run'),
    );
    await expectLater(s, emitsError(isA<FirebaseException>()));
  });
}
