import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/tutor/application/tutor_controller.dart';
import 'package:knowledge_flow/features/tutor/data/tutor_api.dart';
import 'package:knowledge_flow/features/tutor/domain/tutor_models.dart';
import 'package:knowledge_flow/features/tutor/presentation/pages/tutor_page.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/shared/models/question_model.dart';
import 'package:knowledge_flow/shared/widgets/ai_explainer_modal.dart';

class _FakeTutorApi implements TutorApi {
  _FakeTutorApi(this.script);

  final List<Object> script;
  final List<TutorRequest> requests = [];

  @override
  Future<TutorReply> ask(TutorRequest request) async {
    requests.add(request);
    final next = script.length > 1 ? script.removeAt(0) : script.first;
    if (next is TutorReply) return next;
    throw next;
  }
}

FirebaseFunctionsException _reason(String reason) => FirebaseFunctionsException(
      code: 'failed-precondition',
      message: reason,
      details: {'reason': reason},
    );

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required _FakeTutorApi api,
    required Widget home,
    Brightness brightness = Brightness.light,
    String locale = 'ru',
    bool available = true,
  }) async {
    // Small phone: 360 x 640 dp.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        tutorApiProvider.overrideWithValue(api),
        tutorUidProvider.overrideWith((ref) => Stream<String?>.value('user-1')),
        tutorAvailableProvider.overrideWithValue(available),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: brightness,
          extensions: [brightness == Brightness.dark ? AppTokens.dark : AppTokens.light],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(locale),
        home: home,
      ),
    ));
    await tester.pump();
  }

  group('TutorPage', () {
    testWidgets('sends the message with mode + language and renders the reply', (tester) async {
      final api = _FakeTutorApi([const TutorReply(r'Корни: $x=2$ и **3**.', remainingToday: 7)]);
      await pumpApp(tester, api: api, home: const TutorPage(), locale: 'ky');

      expect(find.text('Кантип жардам берейин?'), findsOneWidget);
      await tester.tap(find.text('Кадам-кадам'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2-5x+6=0');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      expect(api.requests, hasLength(1));
      final req = api.requests.single;
      expect(req.mode, TutorMode.stepByStep);
      expect(req.language, 'ky');
      expect(req.toPayload()['message'], 'x^2-5x+6=0');
      expect(find.text('x^2-5x+6=0'), findsOneWidget);
      expect(find.textContaining('Корни'), findsOneWidget);
      expect(find.text('Бүгүн калган суроолор: 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('route args set context, mode and prefill', (tester) async {
      final api = _FakeTutorApi([const TutorReply('ok')]);
      await pumpApp(
        tester,
        api: api,
        home: TutorPage(
          args: TutorArgs.fromExtra(const {
            'questionId': 'q1',
            'attemptId': 'a1',
            'prefill': 'Почему не B?',
          }),
        ),
      );
      await tester.pump();

      expect(find.text('Почему не B?'), findsOneWidget);
      expect(find.text('Вопрос прикреплён'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      final req = api.requests.single;
      expect(req.mode, TutorMode.explainMistake);
      expect(req.questionId, 'q1');
      expect(req.attemptId, 'a1');
      expect(req.language, 'ru');
    });

    testWidgets('quota exceeded disables input with a clear message', (tester) async {
      final api = _FakeTutorApi([_reason('AI_QUOTA_EXCEEDED')]);
      await pumpApp(tester, api: api, home: const TutorPage());

      await tester.enterText(find.byType(TextField), 'Вопрос');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.text('Лимит запросов к ИИ на сегодня исчерпан. Возвращайтесь завтра.'),
          findsWidgets);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('exam in progress is explained and the message can be retried', (tester) async {
      final api = _FakeTutorApi([_reason('AI_EXAM_IN_PROGRESS'), const TutorReply('ok')]);
      await pumpApp(tester, api: api, home: const TutorPage());

      await tester.enterText(find.byType(TextField), 'Вопрос');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Во время экзамена'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });

    testWidgets('composer: counter near the limit, error and no send above it (D13)', (tester) async {
      final api = _FakeTutorApi([const TutorReply('ok')]);
      await pumpApp(tester, api: api, home: const TutorPage());

      await tester.enterText(find.byType(TextField), 'a' * 1900);
      await tester.pump();
      expect(find.text('1900/2000'), findsOneWidget);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send_rounded)).onPressed,
          isNotNull);

      // Typing is not cut off at the limit, but sending is blocked.
      await tester.enterText(find.byType(TextField), 'a' * 2001);
      await tester.pump();
      expect(find.textContaining('2001/2000'), findsOneWidget);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send_rounded)).onPressed,
          isNull);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(api.requests, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('banned account: clear message and input disabled', (tester) async {
      final api = _FakeTutorApi([
        FirebaseFunctionsException(
            code: 'permission-denied', message: 'banned', details: {'reason': 'USER_BANNED'}),
      ]);
      await pumpApp(tester, api: api, home: const TutorPage());
      await tester.enterText(find.byType(TextField), 'Вопрос');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Ваш аккаунт ограничен'), findsWidgets);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('platform without App Check: "not available" state, nothing is sent (D7)',
        (tester) async {
      final api = _FakeTutorApi([const TutorReply('ok')]);
      await pumpApp(tester, api: api, home: const TutorPage(), available: false);

      expect(find.text('ИИ-репетитор недоступен на этой платформе. Воспользуйтесь Android-приложением.'),
          findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(api.requests, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode on a small phone renders without overflow', (tester) async {
      final api = _FakeTutorApi([
        const TutorReply('# План\n1. **Алгебра** — '
            r'$\frac{a}{b}$'
            '\n2. Геометрия\n\n'
            r'$$\int_0^1 x\,dx$$'),
      ]);
      await pumpApp(tester, api: api, home: const TutorPage(), brightness: Brightness.dark);
      await tester.enterText(find.byType(TextField), 'План');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Алгебра'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AIExplainerModal', () {
    final question = QuestionModel(
      id: 'q42',
      subjectId: 'math',
      sectionId: 'math',
      stem: const {'ru': r'Сколько будет $2+2$?'},
      options: const [
        OptionModel(id: 'A', text: {'ru': '3'}),
        OptionModel(id: 'B', text: {'ru': '4'}),
      ],
      correctAnswer: 'B',
      type: QuestionType.singleChoice,
      difficulty: 1,
      explanation: const {'ru': 'Два плюс два — четыре.'},
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      createdBy: 'test',
    );

    testWidgets('asks the aiTutor backend (explain_mistake), never an LLM directly', (tester) async {
      final api = _FakeTutorApi([const TutorReply('Вы прибавили неверно.', remainingToday: 3)]);
      await pumpApp(
        tester,
        api: api,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => AIExplainerModal.show(context, question: question, userAnswer: 'A'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Неправильно'), findsOneWidget);
      expect(find.text('Два плюс два — четыре.'), findsOneWidget);
      await tester.tap(find.text('Объяснить мою ошибку'));
      await tester.pump();
      await tester.pump();

      final req = api.requests.single;
      expect(req.mode, TutorMode.explainMistake);
      expect(req.questionId, 'q42');
      expect(req.language, 'ru');
      expect(req.message, contains('A) 3'));
      expect(find.text('Вы прибавили неверно.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    QuestionModel longQuestion({int stemRepeat = 90, int optionRepeat = 25, int optionCount = 5}) =>
        QuestionModel(
          id: 'q_long',
          subjectId: 'reading',
          sectionId: 'reading',
          stem: {'ru': 'Прочитайте текст. ' * stemRepeat},
          options: [
            for (var i = 0; i < optionCount; i++)
              OptionModel(
                id: String.fromCharCode(65 + i),
                text: {'ru': 'Вариант ${String.fromCharCode(65 + i)}: ${'длинный ответ ' * optionRepeat}'},
              ),
          ],
          correctAnswer: 'C',
          type: QuestionType.singleChoice,
          difficulty: 2,
          explanation: const {},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          createdBy: 'test',
        );

    Future<void> openExplainer(WidgetTester tester, _FakeTutorApi api, QuestionModel q,
        {bool available = true}) async {
      await pumpApp(
        tester,
        api: api,
        available: available,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => AIExplainerModal.show(context, question: q, userAnswer: 'A'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('long reading question: the explain request fits the 2000-char limit (D13)',
        (tester) async {
      // Stem ~1600 + 5 options of ~360 chars: the untrimmed prompt is ~3.6k.
      final api = _FakeTutorApi([const TutorReply('Разбор.')]);
      await openExplainer(tester, api, longQuestion());
      await tester.ensureVisible(find.text('Объяснить мою ошибку'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Объяснить мою ошибку'));
      await tester.pump();
      await tester.pump();

      final req = api.requests.single;
      expect(req.message.length, lessThanOrEqualTo(TutorRequest.maxMessageChars));
      expect(req.toPayload()['message'], req.message.trim());
      for (final id in ['A', 'B', 'C', 'D', 'E']) {
        expect(req.message, contains('$id) Вариант $id'));
      }
      expect(req.message, contains('Мой ответ: A'));
      expect(req.message, contains('Правильный ответ: C'));
      expect(req.questionId, 'q_long');
      expect(tester.takeException(), isNull);
    });

    testWidgets('buildExplainPrompt stays within the limit for huge questions', (tester) async {
      await pumpApp(tester, api: _FakeTutorApi([const TutorReply('x')]), home: const SizedBox());
      for (final code in ['ru', 'ky', 'en']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        final prompt = buildExplainPrompt(
          l10n,
          question: longQuestion(stemRepeat: 2000, optionRepeat: 200, optionCount: 12),
          languageCode: code,
          userAnswer: 'Z' * 5000,
        );
        expect(prompt.length, lessThanOrEqualTo(TutorRequest.maxMessageChars), reason: code);
        expect(prompt, contains('L) Вариант L'), reason: code);
      }
    });

    testWidgets('platform without App Check: no AI buttons, a clear note instead (D7)',
        (tester) async {
      final api = _FakeTutorApi([const TutorReply('x')]);
      await openExplainer(tester, api, question, available: false);
      expect(find.text('Объяснить мою ошибку'), findsNothing);
      expect(find.textContaining('недоступен на этой платформе'), findsOneWidget);
      expect(api.requests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
