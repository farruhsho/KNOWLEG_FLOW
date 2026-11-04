/**
 * recordActivity {kind: lesson_completed|practice_answered, refId, correct?, count?}
 *   -> {xpAwarded, stats}
 *
 * XP is computed and stored only here (ARCHITECTURE §1.7), idempotently via
 * xp_events/{uid}/events/{eventId}. Practice correctness is reported by the
 * client (the legacy practice bank is client-readable, so it cannot be
 * verified); its impact is bounded by the 200 XP/day cap. Awarded XP also
 * goes to the weekly and all-time leaderboards (decision D10; subject boards
 * stay exam-only). A 0 award (daily cap reached) writes nothing.
 */
import '../config';
import { onCall } from 'firebase-functions/v2/https';
import { activityEventId, dailyLessonTarget, isActivityKind, practiceCorrectCount, shouldPersistAward } from '../domain/activity';
import { DomainError, Reasons } from '../domain/reasons';
import { applyLessonCompleted, applyPracticeCorrect, parseStats, statsView } from '../domain/xp';
import { callableOptions, db, FieldValue, payload, reqId, requireActiveUser, wrap } from './common';
import { addLeaderboardXp, profileFromUserDoc, statsRef, statsToDoc, xpEventRef } from './gamification';

/**
 * Real lesson id for a lesson_completed refId: `lessons/{refId}` when it
 * exists, else the lesson a legacy `daily_lessons/{refId}` pointer names (if
 * that lesson exists). Null when neither resolves.
 */
async function resolveLessonId(refId: string): Promise<string | null> {
  const lesson = await db().doc(`lessons/${refId}`).get();
  if (lesson.exists) return refId;
  const daily = await db().doc(`daily_lessons/${refId}`).get();
  const target = daily.exists ? dailyLessonTarget(daily.data()) : null;
  if (!target || target === refId) return null;
  return (await db().doc(`lessons/${target}`).get()).exists ? target : null;
}

export const recordActivity = onCall(
  callableOptions(),
  wrap('recordActivity', async (req) => {
    const { uid, profile } = await requireActiveUser(req);
    const data = payload(req);
    const kind = data['kind'];
    if (!isActivityKind(kind)) {
      throw new DomainError(Reasons.VALIDATION_FAILED, 'kind must be lesson_completed or practice_answered');
    }
    const refId = reqId(data['refId'], 'refId', true);
    const nowMs = Date.now();

    let ref = refId;
    if (kind === 'lesson_completed') {
      const lessonId = await resolveLessonId(refId);
      if (!lessonId) throw new DomainError(Reasons.VALIDATION_FAILED, 'unknown lesson', { field: 'refId' });
      ref = lessonId;
    }
    const eventId = activityEventId(kind, ref, nowMs);
    const correctCount = kind === 'practice_answered' ? practiceCorrectCount(data['correct'], data['count']) : 0;
    const leaderboardProfile = profileFromUserDoc(profile);

    return db().runTransaction(async (tx) => {
      const [eventSnap, statsSnap] = await tx.getAll(xpEventRef(uid, eventId), statsRef(uid));
      const stats = parseStats(statsSnap!.data());
      if (eventSnap!.exists) return { xpAwarded: 0, stats: statsView(stats), duplicate: true };
      const award = kind === 'lesson_completed' ? applyLessonCompleted(stats, nowMs) : applyPracticeCorrect(stats, correctCount, nowMs);
      if (!shouldPersistAward(award.total)) {
        // Daily practice cap reached (or nothing correct): no event, no stats write.
        return { xpAwarded: 0, stats: statsView(stats), capped: kind === 'practice_answered' && correctCount > 0 };
      }
      const toLeaderboard = !leaderboardProfile.banned;
      tx.set(xpEventRef(uid, eventId), {
        kind,
        ref: ref.slice(0, 150),
        amount: award.total,
        daily_goal_bonus: award.dailyGoalBonus,
        correct_count: kind === 'practice_answered' ? correctCount : null,
        leaderboard_xp: toLeaderboard ? award.total : 0,
        at: FieldValue.serverTimestamp(),
      });
      tx.set(statsRef(uid), statsToDoc(award.stats), { merge: true });
      if (toLeaderboard) addLeaderboardXp(tx, uid, leaderboardProfile, award.total, nowMs, null);
      return { xpAwarded: award.total, stats: statsView(award.stats), newAchievements: award.newAchievements };
    });
  }),
);
