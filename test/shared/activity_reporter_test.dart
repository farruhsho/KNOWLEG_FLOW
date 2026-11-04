import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/shared/services/activity_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The offline queue's SharedPreferences key (activity_reporter.dart).
const _queueKey = 'learn_pending_activity_v1';

Future<List<Map<String, dynamic>>> _queued() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_queueKey);
  if (raw == null) return const [];
  return [for (final e in jsonDecode(raw) as List) Map<String, dynamic>.from(e as Map)];
}

ActivityEvent _practice({String session = 's1', int seconds = 2400}) => ActivityEvent(
      kind: ActivityKinds.practiceAnswered,
      refId: session,
      count: 30,
      correct: 21,
      seconds: seconds,
    );

/// A fake `recordActivity`: records every payload and answers with the next
/// queued outcome (an exception to throw, or response data).
class _FakeBackend {
  final calls = <Map<String, dynamic>>[];
  final outcomes = <Object?>[];

  Future<Object?> call(Map<String, dynamic> payload) async {
    calls.add(Map.of(payload));
    final next = outcomes.isEmpty ? const {'xpAwarded': 0} : outcomes.removeAt(0);
    if (next is Exception) throw next;
    return next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActivityEvent.reportId (ARCHITECTURE §9.7)', () {
    test('every new event gets its own id of 8..64 [A-Za-z0-9_-]', () {
      final ids = {for (var i = 0; i < 200; i++) _practice().reportId};
      expect(ids, hasLength(200));
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
      }
    });

    test('the id is created once: toJson always sends the same one', () {
      final e = _practice();
      expect(e.toJson()['reportId'], e.reportId);
      expect(e.toJson()['reportId'], e.toJson()['reportId']);
    });

    test('newReportId uses the whole alphabet and the given generator', () {
      expect(ActivityEvent.newReportId(Random(7)), ActivityEvent.newReportId(Random(7)));
      final chars = {for (var i = 0; i < 300; i++) ...ActivityEvent.newReportId(Random(i)).split('')};
      expect(chars, containsAll(['A', 'z', '0', '9', '_', '-']));
    });

    test('a queued event keeps its id through toJson/fromJson', () {
      final e = _practice();
      final back = ActivityEvent.fromJson(jsonDecode(jsonEncode(e.toJson())))!;
      expect(back.reportId, e.reportId);
      expect(back.kind, e.kind);
      expect(back.refId, e.refId);
      expect(back.seconds, 2400);
      expect(back.count, 30);
      expect(back.correct, 21);
    });

    test('an event queued by an older build (no reportId) still loads, with a fresh valid id', () {
      final old = ActivityEvent.fromJson({'kind': 'lesson_completed', 'refId': 'l1', 'seconds': 300})!;
      expect(old.refId, 'l1');
      expect(old.seconds, 300);
      expect(ActivityEvent.reportIdPattern.hasMatch(old.reportId), isTrue);
    });

    test('a malformed stored id is replaced (the server would reject it)', () {
      for (final bad in ['short', 'has space in it', 'x' * 65, 'кириллица123']) {
        final e = ActivityEvent.fromJson({'kind': 'lesson_completed', 'refId': 'l1', 'reportId': bad})!;
        expect(e.reportId, isNot(bad));
        expect(ActivityEvent.reportIdPattern.hasMatch(e.reportId), isTrue);
      }
    });
  });

  group('ActivityReporter offline queue', () {
    late _FakeBackend backend;
    late ActivityReporter reporter;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      backend = _FakeBackend();
      reporter = ActivityReporter.withCall(backend.call);
    });

    test('the payload carries reportId next to the activity fields', () async {
      backend.outcomes.add({'xpAwarded': 12});
      final e = _practice();
      final res = await reporter.report(e);
      expect(res?.xpAwarded, 12);
      expect(backend.calls.single, {
        'kind': 'practice_answered',
        'refId': 's1',
        'correct': 21,
        'count': 30,
        'seconds': 2400,
        'reportId': e.reportId,
      });
    });

    test('a lost response (deadline-exceeded) is retried with the same reportId', () async {
      final e = _practice();
      backend.outcomes.add(FirebaseFunctionsException(message: 'timeout', code: 'deadline-exceeded'));
      expect(await reporter.report(e), isNull);
      expect((await _queued()).single['reportId'], e.reportId, reason: 'the id is persisted with the event');

      // Still failing: the event stays queued with the same id.
      backend.outcomes.add(FirebaseFunctionsException(message: 'down', code: 'unavailable'));
      await reporter.flushPending();
      expect((await _queued()).single['reportId'], e.reportId);

      // Delivered: the queue is empty.
      backend.outcomes.add({'xpAwarded': 0});
      await reporter.flushPending();
      expect(await _queued(), isEmpty);

      expect(backend.calls, hasLength(3));
      expect(backend.calls.map((c) => c['reportId']).toSet(), {e.reportId},
          reason: 'the server credits seconds once per reportId');
      expect(backend.calls.map((c) => c['seconds']).toSet(), {2400});
    });

    test('offline / client timeout (not a Functions error) is queued with the same id too', () async {
      final e = _practice(session: 's2');
      backend.outcomes.add(TimeoutException('client timeout'));
      await reporter.report(e);
      await reporter.flushPending();
      expect(backend.calls.map((c) => c['reportId']).toList(), [e.reportId, e.reportId]);
      expect(await _queued(), isEmpty);
    });

    test('a rejected event (invalid-argument) is dropped, not retried', () async {
      backend.outcomes.add(FirebaseFunctionsException(message: 'bad', code: 'invalid-argument'));
      await reporter.report(_practice());
      expect(await _queued(), isEmpty);
    });

    test('an event queued by an older build gets one id and keeps it across retries', () async {
      SharedPreferences.setMockInitialValues({
        _queueKey: jsonEncode([
          {'kind': 'lesson_completed', 'refId': 'l1', 'seconds': 300},
        ]),
      });
      backend.outcomes
        ..add(FirebaseFunctionsException(message: 'down', code: 'unavailable'))
        ..add({'xpAwarded': 10});
      await reporter.flushPending();
      final sent = backend.calls.single['reportId'] as String;
      expect(ActivityEvent.reportIdPattern.hasMatch(sent), isTrue);
      expect((await _queued()).single['reportId'], sent);

      await reporter.flushPending();
      expect(backend.calls.last['reportId'], sent);
      expect(await _queued(), isEmpty);
    });
  });
}
