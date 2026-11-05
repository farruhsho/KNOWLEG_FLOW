import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/billing/application/billing_providers.dart';
import 'package:knowledge_flow/features/billing/domain/billing_mode.dart';
import 'package:knowledge_flow/features/billing/domain/entitlements.dart';
import 'package:knowledge_flow/features/exam/data/exam_catalog_repository.dart';
import 'package:knowledge_flow/features/exam/domain/exam_attempt.dart';
import 'package:knowledge_flow/features/exam/domain/exam_blueprint.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_variant.dart';
import 'package:knowledge_flow/features/exam/domain/localized_text.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exams_tab_page.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'exam_fakes.dart';

List<ExamBlueprint> _assetBlueprints() => ExamBlueprint.listFromJson(
    jsonDecode(File('assets/data/exam_blueprints.json').readAsStringSync()));

/// Catalog backed by the real blueprint asset and two published variants of
/// the main test (no Firebase).
class _FakeCatalog implements ExamCatalogRepository {
  final blueprints = _assetBlueprints();
  final variantQueries = <String>[];

  @override
  Future<List<ExamBlueprint>> loadBlueprints() async => blueprints;

  @override
  Future<ExamBlueprint?> loadBlueprint(String id) async =>
      blueprints.where((b) => b.id == id).firstOrNull;

  @override
  Future<VariantPage> loadVariants({
    required String blueprintId,
    required String language,
    int? afterNumber,
    int limit = 20,
  }) async {
    variantQueries.add('$blueprintId/$language');
    if (blueprintId != 'ort_main_2026') {
      return const VariantPage(items: [], hasMore: false);
    }
    return VariantPage(items: [
      for (final n in [1, 2])
        ExamVariant(
          id: 'v$n',
          blueprintId: blueprintId,
          blueprintVersion: 1,
          number: n,
          title: LocalizedText.empty,
          language: language,
          status: 'published',
        ),
    ], hasMore: false);
  }

  @override
  Future<ExamVariant?> loadVariant(String variantId) async => null;

  @override
  Stream<List<AttemptSummary>> watchMyAttempts(String uid) => Stream.value([
        const AttemptSummary(
          id: 'a1',
          variantId: 'v1',
          blueprintId: 'ort_main_2026',
          language: 'ru',
          status: 'completed',
          completedAtMs: 1,
          result: ExamResult(correct: 87, total: 150, percent: 58),
        ),
        AttemptSummary(
          id: 'a2',
          variantId: 'v2',
          blueprintId: 'ort_main_2026',
          language: 'ru',
          status: 'in_progress',
          sectionCount: 4,
          currentSectionIndex: 1,
          currentDeadlineAtMs:
              DateTime.now().add(const Duration(minutes: 20)).millisecondsSinceEpoch,
        ),
      ]);

  @override
  Future<AttemptPage> loadHistory(String uid, {Object? cursor, int limit = 20}) async =>
      const AttemptPage(items: [], hasMore: false);

  @override
  Future<AttemptSummary?> loadAttempt(String attemptId) async => null;
}

Widget _app(List<Override> overrides, {Brightness brightness = Brightness.light}) {
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
      theme: ThemeData(
        brightness: brightness,
        extensions: [brightness == Brightness.dark ? AppTokens.dark : AppTokens.light],
      ),
      home: const ExamsTabPage(),
    ),
  );
}

void main() {
  late _FakeCatalog catalog;

  setUp(() => catalog = _FakeCatalog());

  List<Override> overrides(Entitlements ent) => [
        examCatalogRepositoryProvider.overrideWithValue(catalog),
        examLocalStoreProvider.overrideWithValue(MemoryExamStore()),
        examUidProvider.overrideWithValue('u1'),
        examLanguageProvider.overrideWith((ref) => 'ru'),
        entitlementsProvider.overrideWith((ref) => Stream.value(ent)),
      ];

  testWidgets('directions from blueprints, entitlement, variant statuses, resume (dark, 360dp)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
      overrides(const Entitlements(
          freeExamUsed: true, credits: 0, lifetimeCreditsPurchased: 1)),
      brightness: Brightness.dark,
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Resume banner for the in-progress attempt, at the top.
    expect(find.text('Незавершённый тест'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    // Out of credits: the purchase CTA is offered.
    expect(find.text('Кредитов нет'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Купить'), findsOneWidget);

    // Structure summary comes from the blueprint (150 q / 215 min).
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.textContaining('150 вопросов'), 200,
        scrollable: scrollable);
    expect(find.textContaining('150 вопросов · 215 мин'), findsOneWidget);
    // Variants of the main direction (expanded by default) with status.
    expect(catalog.variantQueries, contains('ort_main_2026/ru'));
    await tester.scrollUntilVisible(find.text('В процессе'), 200,
        scrollable: scrollable);
    expect(find.text('Вариант 1'), findsOneWidget);
    expect(find.text('Лучший: 58%'), findsOneWidget);
    expect(find.text('В процессе'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Государственный язык'), 300,
        scrollable: scrollable);
    expect(find.text('Государственный язык'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BILLING_MODE=external: balance only, no Buy button (BILL-EXT-01)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app([
      ...overrides(const Entitlements(
          freeExamUsed: true, credits: 0, lifetimeCreditsPurchased: 1)),
      billingModeProvider.overrideWithValue(BillingMode.external),
    ]));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Кредитов нет'), findsOneWidget, reason: 'balance is still shown');
    expect(find.textContaining('Купить'), findsNothing);
    expect(find.text('Buy'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows / Linux build: platform notice above the catalog (D7)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app([
      ...overrides(Entitlements.initial),
      examCallablesSupportedProvider.overrideWithValue(false),
    ]));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('exam_platform_notice')), findsOneWidget);
    expect(find.textContaining('На этом устройстве пробные экзамены недоступны'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first free test is announced', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(overrides(Entitlements.initial)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Первый тест бесплатно'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Купить'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('several free exams: the remaining count, not "first test" (ENT-FREE-01)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (used, allowed, text) in [
      (0, 5, 'Осталось 5 бесплатных тестов'),
      (1, 3, 'Осталось 2 бесплатных теста'),
      (2, 3, 'Остался 1 бесплатный тест'),
    ]) {
      await tester.pumpWidget(_app(overrides(Entitlements(
        freeExamUsed: used > 0,
        credits: 0,
        lifetimeCreditsPurchased: 0,
        freeExamsUsedCount: used,
        freeExamsAllowed: allowed,
      ))));
      await tester.pump();
      await tester.pump();
      expect(find.text(text), findsOneWidget, reason: '$used/$allowed');
      expect(find.text('Первый тест бесплатно'), findsNothing, reason: '$used/$allowed');
      await tester.pumpWidget(const SizedBox());
    }
    expect(tester.takeException(), isNull);
  });
}
