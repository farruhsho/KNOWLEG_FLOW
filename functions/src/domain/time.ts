/**
 * Calendar helpers anchored to Asia/Bishkek. Kyrgyzstan has used a fixed
 * UTC+6 offset with no daylight saving since 2005, so a constant offset is
 * exact and keeps these functions deterministic (no ICU / tz database).
 */
export const BISHKEK_OFFSET_MS = 6 * 60 * 60 * 1000;
export const DAY_MS = 24 * 60 * 60 * 1000;

function shifted(ms: number): Date {
  return new Date(ms + BISHKEK_OFFSET_MS);
}

function pad(n: number, width = 2): string {
  return String(n).padStart(width, '0');
}

/** `YYYY-MM-DD` of the Bishkek calendar day containing the instant `ms`. */
export function bishkekDayKey(ms: number): string {
  const d = shifted(ms);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

const DAY_KEY_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

export function isDayKey(value: unknown): value is string {
  return typeof value === 'string' && DAY_KEY_RE.test(value);
}

function dayKeyToUtcDays(key: string): number {
  const m = DAY_KEY_RE.exec(key);
  if (!m) throw new Error(`bad day key: ${key}`);
  return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])) / DAY_MS;
}

/** Whole calendar days from `from` to `to` (positive when `to` is later). */
export function dayDiff(from: string, to: string): number {
  return Math.round(dayKeyToUtcDays(to) - dayKeyToUtcDays(from));
}

/** ISO-8601 week id `YYYY-Www` of the Bishkek calendar day containing `ms`. */
export function isoWeekId(ms: number): string {
  const s = shifted(ms);
  const d = new Date(Date.UTC(s.getUTCFullYear(), s.getUTCMonth(), s.getUTCDate()));
  const dayNum = d.getUTCDay() === 0 ? 7 : d.getUTCDay();
  // Move to the Thursday of this ISO week; its year is the ISO year.
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const isoYear = d.getUTCFullYear();
  const yearStart = Date.UTC(isoYear, 0, 1);
  const week = Math.ceil(((d.getTime() - yearStart) / DAY_MS + 1) / 7);
  return `${isoYear}-W${pad(week)}`;
}

/** Leaderboard board ids from ARCHITECTURE §1.7. */
export function weeklyBoardId(ms: number): string {
  return `weekly_${isoWeekId(ms)}`;
}

export const ALL_TIME_BOARD_ID = 'all_time';

export function subjectWeeklyBoardId(subjectId: string, ms: number): string {
  return `subject_${subjectId}_weekly_${isoWeekId(ms)}`;
}
