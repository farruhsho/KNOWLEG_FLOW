import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_session.dart';

import 'exam_test_fixtures.dart';

void main() {
  ExamSession start({int skewMs = 0, Duration timeLeft = const Duration(minutes: 10)}) =>
      ExamSession.fromPayload(startPayload(skewMs: skewMs, timeLeft: timeLeft),
          clientNow: t0, uid: 'u1');

  group('navigation and answers', () {
    test('free navigation inside the section', () {
      var s = start();
      expect(s.phase, ExamPhase.inSection);
      expect(s.currentIndex, 0);
      s = s.next().next();
      expect(s.currentIndex, 2);
      expect(identical(s.next(), s), isTrue, reason: 'cannot go past the last');
      s = s.goTo(0);
      expect(s.currentIndex, 0);
      expect(identical(s.previous(), s), isTrue);
      expect(identical(s.goTo(-1), s), isTrue);
      expect(identical(s.goTo(3), s), isTrue);
    });

    test('answers can be changed and cleared; invalid options are ignored', () {
      var s = start();
      s = s.answer('q3', 'B', now: t0);
      expect(s.answerOf('q3'), 'B');
      s = s.answer('q3', 'E', now: t0); // part II has 5 options
      expect(s.answerOf('q3'), 'E');
      expect(identical(s.answer('q3', 'F', now: t0), s), isTrue);
      expect(identical(s.answer('nope', 'A', now: t0), s), isTrue);
      s = s.clearAnswer('q3', now: t0);
      expect(s.answerOf('q3'), isNull);
      expect(s.answeredCount, 0);
    });

    test('quantitative comparison uses the blueprint fixed options', () {
      final s = start();
      expect(s.partAt(0).id, 'cmp');
      expect(s.partAt(2).id, 'prob');
      final opts = s.optionsFor(0);
      expect(opts.map((o) => o.id).toList(), ['A', 'B', 'C', 'D']);
      expect(opts.first.text, 'А больше');
      expect(s.optionsFor(2), hasLength(5));
      expect(s.answer('q1', 'E', now: t0).answerOf('q1'), isNull,
          reason: 'E is not a comparison option');
      expect(s.answer('q1', 'D', now: t0).answerOf('q1'), 'D');
    });

    test('flags toggle and show in palette cells and counts', () {
      var s = start();
      s = s.toggleFlag('q2', now: t0).answer('q1', 'A', now: t0);
      expect(s.flaggedCount, 1);
      expect(s.unansweredCount, 2);
      expect(s.cell(0), const QuestionCellState(answered: true, flagged: false, current: true));
      expect(s.cell(1), const QuestionCellState(answered: false, flagged: true, current: false));
      s = s.toggleFlag('q2', now: t0);
      expect(s.flaggedCount, 0);
    });
  });

  group('timer', () {
    test('remaining time is corrected for server clock skew', () {
      // Server clock is 90 s ahead of the device; 10 min left on the server.
      final s = start(skewMs: 90000);
      expect(s.clockOffsetMs, 90000);
      expect(s.remaining(t0), const Duration(minutes: 10));
      expect(s.remaining(t0.add(const Duration(minutes: 4))), const Duration(minutes: 6));
      // The deadline in device time is 10 min after t0, not 11.5.
      expect(s.localDeadline(), t0.add(const Duration(minutes: 10)));
    });

    test('negative skew (device ahead of server) is corrected too', () {
      final s = start(skewMs: -120000);
      expect(s.remaining(t0), const Duration(minutes: 10));
      expect(s.localDeadline(), t0.add(const Duration(minutes: 10)));
    });

    test('warnings fire once at 5 and 1 minute', () {
      var s = start();
      expect(s.dueWarning(t0.add(const Duration(minutes: 4))), isNull);
      final at5 = t0.add(const Duration(minutes: 5, seconds: 1));
      expect(s.dueWarning(at5), TimerWarning.fiveMinutes);
      s = s.markWarned(TimerWarning.fiveMinutes);
      expect(s.dueWarning(at5), isNull);
      final at1 = t0.add(const Duration(minutes: 9, seconds: 1));
      expect(s.dueWarning(at1), TimerWarning.oneMinute);
      s = s.markWarned(TimerWarning.oneMinute);
      expect(s.dueWarning(at1), isNull);
    });

    test('resuming with < 1 min left skips the 5-minute warning', () {
      var s = start(timeLeft: const Duration(seconds: 40));
      expect(s.dueWarning(t0), TimerWarning.oneMinute);
      s = s.markWarned(TimerWarning.oneMinute);
      expect(s.dueWarning(t0), isNull);
    });

    test('at the deadline editing stops and auto-submit is due', () {
      var s = start().answer('q1', 'A', now: t0);
      final end = t0.add(const Duration(minutes: 10));
      expect(s.shouldAutoSubmit(end.subtract(const Duration(seconds: 1))), isFalse);
      expect(s.shouldAutoSubmit(end), isTrue);
      expect(s.canEdit(end), isFalse);
      expect(identical(s.answer('q2', 'B', now: end), s), isTrue);
      expect(identical(s.toggleFlag('q2', now: end), s), isTrue);

      s = s.beginSubmit(now: end, automatic: true);
      expect(s.phase, ExamPhase.submitting);
      final sub = s.pendingSubmission!;
      expect(sub.automatic, isTrue);
      expect(sub.sectionId, 'math');
      expect(sub.answers, {'q1': 'A', 'q2': null, 'q3': null});
      expect(sub.clientElapsedSec, 600);
      expect(s.shouldAutoSubmit(end), isFalse, reason: 'already submitting');
    });
  });

  group('section boundaries', () {
    test('submission locks the section; failure keeps it for retry', () {
      var s = start().answer('q1', 'B', now: t0).toggleFlag('q3', now: t0);
      final at = t0.add(const Duration(minutes: 3));
      s = s.beginSubmit(now: at);
      expect(s.pendingSubmission!.flags, ['q3']);
      expect(s.pendingSubmission!.clientElapsedSec, 180);
      expect(identical(s.answer('q2', 'A', now: at), s), isTrue,
          reason: 'no edits after closing the section');
      s = s.submitFailed();
      expect(s.phase, ExamPhase.submitPending);
      // Retry sends exactly the same submission, even later.
      final retry = s.beginSubmit(now: at.add(const Duration(minutes: 5)));
      expect(retry.phase, ExamPhase.submitting);
      expect(retry.pendingSubmission!.clientElapsedSec, 180);
      expect(retry.pendingSubmission!.answers['q1'], 'B');
    });

    test('next section opens in the interstitial and never reopens the previous', () {
      var s = start().answer('q1', 'A', now: t0).toggleFlag('q2', now: t0);
      final at = t0.add(const Duration(minutes: 2));
      s = s.beginSubmit(now: at);
      s = s.acceptNextSection(nextPayload(deviceNow: at, skewMs: 5000), clientNow: at);
      expect(s.phase, ExamPhase.sectionIntro);
      expect(s.section.sectionId, 'verbal');
      expect(s.sectionIndex, 1);
      expect(s.answers, isEmpty);
      expect(s.clockOffsetMs, 5000);
      expect(s.submitted['math']!.answered, 1);
      expect(s.submitted['math']!.flags, ['q2']);
      expect(s.isLastSection, isTrue);
      // Cannot answer before starting the section.
      expect(identical(s.answer('v1', 'A', now: at), s), isTrue);
      s = s.startSection();
      expect(s.phase, ExamPhase.inSection);
      expect(s.passageFor(s.questions.first)!.lines, hasLength(6));

      // A payload for the submitted section (or an earlier index) is refused.
      expect(
        () => s.acceptNextSection(
            ExamSessionPayload.fromJson({
              'attemptId': 'att1',
              'blueprint': twoSectionBlueprint,
              'currentSectionIndex': 0,
              'section': mathSection(deadlineMs: 0),
              'serverNow': 0,
            }),
            clientNow: at),
        throwsStateError,
      );
      final reconciled = s.reconcile(startPayload(), clientNow: at);
      expect(reconciled.section.sectionId, 'verbal',
          reason: 'server state for a submitted section is ignored');
    });

    test('completion stores the result and records the last section', () {
      var s = start().answer('q1', 'A', now: t0);
      s = s.beginSubmit(now: t0);
      final at = t0.add(const Duration(minutes: 1));
      s = s.acceptNextSection(nextPayload(deviceNow: at), clientNow: at).startSection();
      s = s.answer('v1', 'A', now: at).beginSubmit(now: at);
      s = s.complete(ExamResult.fromJson(resultJson()));
      expect(s.phase, ExamPhase.completed);
      expect(s.result!.percent, 60.0);
      expect(s.submitted.keys.toList(), ['math', 'verbal']);
      expect(s.submitted['verbal']!.answered, 1);
      expect(s.pendingSubmission, isNull);
    });
  });

  group('reconcile with server state', () {
    test('same section: local answers kept, deadline and skew from server', () {
      var s = start().answer('q1', 'C', now: t0);
      final later = t0.add(const Duration(minutes: 1));
      // Server extended nothing but its clock now reads 30 s ahead.
      final server = ExamSessionPayload.fromJson({
        'attemptId': 'att1',
        'blueprint': twoSectionBlueprint,
        'currentSectionIndex': 0,
        'section': mathSection(
            deadlineMs: t0.millisecondsSinceEpoch + 10 * 60 * 1000),
        'serverNow': later.millisecondsSinceEpoch + 30000,
      });
      s = s.reconcile(server, clientNow: later);
      expect(s.answerOf('q1'), 'C');
      expect(s.clockOffsetMs, 30000);
      expect(s.remaining(later), const Duration(minutes: 8, seconds: 30));
    });

    test('server moved on: current section closed, next opened', () {
      var s = start().answer('q1', 'C', now: t0).beginSubmit(now: t0).submitFailed();
      final at = t0.add(const Duration(minutes: 2));
      s = s.reconcile(nextPayload(deviceNow: at), clientNow: at);
      expect(s.phase, ExamPhase.sectionIntro);
      expect(s.section.sectionId, 'verbal');
      expect(s.pendingSubmission, isNull);
      expect(s.submitted.containsKey('math'), isTrue);
    });

    test('server says completed', () {
      final s = start().reconcile(
        ExamSessionPayload.fromJson({
          'attemptId': 'att1',
          'blueprint': twoSectionBlueprint,
          'status': 'completed',
          'serverNow': t0.millisecondsSinceEpoch,
          'result': resultJson(),
        }),
        clientNow: t0,
      );
      expect(s.phase, ExamPhase.completed);
      expect(s.result!.correct, 3);
    });
  });

  group('persistence json', () {
    test('state + content round-trip; in-flight submission becomes pending', () {
      var s = start(skewMs: 1234).answer('q3', 'E', now: t0).toggleFlag('q1', now: t0).next();
      s = s.markWarned(TimerWarning.fiveMinutes).beginSubmit(now: t0);
      final restored = ExamSession.fromJson(
        Map<String, dynamic>.from(s.toStateJson()),
        Map<String, dynamic>.from(s.toContentJson()),
      )!;
      expect(restored.attemptId, 'att1');
      expect(restored.uid, 'u1');
      expect(restored.answers, {'q3': 'E'});
      expect(restored.flags, {'q1'});
      expect(restored.currentIndex, 1);
      expect(restored.clockOffsetMs, 1234);
      expect(restored.warned, {TimerWarning.fiveMinutes});
      expect(restored.phase, ExamPhase.submitPending);
      expect(restored.pendingSubmission!.answers['q3'], 'E');
      expect(restored.blueprint.totalQuestions, 5);
      expect(restored.questions.map((q) => q.id).toList(), ['q1', 'q2', 'q3']);
      expect(restored.questions[1].columnA, r'$\sqrt{16}$');
      expect(restored.remaining(t0), s.remaining(t0));
    });

    test('mismatched content is rejected', () {
      final s = start();
      final state = s.toStateJson()..['section_id'] = 'verbal';
      expect(ExamSession.fromJson(state, s.toContentJson()), isNull);
    });
  });
}
