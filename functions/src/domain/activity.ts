/**
 * recordActivity rules (ARCHITECTURE §1.7, decision D10). Pure helpers: the
 * handler persists the award in one transaction.
 *
 * - Event ids are namespaced per kind, and per Bishkek day for practice, so
 *   one lesson is awarded once ever and a practice refId at most once a day.
 * - Practice XP is capped per day (xp.ts). Once the cap is reached the award
 *   is 0 and NOTHING is written (no xp_events doc, no user_stats write), so
 *   inventing refIds beyond the cap costs the client a call and earns nothing.
 * - Lessons are validated against `lessons/{id}`. Legacy `daily_lessons/{day}`
 *   pointer docs are resolved to the lesson they point at, so both ids dedupe
 *   to the same award.
 */
import { sha256Hex } from './hash';
import { bishkekDayKey } from './time';
import { isRecord, num } from './types';

export type ActivityKind = 'lesson_completed' | 'practice_answered';

export function isActivityKind(v: unknown): v is ActivityKind {
  return v === 'lesson_completed' || v === 'practice_answered';
}

/** Number of correct practice answers reported by the payload. */
export function practiceCorrectCount(correct: unknown, count: unknown): number {
  if (correct === false) return 0;
  if (typeof correct === 'number') return Math.max(0, Math.min(50, Math.trunc(correct)));
  const n = count === undefined || count === null ? 1 : Math.trunc(num(count, 1));
  return Math.max(0, Math.min(50, n));
}

/** xp_events id: `lesson_{hash(lessonId)}` or `practice_{day}_{hash(refId)}`. */
export function activityEventId(kind: ActivityKind, refId: string, nowMs: number): string {
  const refHash = sha256Hex(refId).slice(0, 40);
  return kind === 'lesson_completed' ? `lesson_${refHash}` : `practice_${bishkekDayKey(nowMs)}_${refHash}`;
}

/** Lesson id a `daily_lessons/{day}` document points at (`lesson_id` / `lessonId`). */
export function dailyLessonTarget(data: unknown): string | null {
  if (!isRecord(data)) return null;
  const v = data['lesson_id'] ?? data['lessonId'];
  return typeof v === 'string' && /^[^/\s]{1,150}$/.test(v) ? v : null;
}

/** True when an award must be persisted (D10: a 0 award writes nothing). */
export function shouldPersistAward(total: number): boolean {
  return total > 0;
}
