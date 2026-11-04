import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { bishkekDayKey, dayDiff, isoWeekId, subjectWeeklyBoardId, weeklyBoardId } from '../src/domain/time';
import {
  applyExamCompletion,
  applyLessonCompleted,
  applyPracticeCorrect,
  applyXp,
  emptyStats,
  examXp,
  levelForXp,
  parseStats,
  XP_RULES,
} from '../src/domain/xp';
import { bishkek } from './fixtures';

describe('Bishkek calendar', () => {
  it('day key flips at Bishkek midnight (UTC 18:00), not UTC midnight', () => {
    assert.equal(bishkekDayKey(Date.UTC(2026, 10, 1, 17, 59, 59)), '2026-11-01');
    assert.equal(bishkekDayKey(Date.UTC(2026, 10, 1, 18, 0, 0)), '2026-11-02');
    assert.equal(bishkekDayKey(bishkek(2026, 11, 2, 0, 30)), '2026-11-02');
  });

  it('dayDiff counts calendar days across months and years', () => {
    assert.equal(dayDiff('2026-12-31', '2027-01-01'), 1);
    assert.equal(dayDiff('2026-11-02', '2026-11-02'), 0);
    assert.equal(dayDiff('2026-11-05', '2026-11-02'), -3);
  });

  it('ISO week ids (Bishkek-based) for leaderboards', () => {
    assert.equal(isoWeekId(bishkek(2026, 11, 2, 12)), '2026-W45');
    assert.equal(isoWeekId(bishkek(2027, 1, 1, 12)), '2026-W53');
    assert.equal(isoWeekId(bishkek(2026, 1, 1, 12)), '2026-W01');
    // Sunday 23:30 Bishkek is still the old week even though UTC is earlier.
    assert.equal(isoWeekId(bishkek(2026, 11, 8, 23, 30)), '2026-W45');
    assert.equal(isoWeekId(bishkek(2026, 11, 9, 0, 10)), '2026-W46');
    assert.equal(weeklyBoardId(bishkek(2026, 11, 2, 12)), 'weekly_2026-W45');
    assert.equal(subjectWeeklyBoardId('chemistry', bishkek(2026, 11, 2, 12)), 'subject_chemistry_weekly_2026-W45');
  });
});

describe('XP rules', () => {
  it('level = floor(sqrt(xp / 50)) + 1', () => {
    assert.equal(levelForXp(0), 1);
    assert.equal(levelForXp(49), 1);
    assert.equal(levelForXp(50), 2);
    assert.equal(levelForXp(199), 2);
    assert.equal(levelForXp(200), 3);
    assert.equal(levelForXp(1240), 5);
  });

  it('exam XP = 100 + 1 per correct, capped at 250', () => {
    assert.equal(examXp(0), 100);
    assert.equal(examXp(97), 197);
    assert.equal(examXp(150), 250);
  });

  it('awards the +50 improvement bonus only when a previous best existed and improved', () => {
    const t = bishkek(2026, 11, 2, 10);
    const first = applyExamCompletion(emptyStats(), { direction: 'ort_main', correct: 90, percent: 60, sectionPercents: {}, nowMs: t });
    assert.equal(first.improvedBonus, 0);
    assert.equal(first.baseXp, 190);
    const second = applyExamCompletion(first.stats, { direction: 'ort_main', correct: 100, percent: 66.7, sectionPercents: {}, nowMs: t + 3600_000 });
    assert.equal(second.improvedBonus, 50);
    assert.equal(second.stats.best_exam_percent['ort_main'], 66.7);
    const worse = applyExamCompletion(second.stats, { direction: 'ort_main', correct: 10, percent: 6.7, sectionPercents: {}, nowMs: t + 7200_000 });
    assert.equal(worse.improvedBonus, 0);
    assert.equal(worse.stats.best_exam_percent['ort_main'], 66.7);
  });

  it('caps practice XP at 200 per Bishkek day and resets after midnight', () => {
    const evening = bishkek(2026, 11, 2, 23, 50);
    let s = emptyStats();
    let total = 0;
    for (let i = 0; i < 12; i++) {
      const a = applyPracticeCorrect(s, 10, evening);
      total += a.awarded;
      s = a.stats;
    }
    assert.equal(total, XP_RULES.PRACTICE_DAILY_CAP);
    const afterMidnight = applyPracticeCorrect(s, 10, bishkek(2026, 11, 3, 0, 5));
    assert.equal(afterMidnight.awarded, 20);
    assert.equal(afterMidnight.stats.today_practice_xp, 20);
  });

  it('daily goal bonus is added once per day', () => {
    const t = bishkek(2026, 11, 2, 9);
    const a = applyXp(emptyStats(), 'lesson', 60, t);
    assert.equal(a.dailyGoalBonus, XP_RULES.DAILY_GOAL_BONUS);
    const b = applyXp(a.stats, 'lesson', 60, t + 60_000);
    assert.equal(b.dailyGoalBonus, 0);
    const nextDay = applyXp(b.stats, 'lesson', 60, bishkek(2026, 11, 3, 9));
    assert.equal(nextDay.dailyGoalBonus, XP_RULES.DAILY_GOAL_BONUS);
  });
});

describe('streaks across Bishkek midnight', () => {
  it('two events 20 minutes apart around Bishkek midnight make a 2-day streak', () => {
    const a = applyLessonCompleted(emptyStats(), bishkek(2026, 11, 2, 23, 50));
    assert.equal(a.stats.current_streak, 1);
    const b = applyLessonCompleted(a.stats, bishkek(2026, 11, 3, 0, 10));
    assert.equal(b.stats.current_streak, 2);
    assert.equal(b.stats.active_days_total, 2);
    assert.equal(b.stats.last_active_day, '2026-11-03');
  });

  it('events on the same Bishkek day across UTC midnight do not extend the streak', () => {
    // 05:00 and 07:00 Bishkek are on different UTC days (23:00 / 01:00 UTC).
    const a = applyLessonCompleted(emptyStats(), bishkek(2026, 11, 2, 5));
    const b = applyLessonCompleted(a.stats, bishkek(2026, 11, 2, 7));
    assert.equal(b.stats.current_streak, 1);
    assert.equal(b.stats.active_days_total, 1);
  });

  it('a missed day resets the streak; best streak is kept', () => {
    let s = emptyStats();
    for (let d = 1; d <= 3; d++) s = applyLessonCompleted(s, bishkek(2026, 11, d, 12)).stats;
    assert.equal(s.current_streak, 3);
    s = applyLessonCompleted(s, bishkek(2026, 11, 5, 12)).stats;
    assert.equal(s.current_streak, 1);
    assert.equal(s.best_streak, 3);
  });

  it('zero-XP events (practice cap reached) do not count as an active day', () => {
    const s = { ...emptyStats(), last_active_day: '2026-11-01', current_streak: 4, today_practice_xp: 0 };
    const capped = applyPracticeCorrect(s, 0, bishkek(2026, 11, 2, 12));
    assert.equal(capped.stats.current_streak, 4);
    assert.equal(capped.stats.last_active_day, '2026-11-01');
  });
});

describe('achievements', () => {
  it('unlocks first_lesson, xp_100 and exam achievements once', () => {
    const t = bishkek(2026, 11, 2, 12);
    const lesson = applyLessonCompleted(emptyStats(), t);
    assert.ok(lesson.newAchievements.includes('first_lesson'));
    const exam = applyExamCompletion(lesson.stats, { direction: 'ort_main', correct: 140, percent: 93.3, sectionPercents: { math: 95 }, nowMs: t });
    assert.ok(exam.newAchievements.includes('xp_100'));
    assert.ok(exam.newAchievements.includes('accuracy_90'));
    assert.ok(!exam.newAchievements.includes('math_expert'));
    const again = applyLessonCompleted(exam.stats, t + 1000);
    assert.deepEqual(again.newAchievements, []);
  });

  it('math_expert needs three exams with math >= 90%', () => {
    let s = emptyStats();
    const t = bishkek(2026, 11, 2, 12);
    let unlocked: string[] = [];
    for (let i = 0; i < 3; i++) {
      const r = applyExamCompletion(s, { direction: 'ort_main', correct: 50, percent: 50, sectionPercents: { math: 91 }, nowMs: t + i });
      s = r.stats;
      unlocked = unlocked.concat(r.newAchievements);
    }
    assert.ok(unlocked.includes('math_expert'));
    assert.equal(s.section_90_counts['math'], 3);
  });

  it('streak_7 after seven consecutive Bishkek days', () => {
    let s = emptyStats();
    let unlocked: string[] = [];
    for (let d = 1; d <= 7; d++) {
      const r = applyLessonCompleted(s, bishkek(2026, 11, d, 22));
      s = r.stats;
      unlocked = unlocked.concat(r.newAchievements);
    }
    assert.ok(unlocked.includes('streak_7'));
  });
});

describe('parseStats', () => {
  it('tolerates missing fields and Timestamp-like achievements', () => {
    const s = parseStats({ xp: 250, achievements: { first_lesson: { toMillis: () => 5 } }, last_active_day: 'garbage' });
    assert.equal(s.level, 3);
    assert.equal(s.achievements['first_lesson'], 5);
    assert.equal(s.last_active_day, null);
    assert.equal(s.daily_goal_xp, 50);
  });
});
