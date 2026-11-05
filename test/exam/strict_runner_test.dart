import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/exam/data/exam_local_store.dart';
import 'package:knowledge_flow/features/exam/domain/exam_failure.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_session.dart';
import 'package:knowledge_flow/features/exam/presentation/controllers/exam_runner_controller.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exam_runner_page.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';
import 'package:knowledge_flow/features/exam/presentation/widgets/question_palette.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'exam_fakes.dart';
import 'exam_test_fixtures.dart';

/// Strict style («Как на ОРТ», ARCHITECTURE §10.2) in the runner: one
/// correction per answer (kept across restarts), no flags, no "finish
/// section", automatic submission at the deadline, an instruction screen
/// before every section, SECTION_NOT_OVER handled by waiting.
void main() {
  group('controller', () {
    late DateTime now;
    late FakeExamRemote remote;
    late MemoryExamStore store;
    late ExamRunnerController c;

    ExamRunnerController build({ExamLocalStore? local}) => ExamRunnerController(
          attemptId: 'att1',
          remote: remote,
          store: local ?? (store = MemoryExamStore()),
          drafts: RecordingDraftSink(),
          clock: () => now,
          uid: 'u1',
          tickInterval: const Duration(hours: 1),
          draftInterval: const Duration(hours: 1),
          retryInterval: const Duration(seconds: 15),
          autoLoad: false,
        );

    List<ExamRunnerNotice> notices(ExamRunnerController c) {
      final out = <ExamRunnerNotice>[];
      c.addListener((s) {
        if (s.notice != null && s.noticeSeq > out.length) out.add(s.notice!);
      }, fireImmediately: false);
      return out;
    }

    setUp(() {
      now = t0;
      remote = FakeExamRemote(onGetState: () => startPayload(examStyle: 'strict'));
    });

    test('third choice is refused with a notice; the second answer stays', () async {
      c = build();
      addTearDown(c.dispose);
      await c.load();
      expect(c.state.session!.phase, ExamPhase.sectionIntro);
      c.startSection();
      final seen = notices(c);
      c.selectAnswer('q3', 'A');
      c.selectAnswer('q3', 'B');
      c.selectAnswer('q3', 'C');
      await c.pendingWrites;
      expect(c.state.session!.answerOf('q3'), 'B');
      expect(seen, [ExamRunnerNotice.answerLocked]);
      expect(store.saved!.choicesMade('q3'), 2, reason: 'saved locally at once');
      c.toggleFlag('q3');
      expect(c.state.session!.flags, isEmpty);
    });

    test('no early submission; automatic at the deadline', () async {
      c = build();
      addTearDown(c.dispose);
      await c.load();
      c.startSection();
      c.selectAnswer('q1', 'A');
      remote.onSubmit = (s) => SubmitSectionResponse(
          completed: false, next: nextPayload(deviceNow: now, examStyle: 'strict'));
      now = t0.add(const Duration(minutes: 9, seconds: 59));
      await c.submitSection();
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(remote.submissions, isEmpty, reason: 'the section is not over yet');

      now = t0.add(const Duration(minutes: 10));
      c.tick();
      await Future<void>.delayed(Duration.zero);
      await c.pendingWrites;
      expect(remote.submissions.single.automatic, isTrue);
      expect(remote.submissions.single.answers['q1'], 'A');
      expect(remote.submissions.single.flags, isEmpty);
      final s = c.state.session!;
      expect(s.section.sectionId, 'verbal');
      expect(s.phase, ExamPhase.sectionIntro, reason: 'instruction before section 2');
    });

    test('auto-submit also fires while the instruction screen is open', () async {
      c = build();
      addTearDown(c.dispose);
      await c.load();
      remote.onSubmit = (s) => SubmitSectionResponse(
          completed: false, next: nextPayload(deviceNow: now, examStyle: 'strict'));
      now = t0.add(const Duration(minutes: 10, seconds: 1));
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(remote.submissions, hasLength(1));
    });

    test('SECTION_NOT_OVER: wait a few seconds and send the same answers again', () async {
      c = build();
      addTearDown(c.dispose);
      await c.load();
      c.startSection();
      c.selectAnswer('q2', 'D');
      var calls = 0;
      remote.onSubmit = (s) {
        calls++;
        if (calls == 1) throw const ExamFailure(ExamFailureKind.sectionNotOver);
        return SubmitSectionResponse(
            completed: false, next: nextPayload(deviceNow: now, examStyle: 'strict'));
      };
      // The server is 4 s behind the device: its deadline is 4 s away.
      remote.onGetState = () => startPayload(
          examStyle: 'strict', skewMs: 596000, timeLeft: const Duration(seconds: 4));
      now = t0.add(const Duration(minutes: 10));
      c.tick();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.session!.phase, ExamPhase.submitPending,
          reason: 'a few seconds are not worth reopening the section');
      expect(c.state.submitFailure!.kind, ExamFailureKind.sectionNotOver);

      now = now.add(const Duration(seconds: 1));
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(remote.submissions, hasLength(1), reason: 'not before the retry delay');

      now = now.add(const Duration(seconds: 3));
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(remote.submissions, hasLength(2));
      expect(remote.submissions.last.answers['q2'], 'D');
      expect(c.state.session!.section.sectionId, 'verbal');
    });

    test('SECTION_NOT_OVER with the device clock far ahead reopens the section',
        () async {
      c = build();
      addTearDown(c.dispose);
      await c.load();
      c.startSection();
      c.selectAnswer('q1', 'A');
      c.selectAnswer('q1', 'B');
      remote.onSubmit = (s) => throw const ExamFailure(ExamFailureKind.sectionNotOver);
      // The device clock jumped 5 minutes ahead; the server is at minute 5.
      remote.onGetState = () => startPayload(
          examStyle: 'strict', skewMs: 300000, timeLeft: const Duration(minutes: 5));
      now = t0.add(const Duration(minutes: 10));
      c.tick();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final s = c.state.session!;
      expect(s.phase, ExamPhase.inSection);
      expect(s.remaining(now), const Duration(minutes: 5));
      expect(s.answerOf('q1'), 'B');
      expect(s.isAnswerLocked('q1'), isTrue, reason: 'the correction stays used');
      expect(c.state.submitFailure, isNull);
      expect(remote.submissions, hasLength(1));
    });

    group('restart (Hive exam_sessions box)', () {
      late Directory dir;

      setUp(() async {
        dir = await Directory.systemTemp.createTemp('strict_restart');
        Hive.init(dir.path);
      });

      tearDown(() async {
        await Hive.close();
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });

      test('the one correction stays used after the app is killed', () async {
        final first = build(local: ExamLocalStore());
        await first.load();
        first.startSection();
        first.selectAnswer('q3', 'A');
        first.selectAnswer('q3', 'B');
        await first.pendingWrites;
        first.dispose();
        await first.pendingWrites;
        await Hive.close();

        // App restarts offline: only the device copy is available.
        remote.onGetState = null;
        c = build(local: ExamLocalStore());
        addTearDown(c.dispose);
        await c.load();
        final s = c.state.session!;
        expect(s.isStrict, isTrue);
        expect(s.answerOf('q3'), 'B');
        expect(s.isAnswerLocked('q3'), isTrue);
        final seen = notices(c);
        c.selectAnswer('q3', 'E');
        expect(c.state.session!.answerOf('q3'), 'B');
        expect(seen, [ExamRunnerNotice.answerLocked]);
      });
    });
  });

  group('runner page', () {
    late DateTime now;
    late FakeExamRemote remote;
    late MemoryExamStore store;

    Widget app() => ProviderScope(
          overrides: [
            examRemoteProvider.overrideWithValue(remote),
            examLocalStoreProvider.overrideWithValue(store),
            examDraftSinkProvider.overrideWithValue(RecordingDraftSink()),
            examClockProvider.overrideWithValue(() => now),
            examUidProvider.overrideWithValue('u1'),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(extensions: [AppTokens.light]),
            home: const ExamRunnerPage(attemptId: 'att1'),
          ),
        );

    Future<void> pumpRunner(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pump();
    }

    setUp(() {
      now = t0;
      store = MemoryExamStore();
      remote = FakeExamRemote(
        onGetState: () => startPayload(
            examStyle: 'strict', freshness: {'total': 5, 'repeated': 2}),
      );
    });

    testWidgets('instruction screen, then no flags and no "Finish section"',
        (tester) async {
      await pumpRunner(tester);
      // Pre-section instruction (first section too), timer honestly running.
      expect(find.text('ИНСТРУКЦИЯ К РАЗДЕЛУ'), findsOneWidget);
      expect(find.text('Раздел принят'), findsNothing, reason: 'first section');
      expect(find.text('Математика'), findsOneWidget);
      expect(find.textContaining('3 вопроса'), findsOneWidget);
      expect(find.textContaining('Ответ на задание можно исправить только один раз'),
          findsOneWidget);
      expect(find.textContaining('Черновик'), findsOneWidget,
          reason: 'math allows scratch paper');
      expect(find.textContaining('Таймер раздела уже идёт'), findsOneWidget);
      expect(find.textContaining('2 задания вы уже встречали'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('start_section_button')));
      await tester.pump();
      expect(find.text('Вопрос 1 из 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('flag_button')), findsNothing);

      // Last question: a countdown instead of "Finish section".
      await tester.tap(find.byKey(const ValueKey('palette_button')));
      await tester.pumpAndSettle();
      expect(find.byType(QuestionPalette), findsOneWidget);
      expect(find.textContaining('Отмечено'), findsNothing, reason: 'no flag legend');
      expect(find.text('Завершить раздел'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('palette_cell_2')));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 3 из 3'), findsOneWidget);
      expect(find.text('Завершить раздел'), findsNothing);
      expect(find.byKey(const ValueKey('strict_section_countdown')), findsOneWidget);
      expect(find.text('Раздел закончится через 10:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one correction: hint, then a short explanation on the third choice',
        (tester) async {
      await pumpRunner(tester);
      await tester.tap(find.byKey(const ValueKey('start_section_button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('option_q1_A')));
      await tester.pump();
      expect(find.text('Ответ можно исправить ещё один раз.'), findsOneWidget);
      expect(find.text('Сбросить ответ'), findsNothing, reason: 'no erasing');
      await tester.tap(find.byKey(const ValueKey('option_q1_B')));
      await tester.pump();
      expect(find.text('Ответ исправлен — больше изменить нельзя.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('option_q1_C')));
      await tester.pump();
      expect(find.textContaining('исправить его можно только один раз'), findsOneWidget);
      expect(store.saved!.answerOf('q1'), 'B');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the section is sent by itself at the deadline', (tester) async {
      await pumpRunner(tester);
      await tester.tap(find.byKey(const ValueKey('start_section_button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('option_q1_B')));
      await tester.pump();
      remote.onSubmit = (s) => SubmitSectionResponse(
          completed: false, next: nextPayload(deviceNow: now, examStyle: 'strict'));
      now = t0.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      expect(remote.submissions.single.automatic, isTrue);
      expect(remote.submissions.single.answers['q1'], 'B');
      // Section 2 starts with its own instruction; verbal has no scratch paper.
      expect(find.text('Раздел принят'), findsOneWidget);
      expect(find.text('ИНСТРУКЦИЯ К РАЗДЕЛУ'), findsOneWidget);
      expect(find.text('Аналогии'), findsOneWidget);
      expect(find.textContaining('Черновик'), findsNothing);
      expect(find.textContaining('вы уже встречали'), findsNothing,
          reason: 'freshness is shown on the first section only');
      expect(tester.takeException(), isNull);
    });

    testWidgets('SECTION_NOT_OVER shows a calm wait, not an error', (tester) async {
      await pumpRunner(tester);
      await tester.tap(find.byKey(const ValueKey('start_section_button')));
      await tester.pump();
      remote.onSubmit = (s) => throw const ExamFailure(ExamFailureKind.sectionNotOver);
      remote.onGetState = () => startPayload(
          examStyle: 'strict', skewMs: 596000, timeLeft: const Duration(seconds: 4));
      now = t0.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('strict_waiting_deadline')), findsOneWidget);
      expect(find.textContaining('ответы отправятся через несколько секунд'), findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
      remote.onSubmit = (s) => SubmitSectionResponse(
          completed: false, next: nextPayload(deviceNow: now, examStyle: 'strict'));
      now = now.add(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      expect(remote.submissions, hasLength(2));
      expect(find.text('Аналогии'), findsOneWidget);
    });

    testWidgets('standard style: flag button and "Finish section" as before',
        (tester) async {
      remote.onGetState = () => startPayload(freshness: {'total': 5, 'repeated': 1});
      await pumpRunner(tester);
      expect(find.text('Вопрос 1 из 3'), findsOneWidget, reason: 'no instruction screen');
      expect(find.byKey(const ValueKey('flag_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('exam_freshness_notice')), findsOneWidget);
      expect(find.textContaining('1 задание вы уже встречали'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('palette_button')));
      await tester.pumpAndSettle();
      expect(find.text('Завершить раздел'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
