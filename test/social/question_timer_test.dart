import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_session.dart';
import 'package:knowledge_flow/features/exam/domain/question_timing.dart';
import 'package:knowledge_flow/features/exam/presentation/controllers/exam_runner_controller.dart';

import '../exam/exam_fakes.dart';
import '../exam/exam_test_fixtures.dart';

/// Per-question time capture (ARCHITECTURE §9.5).
void main() {
  final base = DateTime.utc(2026, 11, 4, 9);
  DateTime at(int seconds) => base.add(Duration(seconds: seconds));

  group('QuestionTimer', () {
    test('accumulates only while a question is on screen', () {
      final timer = QuestionTimer(sectionId: 'math', capSeconds: 600)
        ..focus('q1', at(0))
        ..focus('q2', at(30))
        ..focus('q1', at(45))
        ..focus(null, at(60)); // interstitial: nothing visible
      expect(timer.secondsAt(at(500)), {'q1': 45, 'q2': 15});
    });

    test('pause / resume (app in background) stops and restarts the clock', () {
      final timer = QuestionTimer(sectionId: 'math', capSeconds: 600)..focus('q1', at(0));
      timer.pause(at(10));
      expect(timer.isRunning, isFalse);
      // Navigating while paused does not count either.
      timer.focus('q2', at(100));
      timer.resume(at(200));
      expect(timer.secondsAt(at(205)), {'q1': 10, 'q2': 5});
      // Double pause / resume are harmless.
      timer
        ..pause(at(205))
        ..pause(at(300))
        ..resume(at(400))
        ..resume(at(401));
      expect(timer.secondsAt(at(402)), {'q1': 10, 'q2': 7});
    });

    test('refocusing the same question does not restart or double count', () {
      final timer = QuestionTimer(sectionId: 'math', capSeconds: 600)..focus('q1', at(0));
      for (var i = 1; i <= 20; i++) {
        timer.focus('q1', at(i));
      }
      expect(timer.secondsAt(at(30)), {'q1': 30});
    });

    test('caps every question at the section duration', () {
      final timer = QuestionTimer(sectionId: 'verbal', capSeconds: 1800)..focus('q1', at(0));
      expect(timer.secondsAt(at(5000)), {'q1': 1800});
      timer.focus('q2', at(6000));
      expect(timer.secondsAt(at(6010))['q1'], 1800);
      expect(timer.secondsAt(at(6010))['q2'], 10);
    });

    test('a clock jumping backwards adds nothing; later time counts normally', () {
      final timer = QuestionTimer(sectionId: 'math', capSeconds: 600)..focus('q1', at(100));
      expect(timer.secondsAt(at(50)), isEmpty);
      expect(timer.secondsAt(at(60)), {'q1': 10});
    });

    test('only the section\'s questions are reported', () {
      final timer = QuestionTimer(sectionId: 'math', capSeconds: 600)
        ..focus('q1', at(0))
        ..focus('stray', at(10))
        ..focus(null, at(20));
      expect(timer.secondsAt(at(30), questionIds: ['q1', 'q2']), {'q1': 10});
    });

    test('survives a restart through JSON (Hive)', () {
      final timer = QuestionTimer(sectionId: 'math', capSeconds: 600)
        ..focus('q1', at(0))
        ..focus('q2', at(20));
      final json = timer.toJson(at(25));
      final restored = QuestionTimer.fromJson(json)!;
      expect(restored.sectionId, 'math');
      expect(restored.capSeconds, 600);
      expect(restored.activeQuestionId, isNull, reason: 'nothing runs until the runner focuses again');
      restored.focus('q2', at(1000));
      expect(restored.secondsAt(at(1003)), {'q1': 20, 'q2': 8});
      expect(QuestionTimer.fromJson({'ms': {'q1': 5}}), isNull);
      // Values beyond the cap are clamped on restore.
      expect(QuestionTimer.fromJson({'section_id': 's', 'cap_sec': 10, 'ms': {'q': 99999}})!.secondsAt(at(0)),
          {'q': 10});
    });
  });

  group('submission carries timings', () {
    test('beginSubmit sends seconds per question, clamped and filtered', () {
      final s = ExamSession.fromPayload(startPayload(), clientNow: t0, uid: 'u1');
      final ids = [for (final q in s.questions) q.id];
      final locked = s.beginSubmit(
        now: t0.add(const Duration(minutes: 1)),
        timings: {ids.first: 42, ids.last: 99999, 'not-in-section': 7},
      );
      final sub = locked.pendingSubmission!;
      final total = s.section.durationSec;
      expect(sub.timings, {ids.first: 42, ids.last: total});
      expect(sub.toCallableData()['timings'], {ids.first: 42, ids.last: total});
      // Round-trips through the local copy (retry after an app kill).
      expect(SectionSubmission.fromJson(sub.toJson()).timings, sub.timings);
    });

    test('no timings → the field is omitted (older clients look the same)', () {
      final s = ExamSession.fromPayload(startPayload(), clientNow: t0, uid: 'u1');
      final sub = s.beginSubmit(now: t0).pendingSubmission!;
      expect(sub.toCallableData().containsKey('timings'), isFalse);
    });

    test('the runner measures the time each question is on screen and sends it', () async {
      var now = t0;
      final remote = FakeExamRemote(
        onGetState: startPayload,
      );
      remote.onSubmit = (_) => SubmitSectionResponse(completed: false, next: nextPayload(deviceNow: now));
      final store = MemoryExamStore();
      final c = ExamRunnerController(
        attemptId: 'att1',
        remote: remote,
        store: store,
        drafts: RecordingDraftSink(),
        clock: () => now,
        uid: 'u1',
        tickInterval: const Duration(days: 1),
        draftInterval: const Duration(days: 1),
      );
      addTearDown(c.dispose);
      await c.load();
      final ids = [for (final q in c.state.session!.questions) q.id];

      now = now.add(const Duration(seconds: 12)); // q1 on screen
      c.next();
      now = now.add(const Duration(seconds: 5)); // q2 on screen
      c.onAppBackground();
      now = now.add(const Duration(minutes: 3)); // in background: not counted
      c.onAppForeground();
      now = now.add(const Duration(seconds: 3)); // q2 again
      expect(c.questionTimings(), {ids[0]: 12, ids[1]: 8});

      await c.submitSection();
      expect(remote.submissions.single.timings, {ids[0]: 12, ids[1]: 8});
      await c.pendingWrites;
      expect(store.timings, isNotNull, reason: 'timings are persisted in the Hive session');
    });

    test('timings restored after an app kill continue to count', () async {
      var now = t0;
      final remote = FakeExamRemote(onGetState: startPayload);
      final store = MemoryExamStore();
      final first = ExamRunnerController(
        attemptId: 'att1',
        remote: remote,
        store: store,
        drafts: RecordingDraftSink(),
        clock: () => now,
        uid: 'u1',
        tickInterval: const Duration(days: 1),
        draftInterval: const Duration(days: 1),
      );
      await first.load();
      final q1 = first.state.session!.questions.first.id;
      now = now.add(const Duration(seconds: 20));
      first.onAppBackground(); // persists
      await first.pendingWrites;
      first.dispose();

      now = now.add(const Duration(minutes: 2));
      final second = ExamRunnerController(
        attemptId: 'att1',
        remote: remote,
        store: store,
        drafts: RecordingDraftSink(),
        clock: () => now,
        uid: 'u1',
        tickInterval: const Duration(days: 1),
        draftInterval: const Duration(days: 1),
      );
      addTearDown(second.dispose);
      await second.load();
      now = now.add(const Duration(seconds: 4));
      expect(second.questionTimings()[q1], 24);
    });
  });
}
