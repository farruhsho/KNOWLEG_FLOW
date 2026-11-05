/**
 * Server-authoritative XP, level, streak and achievement rules
 * (ARCHITECTURE §1.7). Every function is pure; the handlers persist the
 * returned state together with an `xp_events/{uid}/events/{eventId}` doc in
 * one transaction, which makes each award idempotent.
 */
import { bishkekDayKey, dayDiff, isDayKey } from './time';
import { int, isRecord, num, strOrNull } from './types';

export const XP_RULES = Object.freeze({
  EXAM_BASE: 100,
  EXAM_PER_CORRECT: 1,
  EXAM_CAP: 250,
  BEST_IMPROVED_BONUS: 50,
  LESSON_COMPLETED: 20,
  PRACTICE_CORRECT: 2,
  PRACTICE_DAILY_CAP: 200,
  DAILY_GOAL_BONUS: 10,
  DEFAULT_DAILY_GOAL: 50,
  /** recordActivity study time: ≤ 3600 s per call, ≤ 24 h per Bishkek day. */
  STUDY_SECONDS_PER_CALL: 3600,
  STUDY_SECONDS_DAILY_CAP: 86_400,
});

/** Sections whose >= 90% results count toward section achievements. */
export const SECTION_ACHIEVEMENTS: Readonly<Record<string, { id: AchievementId; needed: number }>> = Object.freeze({
  math: { id: 'math_expert', needed: 3 },
  verbal: { id: 'analogies_master', needed: 3 },
  reading: { id: 'reader', needed: 3 },
});

export type AchievementId =
  | 'first_lesson'
  | 'xp_100'
  | 'streak_7'
  | 'days_30'
  | 'accuracy_90'
  | 'math_expert'
  | 'analogies_master'
  | 'reader'
  | 'exam_champion';

export const ALL_ACHIEVEMENTS: readonly AchievementId[] = [
  'first_lesson',
  'xp_100',
  'streak_7',
  'days_30',
  'accuracy_90',
  'math_expert',
  'analogies_master',
  'reader',
  'exam_champion',
];

export interface UserStats {
  xp: number;
  level: number;
  current_streak: number;
  best_streak: number;
  /** Bishkek day key of the last day with XP; today_* counters refer to it. */
  last_active_day: string | null;
  active_days_total: number;
  today_xp: number;
  today_practice_xp: number;
  daily_goal_xp: number;
  daily_goal_awarded_day: string | null;
  exams_completed: number;
  lessons_completed: number;
  best_exam_percent: Record<string, number>;
  section_90_counts: Record<string, number>;
  /** achievement id -> unlock time (ms). */
  achievements: Record<string, number>;
  /** Study time reported with recordActivity (ARCHITECTURE §9.5). */
  study_seconds_total: number;
  /** Seconds on `study_day` (Bishkek); reset when the day changes. */
  study_seconds_today: number;
  study_day: string | null;
}

export function emptyStats(): UserStats {
  return {
    xp: 0,
    level: 1,
    current_streak: 0,
    best_streak: 0,
    last_active_day: null,
    active_days_total: 0,
    today_xp: 0,
    today_practice_xp: 0,
    daily_goal_xp: XP_RULES.DEFAULT_DAILY_GOAL,
    daily_goal_awarded_day: null,
    exams_completed: 0,
    lessons_completed: 0,
    best_exam_percent: {},
    section_90_counts: {},
    achievements: {},
    study_seconds_total: 0,
    study_seconds_today: 0,
    study_day: null,
  };
}

function numMap(v: unknown): Record<string, number> {
  const out: Record<string, number> = {};
  if (!isRecord(v)) return out;
  for (const [k, val] of Object.entries(v)) {
    if (typeof val === 'number' && Number.isFinite(val)) out[k] = val;
    else if (isRecord(val) && typeof (val as { toMillis?: unknown }).toMillis === 'function') {
      out[k] = (val as { toMillis: () => number }).toMillis();
    }
  }
  return out;
}

/** Tolerant parse of a user_stats document (missing fields default). */
export function parseStats(raw: unknown): UserStats {
  const base = emptyStats();
  if (!isRecord(raw)) return base;
  const last = strOrNull(raw['last_active_day']);
  const goalDay = strOrNull(raw['daily_goal_awarded_day']);
  const studyDay = strOrNull(raw['study_day']);
  const xp = Math.max(0, int(raw['xp']));
  return {
    xp,
    level: levelForXp(xp),
    current_streak: Math.max(0, int(raw['current_streak'])),
    best_streak: Math.max(0, int(raw['best_streak'])),
    last_active_day: isDayKey(last) ? last : null,
    active_days_total: Math.max(0, int(raw['active_days_total'])),
    today_xp: Math.max(0, int(raw['today_xp'])),
    today_practice_xp: Math.max(0, int(raw['today_practice_xp'])),
    daily_goal_xp: Math.max(1, int(raw['daily_goal_xp'], XP_RULES.DEFAULT_DAILY_GOAL)),
    daily_goal_awarded_day: isDayKey(goalDay) ? goalDay : null,
    exams_completed: Math.max(0, int(raw['exams_completed'])),
    lessons_completed: Math.max(0, int(raw['lessons_completed'])),
    best_exam_percent: numMap(raw['best_exam_percent']),
    section_90_counts: numMap(raw['section_90_counts']),
    achievements: numMap(raw['achievements']),
    study_seconds_total: Math.max(0, int(raw['study_seconds_total'])),
    study_seconds_today: Math.max(0, int(raw['study_seconds_today'])),
    study_day: isDayKey(studyDay) ? studyDay : null,
  };
}

/** level = floor(sqrt(xp / 50)) + 1 */
export function levelForXp(xp: number): number {
  return Math.floor(Math.sqrt(Math.max(0, xp) / 50)) + 1;
}

/** 100 + 1 per correct answer, at most 250 in total. */
export function examXp(correct: number): number {
  const c = Math.max(0, Math.trunc(num(correct)));
  return Math.min(XP_RULES.EXAM_CAP, XP_RULES.EXAM_BASE + c * XP_RULES.EXAM_PER_CORRECT);
}

export type XpKind = 'exam' | 'lesson' | 'practice';

export interface XpAward {
  stats: UserStats;
  /** XP actually added for the event itself (after caps). */
  awarded: number;
  /** Daily-goal bonus added by this event (0 or DAILY_GOAL_BONUS). */
  dailyGoalBonus: number;
  /** awarded + dailyGoalBonus */
  total: number;
  newAchievements: AchievementId[];
}

function cloneStats(s: UserStats): UserStats {
  return {
    ...s,
    best_exam_percent: { ...s.best_exam_percent },
    section_90_counts: { ...s.section_90_counts },
    achievements: { ...s.achievements },
  };
}

/** Rolls the "today" counters over when the Bishkek day changed. */
function rollDay(s: UserStats, today: string): void {
  if (s.last_active_day !== today) {
    s.today_xp = 0;
    s.today_practice_xp = 0;
  }
}

/** Updates streak/active days for a day on which XP was earned. */
function markActive(s: UserStats, today: string): void {
  const last = s.last_active_day;
  if (last === today) return;
  if (last === null) {
    s.current_streak = 1;
  } else {
    const diff = dayDiff(last, today);
    if (diff < 0) return; // out-of-order event; never rewind the streak
    s.current_streak = diff === 1 ? s.current_streak + 1 : 1;
  }
  s.best_streak = Math.max(s.best_streak, s.current_streak);
  s.active_days_total += 1;
  s.last_active_day = today;
}

export function evaluateAchievements(s: UserStats, nowMs: number): AchievementId[] {
  const unlocked: AchievementId[] = [];
  const bestPercent = Math.max(0, ...Object.values(s.best_exam_percent));
  const checks: Record<AchievementId, boolean> = {
    first_lesson: s.lessons_completed >= 1,
    xp_100: s.xp >= 100,
    streak_7: s.best_streak >= 7,
    days_30: s.active_days_total >= 30,
    accuracy_90: bestPercent >= 90,
    math_expert: (s.section_90_counts['math'] ?? 0) >= SECTION_ACHIEVEMENTS['math']!.needed,
    analogies_master: (s.section_90_counts['verbal'] ?? 0) >= SECTION_ACHIEVEMENTS['verbal']!.needed,
    reader: (s.section_90_counts['reading'] ?? 0) >= SECTION_ACHIEVEMENTS['reading']!.needed,
    exam_champion: s.exams_completed >= 10,
  };
  for (const id of ALL_ACHIEVEMENTS) {
    if (checks[id] && s.achievements[id] === undefined) {
      s.achievements[id] = nowMs;
      unlocked.push(id);
    }
  }
  return unlocked;
}

/**
 * Applies `amount` XP of `kind` at `nowMs`. Practice XP is capped per
 * Bishkek day; the daily-goal bonus is added once per day; the streak only
 * advances on days where XP > 0 was earned.
 */
export function applyXp(stats: UserStats, kind: XpKind, amount: number, nowMs: number): XpAward {
  const s = cloneStats(stats);
  const today = bishkekDayKey(nowMs);
  rollDay(s, today);
  let awarded = Math.max(0, Math.trunc(amount));
  if (kind === 'practice') {
    awarded = Math.max(0, Math.min(awarded, XP_RULES.PRACTICE_DAILY_CAP - s.today_practice_xp));
    s.today_practice_xp += awarded;
  }
  let dailyGoalBonus = 0;
  if (awarded > 0) {
    markActive(s, today);
    s.xp += awarded;
    s.today_xp += awarded;
    if (s.today_xp >= s.daily_goal_xp && s.daily_goal_awarded_day !== today) {
      dailyGoalBonus = XP_RULES.DAILY_GOAL_BONUS;
      s.daily_goal_awarded_day = today;
      s.xp += dailyGoalBonus;
      s.today_xp += dailyGoalBonus;
    }
  }
  s.level = levelForXp(s.xp);
  const newAchievements = evaluateAchievements(s, nowMs);
  return { stats: s, awarded, dailyGoalBonus, total: awarded + dailyGoalBonus, newAchievements };
}

export interface ExamCompletionInput {
  /** directionKey(blueprintId), e.g. "ort_main". */
  direction: string;
  correct: number;
  percent: number;
  sectionPercents: Record<string, number>;
  nowMs: number;
}

export interface ExamCompletionAward extends XpAward {
  baseXp: number;
  improvedBonus: number;
}

/**
 * XP for a completed exam: 100 + 1/correct (cap 250), +50 if the best
 * percent for the direction improved (only when a previous best existed).
 */
export function applyExamCompletion(stats: UserStats, input: ExamCompletionInput): ExamCompletionAward {
  const s = cloneStats(stats);
  const baseXp = examXp(input.correct);
  const prevBest = s.best_exam_percent[input.direction];
  const improvedBonus = prevBest !== undefined && input.percent > prevBest ? XP_RULES.BEST_IMPROVED_BONUS : 0;
  if (prevBest === undefined || input.percent > prevBest) s.best_exam_percent[input.direction] = input.percent;
  s.exams_completed += 1;
  for (const [sectionId, pct] of Object.entries(input.sectionPercents)) {
    if (SECTION_ACHIEVEMENTS[sectionId] && pct >= 90) {
      s.section_90_counts[sectionId] = (s.section_90_counts[sectionId] ?? 0) + 1;
    }
  }
  const award = applyXp(s, 'exam', baseXp + improvedBonus, input.nowMs);
  return { ...award, baseXp, improvedBonus };
}

/** XP for a completed lesson (idempotency per lesson is the caller's job). */
export function applyLessonCompleted(stats: UserStats, nowMs: number): XpAward {
  const s = cloneStats(stats);
  s.lessons_completed += 1;
  return applyXp(s, 'lesson', XP_RULES.LESSON_COMPLETED, nowMs);
}

/** XP for `correctCount` correct practice answers (2 each, daily cap 200). */
export function applyPracticeCorrect(stats: UserStats, correctCount: number, nowMs: number): XpAward {
  const n = Math.max(0, Math.min(100, Math.trunc(correctCount)));
  return applyXp(stats, 'practice', n * XP_RULES.PRACTICE_CORRECT, nowMs);
}

/**
 * Adds study time reported by recordActivity (`seconds`, 0..3600). The
 * today counter resets on a new Bishkek day and is capped at 24 h; the total
 * grows by what was accepted. Independent of XP (a 0-XP call still counts
 * study time).
 */
export function applyStudySeconds(stats: UserStats, seconds: number, nowMs: number): { stats: UserStats; added: number } {
  const s = cloneStats(stats);
  const today = bishkekDayKey(nowMs);
  if (s.study_day !== today) {
    s.study_day = today;
    s.study_seconds_today = 0;
  }
  const want = Math.max(0, Math.min(XP_RULES.STUDY_SECONDS_PER_CALL, Math.trunc(num(seconds))));
  const added = Math.max(0, Math.min(want, XP_RULES.STUDY_SECONDS_DAILY_CAP - s.study_seconds_today));
  s.study_seconds_today += added;
  s.study_seconds_total += added;
  return { stats: s, added };
}

/** Plain JSON view of stats for callable responses. */
export function statsView(s: UserStats): Record<string, unknown> {
  return {
    xp: s.xp,
    level: s.level,
    current_streak: s.current_streak,
    best_streak: s.best_streak,
    last_active_day: s.last_active_day,
    active_days_total: s.active_days_total,
    today_xp: s.today_xp,
    daily_goal_xp: s.daily_goal_xp,
    exams_completed: s.exams_completed,
    lessons_completed: s.lessons_completed,
    best_exam_percent: s.best_exam_percent,
    achievements: Object.keys(s.achievements),
    study_seconds_total: s.study_seconds_total,
    study_seconds_today: s.study_seconds_today,
    study_day: s.study_day,
  };
}
