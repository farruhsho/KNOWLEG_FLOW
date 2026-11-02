import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/user_stats_model.dart';

/// Server-checked achievements (ARCHITECTURE.md §1.7). Unlocks are written
/// by the backend into `user_stats.achievements`; the client only displays
/// them, with progress where the stats make it computable (GAM-18).
class AchievementDef {
  final String id;
  final IconData icon;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) description;

  /// Progress 0..1 from stats, or null when it cannot be derived.
  final double? Function(UserStats)? progress;

  const AchievementDef({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    this.progress,
  });
}

abstract final class AchievementCatalog {
  static double _ratio(num value, num target) => target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble();

  static final List<AchievementDef> all = [
    AchievementDef(
      id: 'first_lesson',
      icon: Icons.menu_book_outlined,
      title: (l) => l.learnAchFirstLessonTitle,
      description: (l) => l.learnAchFirstLessonDesc,
    ),
    AchievementDef(
      id: 'xp_100',
      icon: Icons.bolt_outlined,
      title: (l) => l.learnAchXp100Title,
      description: (l) => l.learnAchXp100Desc,
      progress: (s) => _ratio(s.xp, 100),
    ),
    AchievementDef(
      id: 'streak_7',
      icon: Icons.local_fire_department_outlined,
      title: (l) => l.learnAchStreak7Title,
      description: (l) => l.learnAchStreak7Desc,
      progress: (s) => _ratio(math.max(s.bestStreak, s.currentStreak), 7),
    ),
    AchievementDef(
      id: 'days_30',
      icon: Icons.calendar_month_outlined,
      title: (l) => l.learnAchDays30Title,
      description: (l) => l.learnAchDays30Desc,
      progress: (s) => _ratio(s.activeDaysTotal, 30),
    ),
    AchievementDef(
      id: 'accuracy_90',
      icon: Icons.track_changes_outlined,
      title: (l) => l.learnAchAccuracy90Title,
      description: (l) => l.learnAchAccuracy90Desc,
      progress: (s) => s.bestExamPercent.isEmpty
          ? 0
          : _ratio(s.bestExamPercent.values.reduce(math.max), 90),
    ),
    AchievementDef(
      id: 'math_expert',
      icon: Icons.calculate_outlined,
      title: (l) => l.learnAchMathExpertTitle,
      description: (l) => l.learnAchMathExpertDesc,
    ),
    AchievementDef(
      id: 'analogies_master',
      icon: Icons.psychology_outlined,
      title: (l) => l.learnAchAnalogiesTitle,
      description: (l) => l.learnAchAnalogiesDesc,
    ),
    AchievementDef(
      id: 'reader',
      icon: Icons.chrome_reader_mode_outlined,
      title: (l) => l.learnAchReaderTitle,
      description: (l) => l.learnAchReaderDesc,
    ),
    AchievementDef(
      id: 'exam_champion',
      icon: Icons.emoji_events_outlined,
      title: (l) => l.learnAchExamChampionTitle,
      description: (l) => l.learnAchExamChampionDesc,
      progress: (s) => _ratio(s.examsCompleted, 10),
    ),
  ];
}
