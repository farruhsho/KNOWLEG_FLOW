import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/exam/domain/exam_blueprint.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exam_result_page.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'exam_test_fixtures.dart';

ExamBlueprint _blueprint(String id) {
  final raw = File('assets/data/exam_blueprints.json').readAsStringSync();
  return ExamBlueprint.listFromJson(jsonDecode(raw)).firstWhere((b) => b.id == id);
}

Widget _app(ExamResultData data, {Brightness brightness = Brightness.light}) {
  return ProviderScope(
    overrides: [
      examResultProvider.overrideWith((ref, attemptId) async => data),
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
      theme: ThemeData(
        brightness: brightness,
        extensions: [brightness == Brightness.dark ? AppTokens.dark : AppTokens.light],
      ),
      home: const ExamResultPage(attemptId: 'att1'),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('main test result: percent, counts, disclaimer, no ORT score (dark, 360dp)',
      (tester) async {
    _phone(tester);
    final data = ExamResultData(
      attemptId: 'att1',
      result: ExamResult.fromJson(resultJson()),
      blueprint: _blueprint('ort_main_2026'),
      attempt: null,
      localRecords: const {},
    );
    await tester.pumpWidget(_app(data, brightness: Brightness.dark));
    await tester.pump();
    await tester.pump();

    expect(find.text('60%'), findsOneWidget);
    expect(find.text('3 из 5 верно'), findsOneWidget);
    // The blueprint disclaimer is always visible: practice result, not an
    // official ORT score — and no 0–200 "балл ОРТ" anywhere.
    expect(find.textContaining('Не является официальным баллом ОРТ'), findsOneWidget);
    expect(find.textContaining('из 200'), findsNothing);
    expect(find.text('Начислено XP: 103'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Повторите «'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Повторите «'), findsOneWidget,
        reason: 'plain-language recommendation for the weak topic');
    // State-language level explanation is only for state_language blueprints.
    expect(find.text('Как выдаётся официальный результат'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('state language result explains levels 1–4 without inventing cut-offs',
      (tester) async {
    _phone(tester);
    final data = ExamResultData(
      attemptId: 'att1',
      result: const ExamResult(correct: 31, total: 50, percent: 62),
      blueprint: _blueprint('ort_state_language_2026'),
      attempt: null,
      localRecords: const {},
    );
    await tester.pumpWidget(_app(data));
    await tester.pump();
    await tester.pump();

    expect(find.text('62%'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Как выдаётся официальный результат'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Как выдаётся официальный результат'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
