import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/content/topic_names.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/exam/domain/exam_blueprint.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exam_review_page.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';
import 'package:knowledge_flow/features/exam/presentation/widgets/exam_image_resolver.dart';
import 'package:knowledge_flow/features/exam/presentation/widgets/question_view.dart';
import 'package:knowledge_flow/features/exam/presentation/widgets/rich_stem.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'exam_fakes.dart';

void main() {
  testWidgets(
      'review shows the Storage image (CP-02), QC columns (CP-08) and topic names (UX-02)',
      (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final names = TopicNames.fromJson(
        jsonDecode(File('assets/data/topic_names.json').readAsStringSync())
            as Map<String, dynamic>);
    final main = ExamBlueprint.listFromJson(
            jsonDecode(File('assets/data/exam_blueprints.json').readAsStringSync()))
        .firstWhere((b) => b.id == 'ort_main_2026');
    final resolved = <String>[];
    // Never completes: the image stays in its loading state (no network in
    // tests), but the resolver must have been asked for the Storage path.
    final pending = Completer<String?>();

    // Exactly what examGetReview returns for a stored comparison item.
    final item = ReviewItem.fromJson({
      'questionId': 'q_qc1',
      'sectionId': 'math',
      'partId': 'math_comparison',
      'stem': 'x > 0',
      'options': [
        {'id': 'A', 'text': 'А больше'},
        {'id': 'B', 'text': 'Б больше'},
      ],
      'columnA': 'COL_A_VALUE',
      'columnB': 'COL_B_VALUE',
      'imagePath': 'exam_media/q_qc1/graph.png',
      'table': null,
      'passage': null,
      'userAnswer': 'A',
      'correct': 'B',
      'explanation': '',
      'topicId': 'math.arithmetic',
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        examReviewProvider.overrideWith((ref, id) async => [item]),
        examResultProvider.overrideWith((ref, id) async => ExamResultData(
              attemptId: id,
              result: const ExamResult(correct: 0, total: 1, percent: 0),
              blueprint: main,
              attempt: null,
              localRecords: const {},
            )),
        examLocalStoreProvider.overrideWithValue(MemoryExamStore()),
        topicNamesProvider.overrideWith((ref) async => names),
        examImageUrlResolverProvider.overrideWithValue((ref) {
          resolved.add(ref);
          return pending.future;
        }),
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
        home: const ExamReviewPage(attemptId: 'att1'),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byWidgetPredicate((w) => w is ExamImage && w.url == 'exam_media/q_qc1/graph.png'),
        findsOneWidget);
    expect(resolved, ['exam_media/q_qc1/graph.png']);

    expect(find.byType(ComparisonColumns), findsOneWidget);
    expect(find.text('Колонка А'), findsOneWidget);
    expect(find.text('Колонка Б'), findsOneWidget);
    expect(find.textContaining('COL_A_VALUE', findRichText: true), findsOneWidget);
    expect(find.textContaining('COL_B_VALUE', findRichText: true), findsOneWidget);

    expect(find.text('Математика · Арифметика'), findsOneWidget);
    expect(find.textContaining('math.arithmetic'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
