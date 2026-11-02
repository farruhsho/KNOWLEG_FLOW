import 'dart:math' as math;

import '../../core/utils/bishkek_time.dart';
import '../../core/utils/json_read.dart';

/// Server-owned learning stats from `user_stats/{uid}` (ARCHITECTURE.md §1.7).
///
/// Written only by Cloud Functions. The client reads and displays these
/// values and never computes or persists XP, level, streak or achievements.
class UserStats {
  final String uid;
  final int xp;
  final int level;
  final int currentStreak;
  final int bestStreak;
  final String? lastActiveDay; // YYYY-MM-DD, Asia/Bishkek
  final int activeDaysTotal;
  final int todayXp;
  final int dailyGoalXp;
  final int examsCompleted;
  final Map<String, double> bestExamPercent; // direction -> percent
  final Map<String, DateTime?> achievements; // achievement id -> unlocked at
  final DateTime? updatedAt;

  const UserStats({
    required this.uid,
    this.xp = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastActiveDay,
    this.activeDaysTotal = 0,
    this.todayXp = 0,
    this.dailyGoalXp = 50,
    this.examsCompleted = 0,
    this.bestExamPercent = const {},
    this.achievements = const {},
    this.updatedAt,
  });

  /// Stats for a user the server has not written yet (no activity).
  const UserStats.empty(this.uid)
      : xp = 0,
        level = 1,
        currentStreak = 0,
        bestStreak = 0,
        lastActiveDay = null,
        activeDaysTotal = 0,
        todayXp = 0,
        dailyGoalXp = 50,
        examsCompleted = 0,
        bestExamPercent = const {},
        achievements = const {},
        updatedAt = null;

  factory UserStats.fromMap(String uid, Map<String, dynamic> m) {
    final xp = math.max(0, JsonRead.intOr(m, ['xp', 'total_xp'], 0));
    final best = JsonRead.map(m, ['best_exam_percent']) ?? const {};
    final ach = JsonRead.map(m, ['achievements']) ?? const {};
    return UserStats(
      uid: uid,
      xp: xp,
      level: JsonRead.integer(m, ['level']) ?? levelForXp(xp),
      currentStreak: JsonRead.intOr(m, ['current_streak'], 0),
      bestStreak: JsonRead.intOr(m, ['best_streak'], 0),
      lastActiveDay: JsonRead.string(m, ['last_active_day']),
      activeDaysTotal: JsonRead.intOr(m, ['active_days_total'], 0),
      todayXp: JsonRead.intOr(m, ['today_xp'], 0),
      dailyGoalXp: JsonRead.intOr(m, ['daily_goal_xp'], 50),
      examsCompleted: JsonRead.intOr(m, ['exams_completed'], 0),
      bestExamPercent: {
        for (final e in best.entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      },
      achievements: {
        for (final e in ach.entries)
          if (e.value != null && e.value != false) e.key: JsonRead.toDate(e.value),
      },
      updatedAt: JsonRead.date(m, ['updated_at']),
    );
  }

  /// `level = floor(sqrt(xp / 50)) + 1` (ARCHITECTURE.md §1.7). Display only.
  static int levelForXp(int xp) => (math.sqrt(math.max(0, xp) / 50)).floor() + 1;

  /// Total XP at which [level] starts.
  static int xpForLevelStart(int level) {
    final l = math.max(1, level) - 1;
    return 50 * l * l;
  }

  /// XP earned inside the current level and the size of the level.
  ({int inLevel, int levelSize}) get levelProgress {
    final start = xpForLevelStart(level);
    final next = xpForLevelStart(level + 1);
    final size = math.max(1, next - start);
    return (inLevel: (xp - start).clamp(0, size), levelSize: size);
  }

  /// Streak as it should read today (0 once a day has been missed).
  int liveStreak(DateTime now) => BishkekTime.liveStreak(
        lastActiveDay: lastActiveDay,
        currentStreak: currentStreak,
        now: now,
      );

  /// Today's XP, or 0 when the stored value belongs to an earlier day.
  int todayXpAt(DateTime now) =>
      lastActiveDay == BishkekTime.dayKey(now) ? todayXp : 0;

  bool hasAchievement(String id) => achievements.containsKey(id);
}
