import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/dashboard/data/dashboard_providers.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/gamification/domain/achievement_catalog.dart';
import 'package:knowledge_flow/features/gamification/domain/achievement_config.dart';
import 'package:knowledge_flow/features/progress/data/progress_repository.dart';
import 'package:knowledge_flow/features/progress/domain/motivation_risk.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

void main() {
  // Wednesday 2026-11-04, 15:00 in Bishkek.
  final now = DateTime.utc(2026, 11, 4, 9);

  ExamPoint exam(String id, double percent, int day, {String direction = 'ort_main'}) => ExamPoint(
        attemptId: id,
        direction: direction,
        percent: percent,
        completedAt: DateTime.utc(2026, 10, day, 10),
      );

  group('motivation risk (ARCHITECTURE §9.5)', () {
    test('days since the last active Bishkek day', () {
      expect(MotivationRules.daysSince('2026-11-04', now), 0);
      expect(MotivationRules.daysSince('2026-11-01', now), 3);
      expect(MotivationRules.daysSince(null, now), isNull);
      expect(MotivationRules.daysSince('04.11.2026', now), isNull);
      // 23:30 UTC on Nov 3 is already Nov 4 in Bishkek.
      expect(MotivationRules.daysSince('2026-11-01', DateTime.utc(2026, 11, 3, 23, 30)), 3);
    });

    test('no activity for 3+ days is a risk; 2 days is not', () {
      final risk = MotivationRules.evaluate(lastActiveDay: '2026-11-01', exams: const [], now: now)!;
      expect(risk.isInactive, isTrue);
      expect(risk.inactiveDays, 3);
      expect(risk.isDeclining, isFalse);
      expect(MotivationRules.evaluate(lastActiveDay: '2026-11-02', exams: const [], now: now), isNull);
    });

    test('a new account with nothing recorded gets no nudge', () {
      expect(MotivationRules.evaluate(lastActiveDay: null, exams: const [], now: now), isNull);
    });

    test('the last two exams of the same direction falling is a risk', () {
      final risk = MotivationRules.evaluate(
        lastActiveDay: '2026-11-04',
        exams: [exam('a', 62, 20), exam('b', 55.5, 28)],
        now: now,
      )!;
      expect(risk.isDeclining, isTrue);
      expect(risk.isInactive, isFalse);
      expect(risk.previousPercent, 62);
      expect(risk.latestPercent, 55.5);
      expect(risk.latestAttemptId, 'b');
    });

    test('an improving or equal result is not a risk', () {
      expect(
        MotivationRules.evaluate(lastActiveDay: '2026-11-04', exams: [exam('a', 50, 20), exam('b', 60, 28)], now: now),
        isNull,
      );
      expect(
        MotivationRules.evaluate(lastActiveDay: '2026-11-04', exams: [exam('a', 60, 20), exam('b', 60, 28)], now: now),
        isNull,
      );
    });

    test('different directions are not compared with each other', () {
      // Main test 70% then chemistry 40%: not comparable, no "drop".
      expect(
        MotivationRules.evaluate(
          lastActiveDay: '2026-11-04',
          exams: [exam('a', 70, 20), exam('b', 40, 28, direction: 'ort_subject_chemistry')],
          now: now,
        ),
        isNull,
      );
      // …but the latest is compared with the previous attempt of its direction.
      final risk = MotivationRules.evaluate(
        lastActiveDay: '2026-11-04',
        exams: [exam('a', 70, 10), exam('x', 30, 15, direction: 'ort_subject_chemistry'), exam('b', 65, 28)],
        now: now,
      )!;
      expect(risk.previousPercent, 70);
      expect(risk.latestPercent, 65);
    });

    test('order of the input does not matter; both reasons can apply', () {
      final risk = MotivationRules.evaluate(
        lastActiveDay: '2026-10-29',
        exams: [exam('b', 40, 28), exam('a', 45, 20)],
        now: now,
      )!;
      expect(risk.reasons, {MotivationRiskReason.inactive, MotivationRiskReason.decliningResults});
      expect(risk.inactiveDays, 6);
    });

    test('the home screen builds points from attempt documents', () {
      final points = examPointsFrom([
        (id: 'old', data: {'status': 'completed', 'blueprint_id': 'ort_main_2026', 'result': {'percent': 50}}),
        (id: 'running', data: {'status': 'in_progress', 'blueprint_id': 'ort_main_2026'}),
      ]);
      expect(points.single.attemptId, 'old');
      expect(points.single.direction, 'ort_main');
    });
  });

  group('frequent mistakes', () {
    test('top 5 topics by summed wrong_count; items without a topic are skipped', () {
      final top = topMistakeTopics([
        {'topic_id': 'math.powers', 'wrong_count': 3},
        {'topic_id': 'math.powers', 'wrong_count': 2},
        {'topic_id': 'math.linear', 'wrong_count': 4},
        {'topic_id': null, 'wrong_count': 9},
        {'topic_id': 'a', 'wrong_count': 1},
        {'topic_id': 'b', 'wrong_count': 1},
        {'topic_id': 'c', 'wrong_count': 1},
        {'topic_id': 'd', 'wrong_count': 1},
        {'topic_id': 'e'}, // wrong_count missing → 1
      ]);
      expect(top.map((t) => t.topicId), ['math.powers', 'math.linear', 'a', 'b', 'c']);
      expect(top.first.wrongCount, 5);
      expect(top, hasLength(5));
    });
  });

  group('time per topic', () {
    test('latest completed attempt that has timings', () {
      final snap = TopicTimeSnapshot.latestOf([
        (
          id: 'new-no-timings',
          data: {'status': 'completed', 'completed_at': DateTime.utc(2026, 11, 3), 'result': {'percent': 40}},
        ),
        (
          id: 'with',
          data: {
            'status': 'completed',
            'completed_at': DateTime.utc(2026, 11, 1),
            'result': {
              'topic_time_avg': {'math.powers': 95.5, 'math.linear': 30},
              'slow_topics': ['math.powers'],
            },
          },
        ),
        (
          id: 'older',
          data: {
            'status': 'completed',
            'completed_at': DateTime.utc(2026, 10, 1),
            'result': {'topic_time_avg': {'x': 10}},
          },
        ),
        (id: 'running', data: {'status': 'in_progress', 'result': {'topic_time_avg': {'y': 1}}}),
      ])!;
      expect(snap.attemptId, 'with');
      expect(snap.avgSeconds, {'math.powers': 95.5, 'math.linear': 30.0});
      expect(snap.slowTopics, {'math.powers'});
      expect(TopicTimeSnapshot.latestOf(const []), isNull);
    });

    test('ExamResult reads topic_time_avg and slow_topics', () {
      final r = ExamResult.fromJson({
        'correct': 1,
        'total': 2,
        'topic_time_avg': {'math.powers': 120, 'bad': -1},
        'slow_topics': ['math.powers', ''],
      });
      expect(r.topicTimeAvg, {'math.powers': 120.0});
      expect(r.slowTopics, ['math.powers']);
      expect(ExamResult.fromJson(r.toJson()).slowTopics, ['math.powers']);
      expect(ExamResult.fromJson({'correct': 1, 'total': 2}).slowTopics, isEmpty);
    });
  });

  group('config/achievements', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    final def = AchievementCatalog.all.firstWhere((a) => a.id == 'streak_7');

    test('configured ru/ky texts win, built-in strings otherwise', () {
      final config = AchievementConfig.fromMap({
        'titles': {
          'streak_7': {'ru': 'Неделя без пропусков', 'ky': 'Бир апта катары менен'},
        },
        'descriptions': {
          'streak_7': {'ru': '  '},
        },
        'disabled': ['reader'],
      });
      expect(config.title(def, ru, 'ru'), 'Неделя без пропусков');
      expect(config.title(def, ru, 'ky'), 'Бир апта катары менен');
      expect(config.title(def, ru, 'en'), def.title(ru), reason: 'no English copy in config');
      expect(config.description(def, ru, 'ru'), def.description(ru), reason: 'blank text ignored');
    });

    test('disabled ids are hidden, order kept', () {
      final config = AchievementConfig.fromMap({'disabled': ['reader', 'xp_100']});
      final ids = config.visible(AchievementCatalog.all).map((a) => a.id).toList();
      expect(ids, isNot(contains('reader')));
      expect(ids, isNot(contains('xp_100')));
      expect(ids.first, 'first_lesson');
      expect(ids, hasLength(AchievementCatalog.all.length - 2));
      expect(AchievementConfig.fromMap(null).visible(AchievementCatalog.all), hasLength(AchievementCatalog.all.length));
    });
  });
}
