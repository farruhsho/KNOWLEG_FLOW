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
import 'package:knowledge_flow/features/exam/domain/exam_variant.dart';
import 'package:knowledge_flow/features/exam/domain/localized_text.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exam_intro_page.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

import 'exam_fakes.dart';

class _Catalog implements ExamCatalogRepository {
  final blueprints = ExamBlueprint.listFromJson(
      jsonDecode(File('assets/data/exam_blueprints.json').readAsStringSync()));

  @override
  Future<List<ExamBlueprint>> loadBlueprints() async => blueprints;

  @override
  Future<ExamBlueprint?> loadBlueprint(String id) async =>
      blueprints.where((b) => b.id == id).firstOrNull;

  @override
  Future<ExamVariant?> loadVariant(String variantId) async => const ExamVariant(
        id: 'v1',
        blueprintId: 'ort_subject_chemistry_2026',
        blueprintVersion: 1,
        number: 1,
        title: LocalizedText.empty,
        language: 'ru',
        status: 'published',
      );

  @override
  Future<VariantPage> loadVariants({
    required String blueprintId,
    required String language,
    int? afterNumber,
    int limit = 20,
  }) async =>
      const VariantPage(items: [], hasMore: false);

  @override
  Stream<List<AttemptSummary>> watchMyAttempts(String uid) => Stream.value(const []);

  @override
  Future<AttemptPage> loadHistory(String uid, {Object? cursor, int limit = 20}) async =>
      const AttemptPage(items: [], hasMore: false);

  @override
  Future<AttemptSummary?> loadAttempt(String attemptId) async => null;
}

const _noCredits =
    Entitlements(freeExamUsed: true, credits: 0, lifetimeCreditsPurchased: 0);
const _oneCredit =
    Entitlements(freeExamUsed: true, credits: 1, lifetimeCreditsPurchased: 1);

void main() {
  late FakeExamRemote remote;

  setUp(() => remote = FakeExamRemote());

  Future<void> pumpIntro(
    WidgetTester tester, {
    required BillingMode mode,
    required Entitlements ent,
    bool platformSupported = true,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: RoutePaths.examIntroFor('v1'),
      routes: [
        GoRoute(
          path: RoutePaths.examIntro,
          builder: (_, s) => ExamIntroPage(variantId: s.pathParameters['variantId']!),
        ),
        GoRoute(path: RoutePaths.store, builder: (_, __) => const Text('STORE_PAGE')),
        GoRoute(path: RoutePaths.examRun, builder: (_, __) => const Text('RUNNER_PAGE')),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        examCatalogRepositoryProvider.overrideWithValue(_Catalog()),
        examRemoteProvider.overrideWithValue(remote),
        examLocalStoreProvider.overrideWithValue(MemoryExamStore()),
        examUidProvider.overrideWithValue('u1'),
        entitlementsProvider.overrideWith((ref) => Stream.value(ent)),
        billingModeProvider.overrideWithValue(mode),
        examCallablesSupportedProvider.overrideWithValue(platformSupported),
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

  group('BILLING_MODE=external (BILL-EXT-01)', () {
    testWidgets('no credits: neutral disabled button, no purchase wording', (tester) async {
      await pumpIntro(tester, mode: BillingMode.external, ent: _noCredits);
      expect(find.text('Нет доступных кредитов'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(find.ancestor(
          of: find.text('Нет доступных кредитов'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
      expect(button.onPressed, isNull);
      expect(find.textContaining('Купить'), findsNothing);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NO_ENTITLEMENT from the server never opens the store', (tester) async {
      remote.onStart = () => throw const ExamFailure(ExamFailureKind.noEntitlement);
      await pumpIntro(tester, mode: BillingMode.external, ent: _oneCredit);
      await tester.tap(find.byKey(const ValueKey('exam_start_button')));
      await tester.pump();
      await tester.pump();
      expect(remote.startCalls, 1);
      expect(find.text('Чтобы начать тест, нужен 1 кредит.'), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('STORE_PAGE'), findsNothing);
    });

    testWidgets('play build keeps the purchase path (control)', (tester) async {
      await pumpIntro(tester, mode: BillingMode.play, ent: _noCredits);
      expect(find.text('Купить тест'), findsOneWidget);
      await tester.tap(find.text('Купить тест'));
      await tester.pumpAndSettle();
      expect(find.text('STORE_PAGE'), findsOneWidget);
    });
  });

  testWidgets('USER_BANNED on start shows a clear message (D5)', (tester) async {
    remote.onStart = () => throw const ExamFailure(ExamFailureKind.userBanned);
    await pumpIntro(tester, mode: BillingMode.play, ent: _oneCredit);
    await tester.tap(find.byKey(const ValueKey('exam_start_button')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('заблокирован модератором'), findsOneWidget);
    expect(find.text('RUNNER_PAGE'), findsNothing);
  });

  testWidgets('Windows / Linux: "not available on this device" instead of Start (D7)',
      (tester) async {
    await pumpIntro(tester,
        mode: BillingMode.play, ent: _oneCredit, platformSupported: false);
    expect(find.byKey(const ValueKey('exam_platform_notice')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam_start_button')), findsNothing);
    final button = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Недоступно на этом устройстве'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(button.onPressed, isNull);
    expect(remote.startCalls, 0);
  });
}
