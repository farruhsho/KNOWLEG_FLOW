/**
 * Extended analytics (ARCHITECTURE §9.5). Pure.
 *
 * - examSubmitSection accepts `timings: {questionId: seconds}`: only
 *   questions of the section being submitted, numbers rounded to whole
 *   seconds in [0, section duration]; anything else is dropped (a bad timing
 *   never blocks a section submit). Stored in answers/{sectionId}.timings.
 * - ExamResult.topic_time_avg = mean seconds per topic over the timed
 *   questions; slow_topics = topics whose mean exceeds SLOW_FACTOR × the
 *   median per-question time of the whole attempt (sorted slowest first).
 * - recordActivity `seconds` (0..3600) feed user_stats study time (xp.ts).
 */
import { validationError } from './reasons';
import { round1 } from './scoring';
import { isRecord } from './types';

export const SLOW_FACTOR = 1.5;
export const MAX_ACTIVITY_SECONDS = 3600;

/**
 * Validated timings for one section. `raw` undefined/null -> {}; a
 * non-object -> VALIDATION_FAILED; invalid entries are dropped.
 */
export function sanitizeTimings(raw: unknown, questionIds: readonly string[], maxSec: number): Record<string, number> {
  if (raw === undefined || raw === null) return {};
  if (!isRecord(raw)) throw validationError('timings must be an object {questionId: seconds}', { field: 'timings' });
  const allowed = new Set(questionIds);
  const limit = Math.max(0, Math.floor(maxSec));
  const out: Record<string, number> = {};
  for (const [qid, v] of Object.entries(raw)) {
    if (!allowed.has(qid) || typeof v !== 'number' || !Number.isFinite(v)) continue;
    const s = Math.round(v);
    if (s < 0 || s > limit) continue;
    out[qid] = s;
  }
  return out;
}

/** Stored answers/{sectionId}.timings -> clean map (tolerant read). */
export function storedTimings(raw: unknown): Record<string, number> {
  if (!isRecord(raw)) return {};
  const out: Record<string, number> = {};
  for (const [qid, v] of Object.entries(raw)) if (typeof v === 'number' && Number.isFinite(v) && v >= 0) out[qid] = v;
  return out;
}

export function median(values: readonly number[]): number {
  if (values.length === 0) return 0;
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 === 1 ? s[mid]! : (s[mid - 1]! + s[mid]!) / 2;
}

export interface TopicTimeResult {
  /** topicId -> mean seconds (1 decimal). */
  topic_time_avg: Record<string, number>;
  slow_topics: string[];
}

/**
 * `questions` lists every question of the attempt with its topic;
 * `timings` maps questionId -> seconds (all sections merged).
 */
export function aggregateTopicTimes(
  questions: ReadonlyArray<{ question_id: string; topic_id: string | null }>,
  timings: Readonly<Record<string, number>>,
): TopicTimeResult {
  const all: number[] = [];
  const agg = new Map<string, { sum: number; n: number }>();
  for (const q of questions) {
    const t = timings[q.question_id];
    if (typeof t !== 'number') continue;
    all.push(t);
    if (!q.topic_id) continue;
    const a = agg.get(q.topic_id) ?? { sum: 0, n: 0 };
    a.sum += t;
    a.n += 1;
    agg.set(q.topic_id, a);
  }
  const med = median(all);
  const topic_time_avg: Record<string, number> = {};
  const means: Array<[string, number]> = [];
  for (const [topic, a] of [...agg.entries()].sort((x, y) => x[0].localeCompare(y[0]))) {
    const mean = a.sum / a.n;
    topic_time_avg[topic] = round1(mean);
    means.push([topic, mean]);
  }
  const slow_topics =
    med > 0
      ? means
          .filter(([, m]) => m > SLOW_FACTOR * med)
          .sort((x, y) => y[1] - x[1] || x[0].localeCompare(y[0]))
          .map(([t]) => t)
      : [];
  return { topic_time_avg, slow_topics };
}

/** recordActivity `seconds`: absent -> 0; otherwise an integer in [0, 3600]. */
export function parseActivitySeconds(raw: unknown): number {
  if (raw === undefined || raw === null) return 0;
  if (typeof raw !== 'number' || !Number.isInteger(raw) || raw < 0 || raw > MAX_ACTIVITY_SECONDS) {
    throw validationError(`seconds must be an integer in [0, ${MAX_ACTIVITY_SECONDS}]`, { field: 'seconds' });
  }
  return raw;
}
