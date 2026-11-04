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
 * - Study time (`seconds`) is credited at most once per (uid, reportId)
 *   (ARCHITECTURE §9.7): the client creates `reportId` once per event and
 *   keeps it in its offline queue, so a retry after a lost response carries
 *   the same id. The last STUDY_REPORT_IDS_MAX ids live in the server-only
 *   field user_stats.study_report_ids. Without a reportId every call counts
 *   (the §9.6 behaviour).
 */
import { sha256Hex } from './hash';
import { validationError } from './reasons';
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

/** user_stats.study_report_ids keeps the last 50 report ids (ARCHITECTURE §9.7). */
export const STUDY_REPORT_IDS_MAX = 50;
const REPORT_ID_RE = /^[A-Za-z0-9_-]{8,64}$/;

/** Optional recordActivity `reportId`: absent/null -> null, else 8..64 chars [A-Za-z0-9_-] or VALIDATION_FAILED. */
export function parseReportId(raw: unknown): string | null {
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== 'string' || !REPORT_ID_RE.test(raw)) {
    throw validationError('reportId must be 8-64 characters [A-Za-z0-9_-]', { field: 'reportId' });
  }
  return raw;
}

/** Tolerant read of user_stats.study_report_ids (valid ids only, oldest first, at most 50). */
export function storedReportIds(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter((v): v is string => typeof v === 'string' && REPORT_ID_RE.test(v)).slice(-STUDY_REPORT_IDS_MAX);
}

export interface StudyCredit {
  /** Add `seconds` to the study counters. */
  credit: boolean;
  /** New user_stats.study_report_ids to store; null = leave the field unchanged. */
  reportIds: string[] | null;
}

/**
 * Whether a recordActivity call's `seconds` count. Nothing to credit for
 * 0 seconds; a report id already in `stored` is a retry (no time again); a
 * new id is credited and remembered (the oldest ids roll off after 50).
 */
export function decideStudyCredit(seconds: number, reportId: string | null, stored: unknown): StudyCredit {
  if (!(seconds > 0)) return { credit: false, reportIds: null };
  if (reportId === null) return { credit: true, reportIds: null };
  const ids = storedReportIds(stored);
  if (ids.includes(reportId)) return { credit: false, reportIds: null };
  return { credit: true, reportIds: [...ids, reportId].slice(-STUDY_REPORT_IDS_MAX) };
}
