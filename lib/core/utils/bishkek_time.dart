/// Calendar helpers pinned to Asia/Bishkek.
///
/// Kyrgyzstan has used UTC+6 all year round since 2005 (no DST), so a fixed
/// offset is exact and avoids pulling in a timezone database. Every day key,
/// streak and weekly leaderboard id in the app must go through these helpers
/// so the client agrees with the server (ARCHITECTURE.md §1.7: "граница дня —
/// полночь по Бишкеку").
abstract final class BishkekTime {
  static const Duration offset = Duration(hours: 6);

  /// Wall-clock fields (year/month/day/hour…) of [instant] in Bishkek.
  /// The returned value is a UTC [DateTime] whose fields read as Bishkek
  /// local time; do not convert it back with toLocal().
  static DateTime wallClock(DateTime instant) => instant.toUtc().add(offset);

  /// `YYYY-MM-DD` for the Bishkek calendar day containing [instant]. Matches
  /// `user_stats.last_active_day` written by the backend.
  static String dayKey(DateTime instant) {
    final w = wallClock(instant);
    return '${_pad(w.year, 4)}-${_pad(w.month)}-${_pad(w.day)}';
  }

  /// Day key of the Bishkek day before the one containing [instant].
  static String previousDayKey(DateTime instant) =>
      dayKey(instant.subtract(const Duration(days: 1)));

  /// Whole days since 1970-01-01 in the Bishkek calendar. Stable, monotonic
  /// and identical on every device — used for deterministic daily picks.
  static int dayNumber(DateTime instant) {
    final w = wallClock(instant);
    return DateTime.utc(w.year, w.month, w.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  /// ISO-8601 week (Monday-based, week 1 contains the year's first Thursday)
  /// of the Bishkek calendar day containing [instant].
  static ({int year, int week}) isoWeek(DateTime instant) {
    final w = wallClock(instant);
    final date = DateTime.utc(w.year, w.month, w.day);
    // Thursday of this ISO week decides the ISO year.
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final jan1 = DateTime.utc(thursday.year, 1, 1);
    final dayOfYear = thursday.difference(jan1).inDays; // 0-based
    return (year: thursday.year, week: dayOfYear ~/ 7 + 1);
  }

  /// `YYYY-Www`, e.g. `2026-W45`.
  static String isoWeekKey(DateTime instant) {
    final w = isoWeek(instant);
    return '${_pad(w.year, 4)}-W${_pad(w.week)}';
  }

  /// Leaderboard ids (ARCHITECTURE.md §1.7).
  static String weeklyBoardId(DateTime instant) =>
      'weekly_${isoWeekKey(instant)}';
  static String subjectWeeklyBoardId(String subjectId, DateTime instant) =>
      'subject_${subjectId}_weekly_${isoWeekKey(instant)}';
  static const String allTimeBoardId = 'all_time';

  /// Streak that is still alive at [now]: the server stores the streak as of
  /// [lastActiveDay]; if the student was last active today or yesterday the
  /// streak is still running, otherwise it has lapsed and reads as 0 until
  /// the server records new activity. Purely a display helper — the client
  /// never writes streaks.
  static int liveStreak({
    required String? lastActiveDay,
    required int currentStreak,
    required DateTime now,
  }) {
    if (lastActiveDay == null || currentStreak <= 0) return 0;
    if (lastActiveDay == dayKey(now) || lastActiveDay == previousDayKey(now)) {
      return currentStreak;
    }
    return 0;
  }

  static String _pad(int v, [int width = 2]) => v.toString().padLeft(width, '0');
}
