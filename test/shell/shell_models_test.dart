import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/routes/app_router.dart';
import 'package:knowledge_flow/features/auth/domain/auth_validation.dart';
import 'package:knowledge_flow/features/dashboard/data/dashboard_providers.dart';
import 'package:knowledge_flow/features/dashboard/domain/dashboard_models.dart';
import 'package:knowledge_flow/features/onboarding/data/kg_regions_provider.dart';
import 'package:knowledge_flow/features/onboarding/domain/onboarding_answers.dart';
import 'package:knowledge_flow/shared/models/user_model.dart';
import 'package:knowledge_flow/shared/models/user_settings_model.dart';

void main() {
  group('UserModel tolerant parsing (MODEL-01)', () {
    test('int weak_subjects and string grade no longer throw', () {
      final user = UserModel.fromMap('u1', {
        'name': 'Айбек',
        'grade': '10',
        'weak_subjects': {'math': 3, 'physics': 0.5, 'bad': 'x'},
        'target_universities': 'КГМА',
        'daily_goal_minutes': 20,
        'goal_band': '150+',
      });
      expect(user.grade, 10);
      expect(user.weakSubjects, {'math': 3.0, 'physics': 0.5});
      expect(user.targetUniversities, ['КГМА']);
      expect(user.dailyGoalMinutes, 20);
      expect(user.goalBand, '150+');
      expect(user.hasStudyProfile, isTrue);
      expect(user.role, 'student');
    });

    test('missing fields fall back to defaults', () {
      final user = UserModel.fromMap('u2', const {});
      expect(user.name, '');
      expect(user.grade, 11);
      expect(user.preferredLanguage, 'ru');
      expect(user.region, isNull);
      expect(user.hasStudyProfile, isFalse);
    });

    test('legacy string region and ISO dates are understood', () {
      final user = UserModel.fromMap('u3', {
        'region': 'Чуйская область',
        'region_last_updated': '2026-01-02T00:00:00.000',
        'created_at': Timestamp.fromDate(DateTime(2025, 5, 1)),
      });
      expect(user.region?.oblast, 'Чуйская область');
      expect(user.regionLastUpdated, DateTime(2026, 1, 2));
      expect(user.createdAt, DateTime(2025, 5, 1));
    });

    test('toFirestore still never writes role and adds goal fields', () {
      final user = UserModel.fromMap('u4', {
        'role': 'admin',
        'daily_goal_minutes': 30,
      });
      final map = user.toFirestore();
      expect(map.containsKey('role'), isFalse);
      expect(map['daily_goal_minutes'], 30);
      expect(map.containsKey('goal_band'), isFalse);
    });
  });

  group('UserSettingsModel uses the users-doc shape (MODEL-01)', () {
    test('reads snake_case and legacy camelCase', () {
      final s = UserSettingsModel.fromFirestore({
        'preferred_language': 'ky',
        'region': {'oblast': 'Нарынская область', 'district': 'Ат-Башы', 'settlement': ''},
        'regionLastUpdated': '2026-03-01T00:00:00.000',
      }, 'u1');
      expect(s.language, 'ky');
      expect(s.region, 'Нарынская область');
      expect(s.regionLastUpdated, DateTime(2026, 3, 1));
    });

    test('writes snake_case fields and keeps the region map shape', () {
      final s = UserSettingsModel.fromFirestore({
        'region': {'oblast': 'Нарынская область', 'district': 'Ат-Башы', 'settlement': ''},
      }, 'u1');
      final out = s.toFirestore();
      expect(out['preferred_language'], 'ru');
      expect(out['region'], {
        'oblast': 'Нарынская область',
        'district': 'Ат-Башы',
        'settlement': '',
      });
      expect(out.containsKey('regionLastUpdated'), isFalse);
    });
  });

  group('OnboardingAnswers (ONB-01)', () {
    test('only answered questions are written, using existing fields', () {
      const answers = OnboardingAnswers(
        language: 'ky',
        grade: 11,
        goalBand: '150+',
        targetUniversity: '  КНУ ',
        oblast: 'Ош',
        dailyGoalMinutes: 20,
      );
      final fields = answers.toUserFields(completedAt: 'now');
      expect(fields, {
        'preferred_language': 'ky',
        'grade': 11,
        'goal_band': '150+',
        'target_universities': ['КНУ'],
        'region': {'oblast': 'Ош', 'district': '', 'settlement': ''},
        'daily_goal_minutes': 20,
        'onboarding_completed_at': 'now',
      });

      final partial = const OnboardingAnswers(grade: 9).toUserFields(completedAt: 1);
      expect(partial.keys, unorderedEquals(['grade', 'onboarding_completed_at']));
    });

    test('JSON round trip drops invalid values', () {
      const answers = OnboardingAnswers(
        language: 'ru',
        grade: OnboardingAnswers.gradeGraduate,
        dailyGoalMinutes: 30,
        oblast: 'Бишкек',
        district: 'Свердловский район',
      );
      expect(OnboardingAnswers.fromJson(answers.toJson()), answers);
      final bad = OnboardingAnswers.fromJson(
          {'language': 'de', 'grade': 5, 'daily_goal_minutes': 45, 'goal_band': '999'});
      expect(bad.language, isNull);
      expect(bad.grade, isNull);
      expect(bad.dailyGoalMinutes, isNull);
      expect(bad.goalBand, isNull);
    });
  });

  group('UserStats (server stats, GAM-07)', () {
    final now = DateTime.utc(2026, 11, 2, 10); // 16:00 in Bishkek

    test('Bishkek day boundary is UTC+6', () {
      expect(UserStats.bishkekDay(DateTime.utc(2026, 11, 2, 17, 59)), '2026-11-02');
      expect(UserStats.bishkekDay(DateTime.utc(2026, 11, 2, 18, 0)), '2026-11-03');
    });

    test('a streak older than yesterday is shown as broken', () {
      final active = UserStats.fromMap(const {
        'current_streak': 4, 'last_active_day': '2026-11-01', 'today_xp': 30,
      });
      expect(active.effectiveStreak(now), 4);
      expect(active.effectiveTodayXp(now), 0, reason: 'XP belongs to yesterday');

      final stale = UserStats.fromMap(const {
        'current_streak': 9, 'last_active_day': '2026-10-28',
      });
      expect(stale.effectiveStreak(now), 0);
    });

    test('new users are recognised as empty', () {
      expect(UserStats.fromMap(null).isEmpty, isTrue);
      expect(UserStats.fromMap(const {'xp': 10}).isEmpty, isFalse);
    });
  });

  group('next step rule', () {
    test('no exam yet → first mock', () {
      expect(decideNextStep(examsCompleted: 0, latest: null),
          const NextStep(NextStepKind.firstMock));
    });

    test('weak topic from the latest exam → learn', () {
      final latest = LatestExamSummary.fromDoc('a1', {
        'status': 'completed',
        'result': {
          'percent': 61.5,
          'weak_topics': ['math.quadratic_equations', 'reading.main_idea'],
        },
      });
      expect(decideNextStep(examsCompleted: 1, latest: latest),
          const NextStep(NextStepKind.weakTopic, topicId: 'math.quadratic_equations'));
      expect(topicArea('math.quadratic_equations'), 'math');
    });

    test('completed exam without weak topics → practice', () {
      final latest = LatestExamSummary.fromDoc('a2', {'status': 'completed', 'result': {}});
      expect(decideNextStep(examsCompleted: 1, latest: latest),
          const NextStep(NextStepKind.practice));
      expect(LatestExamSummary.fromDoc('a3', {'status': 'in_progress'}), isNull);
    });
  });

  test('blueprint area titles are parsed from the bundled format', () {
    const raw = '{"blueprints":[{"sections":[{"id":"math","subject_area":"math",'
        '"title":{"ru":"Математика","ky":"Математика"}},{"id":"verbal",'
        '"title":{"ru":"Вербальная часть"}}]}]}';
    final titles = parseAreaTitles(raw);
    expect(titles['math']?['ru'], 'Математика');
    expect(titles['verbal']?['ru'], 'Вербальная часть');
  });

  test('regions are parsed from kg_regions.json format', () {
    const raw = '{"regions":[{"oblast":"Ош","districts":[{"name":"Ош шаары","settlements":[]}]},{"oblast":""}]}';
    final regions = parseKgRegions(raw);
    expect(regions.length, 1);
    expect(regions.single.districts.single.name, 'Ош шаары');
  });

  group('quiz results args (route must not crash without extra)', () {
    test('missing or invalid extra yields null', () {
      expect(QuizResultsArgs.tryParse(null), isNull);
      expect(QuizResultsArgs.tryParse('x'), isNull);
      expect(QuizResultsArgs.tryParse({'totalQuestions': 0}), isNull);
    });

    test('valid extra is parsed and clamped', () {
      final args = QuizResultsArgs.tryParse(
          {'totalQuestions': 10, 'correctAnswers': 12, 'totalTimeSeconds': -3})!;
      expect(args.totalQuestions, 10);
      expect(args.correctAnswers, 10);
      expect(args.totalTimeSeconds, 0);
    });
  });

  group('auth validation (SEC-005R)', () {
    test('email format', () {
      expect(AuthValidators.email(''), AuthFieldError.emailEmpty);
      expect(AuthValidators.email('abc'), AuthFieldError.emailInvalid);
      expect(AuthValidators.email('a@b'), AuthFieldError.emailInvalid);
      expect(AuthValidators.email(' student@mail.kg '), isNull);
    });

    test('new passwords need 8+ chars with letters and digits', () {
      expect(AuthValidators.newPassword('abc12'), AuthFieldError.passwordTooShort);
      expect(AuthValidators.newPassword('abcdefgh'), AuthFieldError.passwordTooWeak);
      expect(AuthValidators.newPassword('12345678'), AuthFieldError.passwordTooWeak);
      expect(AuthValidators.newPassword('сыр12345'), isNull);
      expect(AuthValidators.confirmPassword('x', 'y'), AuthFieldError.passwordMismatch);
    });

    test('Firebase codes map to human failures, cancellations to nothing', () {
      expect(authFailureForCode('invalid-credential'), AuthFailure.invalidCredentials);
      expect(authFailureForCode('wrong-password'), AuthFailure.invalidCredentials);
      expect(authFailureForCode('email-already-in-use'), AuthFailure.emailInUse);
      expect(authFailureForCode('network-request-failed'), AuthFailure.network);
      expect(authFailureForCode('popup-closed-by-user'), isNull);
      expect(authFailureForCode('something-new'), AuthFailure.unknown);
    });
  });
}
