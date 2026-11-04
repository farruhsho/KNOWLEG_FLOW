import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/exam/domain/exam_failure.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_session.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exam_runner_page.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';
import 'package:knowledge_flow/features/exam/presentation/widgets/option_tile.dart';
import 'package:knowledge_flow/features/exam/presentation/widgets/question_palette.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'exam_fakes.dart';
import 'exam_test_fixtures.dart';

Widget _app(Widget child, {List<Override> overrides = const [], Brightness brightness = Brightness.light}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Plain Material theme + tokens: no GoogleFonts / network in tests.
      theme: ThemeData(
        brightness: brightness,
        extensions: [brightness == Brightness.dark ? AppTokens.dark : AppTokens.light],
      ),
      home: child,
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('ExamOptionTile', () {
    testWidgets('tap selects; selected state is exposed', (tester) async {
      _phone(tester);
      var taps = 0;
      await tester.pumpWidget(_app(Scaffold(
        body: Column(children: [
          ExamOptionTile(letter: 'A', text: r'Ответ $x^2$', onTap: () => taps++),
          const ExamOptionTile(letter: 'B', text: 'Второй', mark: OptionMark.selected),
        ]),
      )));
      await tester.tap(find.text('A'));
      expect(taps, 1);
      expect(tester.getSemantics(find.byType(ExamOptionTile).last),
          containsSemantics(isSelected: true));
      expect(tester.takeException(), isNull);
    });

    testWidgets('long option text and broken LaTeX do not overflow on 360dp (dark)',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        Scaffold(
          body: ExamOptionTile(
            letter: 'E',
            text: r'Очень длинный вариант ответа ' * 8 + r'$\frac{1}{$ и $\sqrt{2}$',
            onTap: () {},
          ),
        ),
        brightness: Brightness.dark,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ExamOptionTile), findsOneWidget);
    });
  });

  group('QuestionPalette', () {
    testWidgets('shows states, legend counts and navigates on tap', (tester) async {
      _phone(tester);
      int? selected;
      await tester.pumpWidget(_app(Scaffold(
        body: SingleChildScrollView(
          child: QuestionPalette(
            cells: const [
              QuestionCellState(answered: true, flagged: false, current: false),
              QuestionCellState(answered: false, flagged: true, current: true),
              QuestionCellState(answered: false, flagged: false, current: false),
            ],
            groups: const [
              PaletteGroup(title: 'Часть I', start: 0, count: 2),
              PaletteGroup(title: 'Часть II', start: 2, count: 1),
            ],
            onSelect: (i) => selected = i,
          ),
        ),
      )));
      expect(find.text('Отвечено · 1'), findsOneWidget);
      expect(find.text('Отмечено · 1'), findsOneWidget);
      expect(find.text('Без ответа · 2'), findsOneWidget);
      expect(find.text('Часть II'), findsOneWidget);
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('palette_cell_2')));
      expect(selected, 2);
    });
  });

  group('ExamRunnerPage (no Firebase)', () {
    late FakeExamRemote remote;
    late MemoryExamStore store;

    setUp(() {
      remote = FakeExamRemote(onGetState: () => startPayload());
      store = MemoryExamStore();
    });

    List<Override> overrides() => [
          examRemoteProvider.overrideWithValue(remote),
          examLocalStoreProvider.overrideWithValue(store),
          examDraftSinkProvider.overrideWithValue(RecordingDraftSink()),
          examClockProvider.overrideWithValue(() => t0),
          examUidProvider.overrideWithValue('u1'),
        ];

    testWidgets('answer, flag, palette navigation, finish section, next section',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(
          _app(const ExamRunnerPage(attemptId: 'att1'), overrides: overrides()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Математика'), findsOneWidget);
      expect(find.text('Сравнение'), findsOneWidget, reason: 'part title in the top bar');
      expect(find.text('Вопрос 1 из 3'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      // Quantitative comparison: blueprint fixed options.
      expect(find.text('А больше'), findsOneWidget);
      expect(find.text('Нельзя определить'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('option_q1_B')));
      await tester.pump();
      expect(store.saved!.answerOf('q1'), 'B', reason: 'saved locally at once');
      expect(find.text('Отвечено 1 из 3'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('flag_button')));
      await tester.pump();
      expect(store.saved!.isFlagged('q1'), isTrue);

      await tester.tap(find.byKey(const ValueKey('palette_button')));
      await tester.pumpAndSettle();
      expect(find.byType(QuestionPalette), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('palette_cell_2')));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 3 из 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('option_q3_E')), findsOneWidget,
          reason: 'part II has 5 options');

      remote.onSubmit = (s) => SubmitSectionResponse(
          completed: false, next: nextPayload(deviceNow: t0));
      await tester.tap(find.text('Завершить раздел'));
      await tester.pumpAndSettle();
      expect(find.text('Без ответа: 2'), findsOneWidget);
      expect(find.text('Отмечено для проверки: 1'), findsOneWidget);
      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();

      expect(remote.submissions.single.answers, {'q1': 'B', 'q2': null, 'q3': null});
      expect(find.text('Раздел принят'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start_section_button')));
      await tester.pump();
      expect(find.text('Аналогии'), findsWidgets);
      expect(find.textContaining('Текст: Лес'), findsOneWidget, reason: 'passage panel');
      expect(find.text('5'), findsWidgets, reason: 'line number every 5 lines');
      expect(tester.takeException(), isNull);
      expect(store.saved!.phase, ExamPhase.inSection);
    });

    testWidgets('offline with no local copy shows an error with retry', (tester) async {
      _phone(tester);
      remote.onGetState = null;
      await tester.pumpWidget(
          _app(const ExamRunnerPage(attemptId: 'att1'), overrides: overrides()));
      await tester.pump();
      await tester.pump();
      expect(find.text('Повторить'), findsOneWidget);
      remote.onGetState = () => startPayload();
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Вопрос 1 из 3'), findsOneWidget);
    });

    testWidgets('back press on the load-failure screen just leaves (UX-08)',
        (tester) async {
      _phone(tester);
      remote.onGetState = null; // offline, no local copy: load fails
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/run'),
              child: const Text('HOME'),
            ),
          ),
        ),
        GoRoute(
          path: '/run',
          builder: (_, __) => const ExamRunnerPage(attemptId: 'att1'),
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(extensions: [AppTokens.light]),
        ),
      ));
      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.text('Повторить'), findsOneWidget, reason: 'load failed');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Выйти из теста?'), findsNothing,
          reason: 'no "timer keeps running" dialog for an attempt that never loaded');
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('platform without App Check: clear message, no retry (D7)',
        (tester) async {
      _phone(tester);
      remote.onGetState = () =>
          throw const ExamFailure(ExamFailureKind.platformUnsupported);
      await tester.pumpWidget(
          _app(const ExamRunnerPage(attemptId: 'att1'), overrides: overrides()));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('На этом устройстве пробные экзамены недоступны'),
          findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
    });

    testWidgets('back press asks before leaving', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
          _app(const ExamRunnerPage(attemptId: 'att1'), overrides: overrides()));
      await tester.pump();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Выйти из теста?'), findsOneWidget);
      expect(find.textContaining('таймер раздела продолжает идти'), findsOneWidget);
      await tester.tap(find.text('Остаться'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 1 из 3'), findsOneWidget);
    });
  });
}
