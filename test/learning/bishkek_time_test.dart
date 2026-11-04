import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/utils/bishkek_time.dart';

void main() {
  group('BishkekTime.dayKey (GAM-05)', () {
    test('Bishkek midnight is 18:00 UTC of the previous day', () {
      expect(BishkekTime.dayKey(DateTime.utc(2026, 11, 2, 17, 59)), '2026-11-02');
      expect(BishkekTime.dayKey(DateTime.utc(2026, 11, 2, 18, 0)), '2026-11-03');
    });

    test('independent of the device time zone (uses the instant)', () {
      final instant = DateTime.utc(2026, 1, 31, 20, 30);
      expect(BishkekTime.dayKey(instant), '2026-02-01');
      expect(BishkekTime.dayKey(instant.toLocal()), '2026-02-01');
    });

    test('previous day and day numbers', () {
      final t = DateTime.utc(2026, 3, 1, 3); // 09:00 in Bishkek
      expect(BishkekTime.previousDayKey(t), '2026-02-28');
      expect(BishkekTime.dayNumber(t) - BishkekTime.dayNumber(t.subtract(const Duration(days: 1))), 1);
      // Same Bishkek day, different UTC dates.
      expect(
        BishkekTime.dayNumber(DateTime.utc(2026, 3, 1, 18, 30)),
        BishkekTime.dayNumber(DateTime.utc(2026, 3, 2, 17, 0)),
      );
    });
  });

  group('ISO week and leaderboard ids', () {
    test('weekly board id format', () {
      // Mon 2 Nov 2026 is in ISO week 45.
      expect(BishkekTime.isoWeekKey(DateTime.utc(2026, 11, 2, 6)), '2026-W45');
      expect(BishkekTime.weeklyBoardId(DateTime.utc(2026, 11, 2, 6)), 'weekly_2026-W45');
      expect(BishkekTime.subjectWeeklyBoardId('math', DateTime.utc(2026, 11, 2, 6)),
          'subject_math_weekly_2026-W45');
      expect(BishkekTime.allTimeBoardId, 'all_time');
    });

    test('week starts on Monday in Bishkek time', () {
      // Sunday 8 Nov 2026 17:59 UTC = Sun 23:59 Bishkek -> still W45.
      expect(BishkekTime.isoWeekKey(DateTime.utc(2026, 11, 8, 17, 59)), '2026-W45');
      // Sunday 8 Nov 2026 18:00 UTC = Mon 00:00 Bishkek -> W46.
      expect(BishkekTime.isoWeekKey(DateTime.utc(2026, 11, 8, 18, 0)), '2026-W46');
    });

    test('ISO year boundaries', () {
      // 1 Jan 2026 is a Thursday -> week 1 of 2026.
      expect(BishkekTime.isoWeekKey(DateTime.utc(2026, 1, 1, 6)), '2026-W01');
      // 1 Jan 2027 is a Friday -> belongs to 2026-W53.
      expect(BishkekTime.isoWeekKey(DateTime.utc(2027, 1, 1, 6)), '2026-W53');
      // 31 Dec 2024 (Tuesday) -> 2025-W01.
      expect(BishkekTime.isoWeekKey(DateTime.utc(2024, 12, 31, 6)), '2025-W01');
    });
  });

  group('liveStreak (display only)', () {
    final now = DateTime.utc(2026, 11, 2, 6); // 12:00 Bishkek, 2 Nov
    test('active today or yesterday keeps the streak', () {
      expect(BishkekTime.liveStreak(lastActiveDay: '2026-11-02', currentStreak: 4, now: now), 4);
      expect(BishkekTime.liveStreak(lastActiveDay: '2026-11-01', currentStreak: 4, now: now), 4);
    });
    test('a missed day reads as 0', () {
      expect(BishkekTime.liveStreak(lastActiveDay: '2026-10-31', currentStreak: 4, now: now), 0);
      expect(BishkekTime.liveStreak(lastActiveDay: null, currentStreak: 4, now: now), 0);
    });
  });
}
