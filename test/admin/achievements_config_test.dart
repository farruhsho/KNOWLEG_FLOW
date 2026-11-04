import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/admin/domain/achievements_config.dart';
import 'package:knowledge_flow/features/gamification/domain/achievement_catalog.dart';

void main() {
  test('the editor covers exactly the server achievements (§1.7) in catalog order', () {
    expect(kAchievementIds, [for (final a in AchievementCatalog.all) a.id]);
    expect(kAchievementIds, [
      'first_lesson',
      'xp_100',
      'streak_7',
      'days_30',
      'accuracy_90',
      'math_expert',
      'analogies_master',
      'reader',
      'exam_champion',
    ]);
  });

  group('toFirestore: only the keys the rules allow', () {
    test('an empty config still writes exactly titles, descriptions, disabled', () {
      final m = AchievementsConfig.empty.toFirestore();
      expect(m.keys.toSet(), kAchievementsConfigKeys);
      expect(kAchievementsConfigKeys, {'titles', 'descriptions', 'disabled'});
      expect(m, {'titles': <String, Object>{}, 'descriptions': <String, Object>{}, 'disabled': <String>[]});
    });

    test('unknown ids, unknown locales and empty texts are dropped; values trimmed', () {
      final c = AchievementsConfig.fromEditor(
        titles: {
          'first_lesson': {'ru': ' Первый шаг ', 'ky': 'Биринчи кадам', 'en': 'First step'},
          'xp_100': {'ru': '', 'ky': '  '},
          'hacker': {'ru': 'x', 'ky': 'y'},
        },
        descriptions: {
          'reader': {'ru': 'Читатель', 'ky': 'Окурман'},
        },
        disabled: {'exam_champion', 'streak_7', 'unknown'},
      );
      expect(c.toFirestore(), {
        'titles': {
          'first_lesson': {'ru': 'Первый шаг', 'ky': 'Биринчи кадам'},
        },
        'descriptions': {
          'reader': {'ru': 'Читатель', 'ky': 'Окурман'},
        },
        // Catalog order, known ids only.
        'disabled': ['streak_7', 'exam_champion'],
      });
    });

    test('round trip through fromMap', () {
      final doc = {
        'titles': {
          'math_expert': {'ru': 'Математик', 'ky': 'Математик'},
        },
        'descriptions': {
          'math_expert': {'ru': '90% по математике', 'ky': 'Математикадан 90%'},
        },
        'disabled': ['reader'],
      };
      expect(AchievementsConfig.fromMap(doc).toFirestore(), doc);
    });
  });

  group('fromMap is tolerant', () {
    test('missing document = empty, not existing', () {
      final c = AchievementsConfig.fromMap(null);
      expect(c.exists, isFalse);
      expect(c.isEnabled('first_lesson'), isTrue);
    });

    test('garbage is ignored, legacy kg becomes ky', () {
      final c = AchievementsConfig.fromMap({
        'titles': {
          'xp_100': {'ru': 'Сотня', 'kg': 'Жүз'},
          'streak_7': 'not a map',
          'nope': {'ru': 'x'},
        },
        'descriptions': ['wrong'],
        'disabled': ['days_30', 7, 'nope'],
        'extra': true,
      });
      expect(c.exists, isTrue);
      expect(c.titles, {
        'xp_100': {'ru': 'Сотня', 'ky': 'Жүз'},
      });
      expect(c.descriptions, isEmpty);
      expect(c.disabled, {'days_30'});
      expect(c.isEnabled('days_30'), isFalse);
      expect(c.toFirestore().keys.toSet(), kAchievementsConfigKeys);
    });
  });

  group('validate', () {
    test('both languages or neither', () {
      final c = AchievementsConfig.fromEditor(
        titles: {
          'reader': {'ru': 'Читатель', 'ky': ''},
        },
        descriptions: {
          'reader': {'ru': '', 'ky': 'Окурман'},
        },
        disabled: const {},
      );
      expect(c.validate(), [
        const AchievementIssue(
            'reader', AchievementField.title, AchievementIssueKind.missingTranslation, 'ky'),
        const AchievementIssue(
            'reader', AchievementField.description, AchievementIssueKind.missingTranslation, 'ru'),
      ]);
    });

    test('length limits (code points)', () {
      final c = AchievementsConfig.fromEditor(
        titles: {
          'xp_100': {'ru': 'а' * kAchievementTitleMax, 'ky': 'ө' * (kAchievementTitleMax + 1)},
        },
        descriptions: {
          'xp_100': {'ru': 'd' * (kAchievementDescriptionMax + 1), 'ky': 'd'},
        },
        disabled: const {},
      );
      expect(c.validate(), [
        const AchievementIssue('xp_100', AchievementField.title, AchievementIssueKind.tooLong, 'ky'),
        const AchievementIssue('xp_100', AchievementField.description, AchievementIssueKind.tooLong, 'ru'),
      ]);
    });

    test('an untouched config is valid', () {
      expect(AchievementsConfig.empty.validate(), isEmpty);
    });
  });
}
