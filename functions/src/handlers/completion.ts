/**
 * Exam completion inside a Firestore transaction: grade against
 * exam_question_keys, build ExamResult, record wrong answers in
 * user_mistakes (source 'exam'), award XP idempotently, update user_stats and
 * leaderboards. Split into a read phase and a write phase because Firestore
 * transactions require every read to happen before the first write.
 */
import type { DocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { isLeaderboardEligible, type AttemptState } from '../domain/exam_session';
import { leaderboardSubjectKey } from '../domain/leaderboard';
import { buildExamResult, scoreAttempt, wrongOutcomes, type ExamResult } from '../domain/scoring';
import { round1 } from '../domain/scoring';
import { DAY_MS } from '../domain/time';
import { directionKey, type Blueprint, type ExamQuestion, type QuestionKey } from '../domain/types';
import { applyExamCompletion, parseStats } from '../domain/xp';
import { attemptRef, attemptToDoc, loadKeys, loadQuestions } from './content';
import { db, FieldValue, Timestamp } from './common';
import { addLeaderboardXp, profileFromUserDoc, statsRef, statsToDoc, xpEventRef } from './gamification';

export interface CompletionContext {
  uid: string;
  attemptId: string;
  /** Attempt state AFTER the transition to `completed`. */
  attempt: AttemptState;
  blueprint: Blueprint;
  /** Final answers for every section (sectionId -> qid -> option|null). */
  answersBySection: Record<string, Record<string, string | null>>;
  nowMs: number;
}

export interface CompletionReads {
  keys: Map<string, QuestionKey>;
  questions: Map<string, ExamQuestion>;
  stats: DocumentSnapshot;
  user: DocumentSnapshot;
  xpEvent: DocumentSnapshot;
}

export function examXpEventId(attemptId: string): string {
  return `exam_${attemptId}`;
}

/** Answer keys + question metadata needed to grade an attempt. */
export interface ScoringContent {
  keys: Map<string, QuestionKey>;
  questions: Map<string, ExamQuestion>;
}

/**
 * Loads keys and questions OUTSIDE the transaction. The attempt's question
 * ids are fixed at examStart and content documents are not part of the
 * attempt's consistency boundary, so pre-loading them keeps the completion
 * transaction short (fewer locked documents, fewer contention retries).
 */
export async function loadScoringContent(attempt: AttemptState): Promise<ScoringContent> {
  const qids = attempt.sections.flatMap((s) => s.question_ids);
  const [keys, questions] = await Promise.all([loadKeys(qids), loadQuestions(qids)]);
  return { keys, questions };
}

/**
 * Transactional reads for completion. `content` should be pre-loaded with
 * loadScoringContent; when it is missing (the attempt reached its last
 * section between the pre-read and the transaction) it is read in `tx`.
 */
export async function readCompletionInputs(tx: Transaction, ctx: CompletionContext, content?: ScoringContent): Promise<CompletionReads> {
  const qids = ctx.attempt.sections.flatMap((s) => s.question_ids);
  const [keys, questions, [stats, user, xpEvent]] = await Promise.all([
    content ? Promise.resolve(content.keys) : loadKeys(qids, tx),
    content ? Promise.resolve(content.questions) : loadQuestions(qids, tx),
    tx.getAll(statsRef(ctx.uid), db().doc(`users/${ctx.uid}`), xpEventRef(ctx.uid, examXpEventId(ctx.attemptId))),
  ]);
  return { keys, questions, stats: stats!, user: user!, xpEvent: xpEvent! };
}

/** Writes everything for a completed attempt and returns its ExamResult. */
export function writeCompletion(tx: Transaction, ctx: CompletionContext, reads: CompletionReads): ExamResult {
  const { attempt, uid, nowMs } = ctx;
  const keys: Record<string, string | null> = {};
  const topics: Record<string, string | null> = {};
  for (const s of attempt.sections) {
    for (const qid of s.question_ids) {
      keys[qid] = reads.keys.get(qid)?.correct ?? null;
      topics[qid] = reads.questions.get(qid)?.topic_id ?? null;
    }
  }
  const score = scoreAttempt({ sections: attempt.sections, answers: ctx.answersBySection, keys, topics });
  if (score.unscored > 0) logger.warn('attempt has questions without keys', { attemptId: ctx.attemptId, unscored: score.unscored });
  const eligible = isLeaderboardEligible(attempt);

  let xpTotal = 0;
  if (!reads.xpEvent.exists) {
    const sectionPercents: Record<string, number> = {};
    for (const s of score.sections) sectionPercents[s.section_id] = s.percent;
    const award = applyExamCompletion(parseStats(reads.stats.data()), {
      direction: directionKey(ctx.blueprint.id),
      correct: score.correct,
      percent: score.percent,
      sectionPercents,
      nowMs,
    });
    xpTotal = award.total;
    const profile = profileFromUserDoc(reads.user);
    const toLeaderboard = eligible && !profile.banned;
    tx.set(xpEventRef(uid, examXpEventId(ctx.attemptId)), {
      kind: 'exam_completed',
      ref: ctx.attemptId,
      amount: award.total,
      base: award.baseXp,
      improved_bonus: award.improvedBonus,
      daily_goal_bonus: award.dailyGoalBonus,
      leaderboard_xp: toLeaderboard ? award.total : 0,
      at: FieldValue.serverTimestamp(),
    });
    tx.set(statsRef(uid), statsToDoc(award.stats), { merge: true });
    if (toLeaderboard) {
      addLeaderboardXp(tx, uid, profile, award.total, nowMs, leaderboardSubjectKey(ctx.blueprint));
    }
  }

  // Wrong answers -> "Mistakes & review" queue (no correct answer stored here).
  for (const o of wrongOutcomes(score)) {
    const q = reads.questions.get(o.question_id);
    tx.set(
      db().doc(`user_mistakes/${uid}/items/${o.question_id}`),
      {
        question_id: o.question_id,
        source: 'exam',
        subject_id: q?.subject_id ?? null,
        section_id: o.section_id,
        topic_id: o.topic_id,
        attempt_id: ctx.attemptId,
        wrong_count: FieldValue.increment(1),
        last_wrong_at: Timestamp.fromMillis(nowMs),
        next_review_at: Timestamp.fromMillis(nowMs + DAY_MS),
        interval_days: 1,
        resolved: false,
      },
      { merge: true },
    );
  }

  const result = buildExamResult(score, xpTotal, eligible);
  tx.set(attemptRef(ctx.attemptId), { ...attemptToDoc(attempt), result, updated_at: FieldValue.serverTimestamp() }, { merge: true });
  return result;
}

/**
 * Variant aggregate stats, outside the attempt transaction (a hot document
 * shared by every student taking the variant). Best effort.
 */
export async function bumpVariantStats(variantId: string, percent: number): Promise<void> {
  try {
    const ref = db().doc(`exam_variants/${variantId}`);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const stats = (snap.get('stats') ?? {}) as Record<string, unknown>;
      const attempts = (typeof stats['attempts'] === 'number' ? stats['attempts'] : 0) + 1;
      const sum = (typeof stats['sum_percent'] === 'number' ? stats['sum_percent'] : 0) + percent;
      tx.update(ref, { stats: { attempts, sum_percent: round1(sum), avg_percent: round1(sum / attempts) } });
    });
  } catch (e) {
    logger.warn('variant stats update failed', { variantId, error: String(e) });
  }
}
