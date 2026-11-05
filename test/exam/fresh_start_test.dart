import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';
import 'package:knowledge_flow/features/billing/application/billing_providers.dart';
import 'package:knowledge_flow/features/billing/domain/billing_mode.dart';
import 'package:knowledge_flow/features/billing/domain/entitlements.dart';
import 'package:knowledge_flow/features/exam/data/exam_catalog_repository.dart';
import 'package:knowledge_flow/features/exam/domain/exam_attempt.dart';
import 'package:knowledge_flow/features/exam/domain/exam_blueprint.dart';
import 'package:knowledge_flow/features/exam/domain/exam_failure.dart';
import 'package:knowledge_flow/features/exam/domain/exam_start.dart';
import 'package:knowledge_flow/features/exam/domain/exam_variant.dart';
import 'package:knowledge_flow/features/exam/domain/localized_text.dart';
import 'package:knowledge_flow/features/exam/exam_routes.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'exam_fakes.dart';
import 'exam_test_fixtures.dart';

/// «Новый пробный» (mode `fresh`, ARCHITECTURE §10.1) and the style choice
/// on the rules screen (§10.2), with the real exam routes.
class _Catalog implements ExamCatalogRepository {
  final blueprints = ExamBlueprint.listFromJson(
      jsonDecode(File('assets/data/exam_blueprints.json').readAsStringSync()));

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
    if (blueprintId != 'ort_main_2026') {
      return const VariantPage(items: [], hasMore: false);
    }
    return VariantPage(items: [
      ExamVariant(
        id: 'v1',
        blueprintId: blueprintId,
        blueprintVersion: 1,
        number: 1,
        title: LocalizedText.empty,
        language: language,
        status: 'published',
      ),
    ], hasMore: false);
  }

  @override
  Future<ExamVariant?> loadVariant(String variantId) async => const ExamVariant(
        id: 'v1',
        blueprintId: 'ort_main_2026',
        blueprintVersion: 1,
        number: 1,
        title: LocalizedText.empty,
        language: 'ru',
        status: 'published',
      );

  @override
  Stream<List<AttemptSummary>> watchMyAttempts(String uid) => Stream.value(const []);

  @override
  Future<AttemptPage> loadHistory(String uid, {Object? cursor, int limit = 20}) async =>
      const AttemptPage(items: [], hasMore: false);

  @override
  Future<AttemptSummary?> loadAttempt(String attemptId) async => null;
}

void main() {
  late FakeExamRemote remote;
  late MemoryExamStore store;

  setUp(() {
    store = MemoryExamStore();
    remote = FakeExamRemote()
      ..onStart = () => startPayload(
            examStyle: 'strict',
            variantId: 'fresh_att1',
            freshness: {'total': 5, 'repeated': 2},
          );
  });

  Future<void> pump(
    WidgetTester tester, {
    String initial = RoutePaths.exams,
    bool freshEnabled = true,
    BillingMode mode = BillingMode.play,
    Entitlements ent = Entitlements.initial,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: RoutePaths.exams, builder: (_, __) => buildExamsTab()),
        ...examRoutes.where((r) => r is GoRoute && r.path != RoutePaths.examRun),
        GoRoute(path: RoutePaths.examRun, builder: (_, __) => const Text('RUNNER_PAGE')),
        GoRoute(path: RoutePaths.store, builder: (_, __) => const Text('STORE_PAGE')),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        examCatalogRepositoryProvider.overrideWithValue(_Catalog()),
        examRemoteProvider.overrideWithValue(remote),
        examLocalStoreProvider.overrideWithValue(store),
        examUidProvider.overrideWithValue('u1'),
        examLanguageProvider.overrideWith((ref) => 'ru'),
        examClockProvider.overrideWithValue(() => t0),
        examPoolConfigProvider.overrideWith(
            (ref) => Stream.value(ExamPoolConfig(freshEnabled: freshEnabled))),
        entitlementsProvider.overrideWith((ref) => Stream.value(ent)),
        billingModeProvider.overrideWithValue(mode),
      ],
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
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  Finder scrollable() => find.byType(Scrollable).first;

  Future<void> tapScrolled(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200, scrollable: scrollable());
    await tester.pump(); // lay out at the new scroll offset before tapping
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  group('catalog', () {
    testWidgets('«Новый пробный» per direction; library variants stay as a secondary list',
        (tester) async {
      await pump(tester);
      final mainFresh = find.byKey(const ValueKey('fresh_start_ort_main_2026'));
      await tester.scrollUntilVisible(mainFresh, 200, scrollable: scrollable());
      expect(find.descendant(of: mainFresh, matching: find.text('Новый пробный')),
          findsOneWidget);
      await tester.scrollUntilVisible(find.text('Вариант 1'), 200, scrollable: scrollable());
      expect(find.text('Готовые варианты'), findsWidgets);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('fresh_start_ort_state_language_2026')), 300,
          scrollable: scrollable());
      expect(tester.takeException(), isNull);
    });

    testWidgets('config/exam_pool.fresh_enabled = false hides it; library remains',
        (tester) async {
      await pump(tester, freshEnabled: false);
      expect(find.text('Новый пробный'), findsNothing);
      await tester.scrollUntilVisible(find.text('Вариант 1'), 200, scrollable: scrollable());
      expect(find.text('Вариант 1'), findsOneWidget);
    });

    testWidgets('tapping it opens the fresh rules screen in the catalog language',
        (tester) async {
      await pump(tester);
      await tapScrolled(tester, find.byKey(const ValueKey('fresh_start_ort_main_2026')));
      expect(find.text('Новый вариант — соберём при старте · Язык теста: Русский'),
          findsOneWidget);
      final ru = tester.widget<ChoiceChip>(find.byKey(const ValueKey('fresh_lang_ru')));
      expect(ru.selected, isTrue);
      expect(find.byKey(const ValueKey('fresh_lang_ky')), findsOneWidget);
    });
  });

  group('fresh rules screen', () {
    testWidgets('language + «Как на ОРТ» → examStart(mode fresh) → runner',
        (tester) async {
      await pump(tester, initial: RoutePaths.examFreshFor('ort_main_2026', language: 'ru'));
      await tester.tap(find.byKey(const ValueKey('fresh_lang_ky')));
      await tester.pump();
      expect(find.textContaining('Язык теста: Кыргызский'), findsOneWidget);

      // Standard is preselected; its rules mention flags / free navigation.
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('exam_rules_standard')), 200, scrollable: scrollable());
      expect(find.textContaining('Раздел нельзя завершить досрочно'), findsNothing);
      await tapScrolled(tester, find.byKey(const ValueKey('exam_style_strict')));
      expect(find.textContaining('Это тренировка: результат учебный'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('exam_rules_strict')), 200, scrollable: scrollable());
      expect(find.textContaining('Раздел нельзя завершить досрочно'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('exam_start_button')));
      await tester.pumpAndSettle();
      final r = remote.startRequests.single;
      expect(r.mode, ExamMode.fresh);
      expect(r.blueprintId, 'ort_main_2026');
      expect(r.language, 'ky');
      expect(r.style, ExamStyle.strict);
      expect(r.variantId, isNull);
      expect(find.text('RUNNER_PAGE'), findsOneWidget);
      // The session the runner opens with: strict, freshness kept.
      expect(store.saved!.isStrict, isTrue);
      expect(store.saved!.freshness!.repeated, 2);
    });

    testWidgets('state language test: Kyrgyz only', (tester) async {
      await pump(tester,
          initial: RoutePaths.examFreshFor('ort_state_language_2026', language: 'ru'));
      expect(find.byKey(const ValueKey('fresh_lang_ru')), findsNothing);
      expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('fresh_lang_ky'))).selected,
          isTrue);
      expect(find.text('Тест по государственному языку проводится только на кыргызском.'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('exam_start_button')));
      await tester.pumpAndSettle();
      expect(remote.startRequests.single.language, 'ky');
      expect(remote.startRequests.single.style, ExamStyle.standard);
    });

    testWidgets('POOL_TOO_SMALL: honest message, no credit charged, way back',
        (tester) async {
      remote.onStart = () => throw const ExamFailure(ExamFailureKind.poolTooSmall, null,
          {'reason': 'POOL_TOO_SMALL', 'section_id': 'reading', 'part_id': 'p1'});
      await pump(tester);
      await tapScrolled(tester, find.byKey(const ValueKey('fresh_start_ort_main_2026')));
      await tester.tap(find.byKey(const ValueKey('exam_start_button')));
      await tester.pumpAndSettle();
      expect(find.text('RUNNER_PAGE'), findsNothing);
      final card = find.byKey(const ValueKey('exam_pool_too_small'));
      expect(card, findsOneWidget);
      expect(find.text('Новые варианты ещё готовятся'), findsOneWidget);
      expect(find.textContaining('Кредит не списан'), findsOneWidget);
      expect(find.textContaining('(Русский)'), findsOneWidget);
      expect(store.saved, isNull);
      await tester.tap(find.text('К готовым вариантам'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('fresh_start_ort_main_2026')), findsOneWidget,
          reason: 'back in the catalog');
    });

    testWidgets('external build without credits: neutral, no purchase path',
        (tester) async {
      await pump(tester,
          initial: RoutePaths.examFreshFor('ort_main_2026'),
          mode: BillingMode.external,
          ent: const Entitlements(
              freeExamUsed: true, credits: 0, lifetimeCreditsPurchased: 0));
      expect(find.byKey(const ValueKey('exam_no_credits_button')), findsOneWidget);
      expect(find.textContaining('Купить'), findsNothing);
      expect(find.textContaining('сом'), findsNothing);
    });
  });

  testWidgets('library variant: the same style choice is sent with mode library',
      (tester) async {
    remote.onStart = () => startPayload(examStyle: 'strict');
    await pump(tester, initial: RoutePaths.examIntroFor('v1'));
    await tapScrolled(tester, find.byKey(const ValueKey('exam_style_strict')));
    await tester.tap(find.byKey(const ValueKey('exam_start_button')));
    await tester.pumpAndSettle();
    final r = remote.startRequests.single;
    expect(r.mode, ExamMode.library);
    expect(r.variantId, 'v1');
    expect(r.style, ExamStyle.strict);
    expect(find.text('RUNNER_PAGE'), findsOneWidget);
    expect(store.saved!.isStrict, isTrue);
  });
}
