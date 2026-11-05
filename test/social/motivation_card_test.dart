import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/dashboard/data/dashboard_providers.dart';
import 'package:knowledge_flow/features/dashboard/domain/dashboard_models.dart';
import 'package:knowledge_flow/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:knowledge_flow/features/progress/domain/motivation_risk.dart';
import 'package:knowledge_flow/features/progress/presentation/widgets/motivation_risk_card.dart';

import 'social_fakes.dart';

void main() {
  late FakeSocialRepository repo;
  setUp(() => repo = FakeSocialRepository());
  tearDown(() => repo.dispose());

  const both = MotivationRisk(
    reasons: {MotivationRiskReason.inactive, MotivationRiskReason.decliningResults},
    inactiveDays: 5,
    previousPercent: 62,
    latestPercent: 55.5,
    latestAttemptId: 'att9',
  );

  testWidgets('progress card: reasons with explanation and a concrete next step', (tester) async {
    await pumpSocial(tester, const Scaffold(body: SingleChildScrollView(child: MotivationRiskCard(risk: both))),
        repo: repo);
    expect(find.text('Не теряйте темп'), findsOneWidget);
    expect(find.text('Результат последнего пробного экзамена снизился: было 62%, стало 55,5%.'), findsOneWidget);
    expect(find.text('Вы не занимались 5 дней.'), findsOneWidget);
    expect(find.textContaining('Спад — это нормально'), findsOneWidget);
    expect(find.text('Следующий шаг: разберите ошибки последнего экзамена.'), findsOneWidget);
    await tester.tap(find.text('Разобрать ошибки'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /exams/attempt/att9/review'), findsOneWidget);
  });

  testWidgets('inactivity only → quick practice', (tester) async {
    const risk = MotivationRisk(reasons: {MotivationRiskReason.inactive}, inactiveDays: 3);
    await pumpSocial(tester, const Scaffold(body: MotivationRiskCard(risk: risk)), repo: repo);
    expect(find.text('Вы не занимались 3 дня.'), findsOneWidget);
    expect(find.textContaining('10 быстрых вопросов'), findsOneWidget);
    await tester.tap(find.text('Быстрая практика'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /quick-test'), findsOneWidget);
  });

  testWidgets('home: compact nudge from server stats and recent exams', (tester) async {
    await pumpSocial(
      tester,
      const Scaffold(body: MotivationNudgeCard()),
      repo: repo,
      overrides: [
        dashboardClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 9)),
        userStatsProvider.overrideWith((ref) => Stream.value(const UserStats(xp: 300, lastActiveDay: '2026-10-30'))),
        recentExamPointsProvider.overrideWith((ref) async => const <ExamPoint>[]),
      ],
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('motivation_risk_card')), findsOneWidget);
    expect(find.text('Вы не занимались 5 дней.'), findsOneWidget);
    // Compact: no long explanation.
    expect(find.textContaining('выученное быстрее забывается'), findsNothing);
  });

  testWidgets('home: nothing when the student was active and results hold', (tester) async {
    await pumpSocial(
      tester,
      const Scaffold(body: MotivationNudgeCard()),
      repo: repo,
      overrides: [
        dashboardClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 9)),
        userStatsProvider.overrideWith((ref) => Stream.value(const UserStats(xp: 300, lastActiveDay: '2026-11-03'))),
        recentExamPointsProvider.overrideWith((ref) async => const <ExamPoint>[]),
      ],
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('motivation_risk_card')), findsNothing);
  });

  for (final locale in ['ky', 'en']) {
    testWidgets('[$locale] dark 360dp without overflow', (tester) async {
      await pumpSocial(tester, const Scaffold(body: SingleChildScrollView(child: MotivationRiskCard(risk: both))),
          repo: repo, locale: locale, brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  }
}
