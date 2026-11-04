/**
 * recordActivity {kind: lesson_completed|practice_answered, refId, correct?, count?}
 *   -> {xpAwarded, stats}
 *
 * XP is computed and stored only here (ARCHITECTURE §1.7), idempotently via
 * xp_events/{uid}/events/{eventId}. Practice correctness is reported by the
 * client (the legacy practice bank is client-readable, so it cannot be
 * verified); its impact is bounded by the 200 XP/day cap and practice XP is
 * never added to leaderboards. Leaderboards only receive exam XP.
 */
import '../config';
import { onCall } from 'firebase-functions/v2/https';
import { sha256Hex } from '../domain/hash';
import { DomainError, Reasons } from '../domain/reasons';
import { bishkekDayKey } from '../domain/time';
import { num } from '../domain/types';
import { applyLessonCompleted, applyPracticeCorrect, parseStats, statsView } from '../domain/xp';
import { callableOptions, db, FieldValue, payload, reqId, requireAuth, wrap } from './common';
import { statsRef, statsToDoc, xpEventRef } from './gamification';

/** Number of correct practice answers reported by the payload. */
export function practiceCorrectCount(correct: unknown, count: unknown): number {
  if (correct === false) return 0;
  if (typeof correct === 'number') return Math.max(0, Math.min(50, Math.trunc(correct)));
  const n = count === undefined || count === null ? 1 : Math.trunc(num(count, 1));
  return Math.max(0, Math.min(50, n));
}

export const recordActivity = onCall(
  callableOptions(),
  wrap('recordActivity', async (req) => {
    const uid = requireAuth(req);
    const data = payload(req);
    const kind = data['kind'];
    if (kind !== 'lesson_completed' && kind !== 'practice_answered') {
      throw new DomainError(Reasons.VALIDATION_FAILED, 'kind must be lesson_completed or practice_answered');
    }
    const refId = reqId(data['refId'], 'refId', true);
    const nowMs = Date.now();
    const refHash = sha256Hex(refId).slice(0, 40);

    let eventId: string;
    if (kind === 'lesson_completed') {
      const [lesson, daily] = await db().getAll(db().doc(`lessons/${refId}`), db().doc(`daily_lessons/${refId}`));
      if (!lesson!.exists && !daily!.exists) throw new DomainError(Reasons.VALIDATION_FAILED, 'unknown lesson', { field: 'refId' });
      eventId = `lesson_${refHash}`;
    } else {
      eventId = `practice_${bishkekDayKey(nowMs)}_${refHash}`;
    }
    const correctCount = kind === 'practice_answered' ? practiceCorrectCount(data['correct'], data['count']) : 0;

    return db().runTransaction(async (tx) => {
      const [eventSnap, statsSnap] = await tx.getAll(xpEventRef(uid, eventId), statsRef(uid));
      const stats = parseStats(statsSnap!.data());
      if (eventSnap!.exists) return { xpAwarded: 0, stats: statsView(stats), duplicate: true };
      const award = kind === 'lesson_completed' ? applyLessonCompleted(stats, nowMs) : applyPracticeCorrect(stats, correctCount, nowMs);
      tx.set(xpEventRef(uid, eventId), {
        kind,
        ref: refId.slice(0, 150),
        amount: award.total,
        daily_goal_bonus: award.dailyGoalBonus,
        correct_count: kind === 'practice_answered' ? correctCount : null,
        leaderboard_xp: 0,
        at: FieldValue.serverTimestamp(),
      });
      tx.set(statsRef(uid), statsToDoc(award.stats), { merge: true });
      return { xpAwarded: award.total, stats: statsView(award.stats), newAchievements: award.newAchievements };
    });
  }),
);
