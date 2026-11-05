import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/domain/exam_failure.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_session.dart';
import 'package:knowledge_flow/features/exam/presentation/controllers/exam_runner_controller.dart';

import 'exam_fakes.dart';
import 'exam_test_fixtures.dart';

void main() {
  late DateTime now;
  late FakeExamRemote remote;
  late MemoryExamStore store;
  late RecordingDraftSink drafts;
  late ExamRunnerController c;

  ExamRunnerController build({ExamSession? local}) {
    store = MemoryExamStore(initial: local);
    return ExamRunnerController(
      attemptId: 'att1',
      remote: remote,
      store: store,
      drafts: drafts,
      clock: () => now,
      uid: 'u1',
      // Real timers must not fire during the test; ticks are driven by hand.
      tickInterval: const Duration(hours: 1),
      draftInterval: const Duration(hours: 1),
      retryInterval: Duration.zero,
      autoLoad: false,
    );
  }

  setUp(() {
    now = t0;
    remote = FakeExamRemote(onGetState: () => startPayload(skewMs: 2000));
    drafts = RecordingDraftSink();
  });

  tearDown(() => c.dispose());

  test('loads from the server and saves every answer immediately', () async {
    c = build();
    await c.load();
    expect(c.state.session!.clockOffsetMs, 2000);
    c.selectAnswer('q3', 'B');
    await c.pendingWrites;
    expect(store.saved!.answerOf('q3'), 'B');
    final before = store.saves;
    c.toggleFlag('q1');
    await c.pendingWrites;
    expect(store.saves, before + 1);
    // Drafts are flushed on demand (AppLifecycleState.paused).
    c.flushDraft();
    await Future<void>.delayed(Duration.zero);
    expect(drafts.drafts.single.answers, {'q3': 'B'});
    expect(drafts.drafts.single.flags, ['q1']);
  });

  test('offline start: continues from the local copy', () async {
    final local = ExamSession.fromPayload(startPayload(), clientNow: t0, uid: 'u1')
        .answer('q1', 'A', now: t0);
    remote.onGetState = null; // network error
    c = build(local: local);
    await c.load();
    expect(c.state.loadFailure, isNull);
    expect(c.state.offline, isTrue);
    expect(c.state.session!.answerOf('q1'), 'A');
  });

  test('no local copy and no network: error state with retry', () async {
    remote.onGetState = null;
    c = build();
    await c.load();
    expect(c.state.session, isNull);
    expect(c.state.loadFailure!.kind, ExamFailureKind.network);
    remote.onGetState = () => startPayload();
    await c.retryLoad();
    expect(c.state.session, isNotNull);
  });

  test('warnings and auto-submit at the deadline (fake clock)', () async {
    c = build();
    remote.onGetState = () => startPayload();
    await c.load();
    final notices = <ExamRunnerNotice>[];
    c.addListener((s) {
      if (s.notice != null && (notices.isEmpty || s.noticeSeq > notices.length)) {
        notices.add(s.notice!);
      }
    }, fireImmediately: false);
    now = t0.add(const Duration(minutes: 5, seconds: 30));
    c.tick();
    expect(notices, [ExamRunnerNotice.fiveMinutesLeft]);
    now = t0.add(const Duration(minutes: 9, seconds: 30));
    c.tick();
    expect(notices.last, ExamRunnerNotice.oneMinuteLeft);

    c.selectAnswer('q1', 'C');
    remote.onSubmit = (s) => SubmitSectionResponse(
        completed: false, next: nextPayload(deviceNow: now));
    now = t0.add(const Duration(minutes: 10));
    c.tick();
    await Future<void>.delayed(Duration.zero);
    await c.pendingWrites;
    expect(remote.submissions.single.automatic, isTrue);
    expect(remote.submissions.single.answers['q1'], 'C');
    expect(c.state.session!.phase, ExamPhase.sectionIntro);
    expect(notices.last, ExamRunnerNotice.autoSubmitted);
  });

  test('offline at the boundary: locked, retried, next section only after acceptance', () async {
    c = build();
    remote.onGetState = () => startPayload();
    await c.load();
    c.selectAnswer('q2', 'D');
    remote.onSubmit = null; // network down
    await c.submitSection();
    expect(c.state.session!.phase, ExamPhase.submitPending);
    expect(c.state.submitFailure!.kind, ExamFailureKind.network);
    // Edits are refused while waiting.
    c.selectAnswer('q2', 'A');
    expect(c.state.session!.answerOf('q2'), 'D');

    remote.onSubmit = (s) => SubmitSectionResponse(
        completed: false, next: nextPayload(deviceNow: now));
    c.tick(); // periodic auto-retry
    await Future<void>.delayed(Duration.zero);
    await c.pendingWrites;
    expect(remote.submissions, hasLength(2));
    expect(remote.submissions.last.answers['q2'], 'D');
    expect(c.state.session!.section.sectionId, 'verbal');
    c.startSection();
    expect(c.state.session!.phase, ExamPhase.inSection);
  });

  test('WRONG_SECTION on submit resyncs with the server', () async {
    c = build();
    remote.onGetState = () => startPayload();
    await c.load();
    remote.onSubmit = (_) => throw const ExamFailure(ExamFailureKind.wrongSection);
    remote.onGetState = () => nextPayload(deviceNow: now);
    await c.submitSection();
    expect(c.state.session!.section.sectionId, 'verbal');
    expect(c.state.session!.phase, ExamPhase.sectionIntro);
  });

  test('draft write failure (EXAM-01): reported once, retried, Hive copy untouched',
      () async {
    final flaky = FlakyDraftSink(failTimes: 2);
    final reports = <String>[];
    store = MemoryExamStore();
    c = ExamRunnerController(
      attemptId: 'att1',
      remote: remote,
      store: store,
      drafts: flaky,
      clock: () => now,
      uid: 'u1',
      reportError: (e, s, reason) => reports.add(reason),
      tickInterval: const Duration(hours: 1),
      draftInterval: const Duration(hours: 1),
      retryInterval: Duration.zero,
      autoLoad: false,
    );
    await c.load();
    c.selectAnswer('q1', 'A');
    await c.pendingWrites;

    c.flushDraft();
    await Future<void>.delayed(Duration.zero);
    expect(flaky.calls, 1);
    expect(reports, ['exam_draft_write'], reason: 'not swallowed silently');
    expect(c.draftFailures, 1);
    expect(store.saved!.answerOf('q1'), 'A', reason: 'local copy is authoritative');
    expect(c.state.session!.answerOf('q1'), 'A');

    // Still dirty after the failure: the next interval retries without a
    // new edit, and a repeated failure of the same section is not
    // re-reported.
    c.flushDraft();
    await Future<void>.delayed(Duration.zero);
    expect(flaky.calls, 2);
    expect(reports, hasLength(1));

    c.flushDraft();
    await Future<void>.delayed(Duration.zero);
    expect(flaky.calls, 3);
    expect(flaky.written.single, {'q1': 'A'});

    // Saved: nothing new to send.
    c.flushDraft();
    await Future<void>.delayed(Duration.zero);
    expect(flaky.calls, 3);
  });

  test('last section completes the attempt with the server result', () async {
    c = build();
    remote.onGetState = () => nextPayload(deviceNow: now);
    await c.load();
    c.startSection();
    remote.onSubmit = (_) => SubmitSectionResponse(
        completed: true, result: ExamResult.fromJson(resultJson()));
    await c.submitSection();
    await c.pendingWrites;
    expect(c.state.session!.phase, ExamPhase.completed);
    expect(store.saved!.result!.percent, 60.0);
    expect(store.prunes, 1, reason: 'question content dropped after completion');
  });
}
