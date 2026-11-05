import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/content/topic_names.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exam_result_page.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import '../exam/exam_test_fixtures.dart';

/// "Медленные темы" on the result page (ARCHITECTURE §9.5): the server's
/// `slow_topics` with curriculum names and the average time per question.
void main() {
  final names = TopicNames.fromJson(
      jsonDecode(File('assets/data/topic_names.json').readAsStringSync()) as Map<String, dynamic>);

  Future<void> pump(WidgetTester tester, ExamResult result, {String locale = 'ru', Brightness? dark}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final brightness = dark ?? Brightness.light;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        examResultProvider.overrideWith((ref, attemptId) async => ExamResultData(
              attemptId: 'att1',
              result: result,
              blueprint: null,
              attempt: null,
              localRecords: const {},
            )),
        topicNamesProvider.overrideWith((ref) async => names),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          brightness: brightness,
          extensions: [brightness == Brightness.dark ? AppTokens.dark : AppTokens.light],
        ),
        home: const ExamResultPage(attemptId: 'att1'),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  ExamResult withTimings() => ExamResult.fromJson({
        ...resultJson(),
        'topic_time_avg': {'math.arithmetic': 95.4, 'math.linear': 41},
        'slow_topics': ['math.arithmetic'],
      });

  testWidgets('shows slow topics by name with the time per question', (tester) async {
    await pump(tester, withTimings());
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Медленные темы'), 200, scrollable: scrollable);
    await tester.scrollUntilVisible(find.text('1 мин 35 с на вопрос'), 100, scrollable: scrollable);
    expect(find.text('Арифметика'), findsOneWidget);
    expect(find.text('1 мин 35 с на вопрос'), findsOneWidget);
    expect(find.textContaining('arithmetic'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no slow topics (older attempts) → no section', (tester) async {
    await pump(tester, ExamResult.fromJson(resultJson()));
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byType(OutlinedButton), 200, scrollable: scrollable);
    expect(find.text('Медленные темы'), findsNothing);
  });

  testWidgets('[ky] dark 360dp without overflow', (tester) async {
    await pump(tester, withTimings(), locale: 'ky', dark: Brightness.dark);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Жай иштелген темалар'), 200, scrollable: scrollable);
    expect(find.text('бир суроого 1 мүн 35 сек'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
