import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/quiz/presentation/pages/quiz_results_page.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

/// Pumps the results page the way the router builds it, on a 360x640 phone.
/// The real app theme uses Google Fonts (network), so the test theme carries
/// the same design tokens on a plain Material 3 theme.
Future<void> _pump(
  WidgetTester tester, {
  required int total,
  required int correct,
  Locale locale = const Locale('ru'),
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tokens = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(brightness: brightness, useMaterial3: true, extensions: [tokens]),
    home: QuizResultsPage(totalQuestions: total, correctAnswers: correct, totalTimeSeconds: 125),
  ));
  await tester.pump();
}

void main() {
  testWidgets('opened without route extra shows an empty state, not a crash (EXAM-15)', (tester) async {
    await _pump(tester, total: 0, correct: 0);
    expect(tester.takeException(), isNull);
    expect(find.text('Результатов пока нет'), findsOneWidget);
  });

  testWidgets('7 of 10 is shown as a 70% practice result, never as an ORT score (EXAM-03)', (tester) async {
    await _pump(tester, total: 10, correct: 7);
    expect(tester.takeException(), isNull, reason: 'no overflow on a 360x640 phone in dark mode');
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('Практика: 70%'), findsOneWidget);
    expect(find.text('7 из 10 верно'), findsOneWidget);
    expect(find.textContaining('Прогнозируемый'), findsNothing);
    expect(find.textContaining('140'), findsNothing);
    expect(find.textContaining('/200'), findsNothing);
  });

  testWidgets('Kyrgyz UI in light mode renders Kyrgyz labels', (tester) async {
    await _pump(tester, total: 10, correct: 7, locale: const Locale('ky'), brightness: Brightness.light);
    expect(tester.takeException(), isNull);
    expect(find.text('Машыгуу: 70%'), findsOneWidget);
    expect(find.text('10 суроодон 7 туура'), findsOneWidget);
  });
}
