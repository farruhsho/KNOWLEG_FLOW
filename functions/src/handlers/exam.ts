/**
 * Exam callables (ARCHITECTURE §3): examStart, examGetState,
 * examSubmitSection, examGetReview, and the examExpireStale scheduler.
 */
import '../config';
import type { DocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { applyStartDecision, decideExamStart, parseEntitlement, parseFreeExamsPerUser } from '../domain/entitlements';
import {
  applyExpiry,
  applySectionSubmit,
  assertOwner,
  buildInitialAttempt,
  isStale,
  sanitizeAnswers,
  sanitizeFlags,
  STALE_AFTER_MS,
  type AttemptState,
} from '../domain/exam_session';
import { buildSessionPayload, classifySubmit, clientOptions, type ExamSessionPayload } from '../domain/payload';
import { DomainError, Reasons } from '../domain/reasons';
import type { ExamResult } from '../domain/scoring';
import { sanitizeTimings, storedTimings } from '../domain/timings';
import { isRecord, num, partForIndex, type Blueprint } from '../domain/types';
import {
  callableOptions,
  db,
  FieldValue,
  mapLimit,
  optString,
  payload,
  reqId,
  requireActiveUser,
  requireAuth,
  Timestamp,
  wrap,
} from './common';
import { bumpVariantStats, loadScoringContent, readCompletionInputs, writeCompletion, type CompletionContext } from './completion';
import {
  attemptFromDoc,
  attemptRef,
  attemptToDoc,
  loadBlueprint,
  loadCurrentSectionContent,
  loadKeys,
  loadPassages,
  loadQuestions,
  loadVariant,
} from './content';

async function requireBlueprint(id: string): Promise<Blueprint> {
  const bp = await loadBlueprint(id);
  if (!bp) throw new DomainError(Reasons.VARIANT_NOT_AVAILABLE, `blueprint ${id} not available`);
  return bp;
}

async function sessionPayload(
  attemptId: string,
  attempt: AttemptState,
  blueprint: Blueprint,
  entitlementSource?: string,
  result?: ExamResult | null,
): Promise<ExamSessionPayload> {
  const { questions, passages } = await loadCurrentSectionContent(attempt);
  return buildSessionPayload({
    attemptId,
    attempt,
    blueprint,
    questions,
    passages,
    nowMs: Date.now(),
    ...(entitlementSource ? { entitlementSource } : {}),
    result: result ?? null,
  });
}

async function readPricingFreeExams(): Promise<number> {
  const snap = await db().doc('config/pricing').get();
  return parseFreeExamsPerUser(snap.get('free_exams_per_user') ?? snap.get('freeExamsPerUser'));
}

function answersRef(attemptId: string, sectionId: string) {
  return attemptRef(attemptId).collection('answers').doc(sectionId);
}

function draftRef(attemptId: string, sectionId: string) {
  return attemptRef(attemptId).collection('drafts').doc(sectionId);
}

function answersFromSnap(snap: DocumentSnapshot | undefined): Record<string, string | null> {
  const a = snap?.exists ? snap.get('answers') : null;
  return isRecord(a) ? (a as Record<string, string | null>) : {};
}

function timingsFromSnap(snap: DocumentSnapshot | undefined): Record<string, number> {
  return storedTimings(snap?.exists ? snap.get('timings') : null);
}

// ---------------------------------------------------------------------------
// examStart {variantId, clientAppVersion} -> ExamSessionPayload

export const examStart = onCall(
  callableOptions(),
  wrap('examStart', async (req) => {
    // Deleted accounts (token still valid) and banned users cannot start or claim the free exam.
    const { uid } = await requireActiveUser(req);
    const data = payload(req);
    const variantId = reqId(data['variantId'], 'variantId');
    const clientAppVersion = optString(data['clientAppVersion'], 'clientAppVersion', 40) ?? '';

    const variant = await loadVariant(variantId);
    if (!variant || variant.status !== 'published') {
      throw new DomainError(Reasons.VARIANT_NOT_AVAILABLE, 'variant is not available');
    }
    const blueprint = await requireBlueprint(variant.blueprint_id);
    const freeExamsPerUser = await readPricingFreeExams();
    const entRef = db().doc(`entitlements/${uid}`);

    const started = await db().runTransaction(async (tx) => {
      const nowMs = Date.now();
      const inProgressQuery = db()
        .collection('exam_attempts')
        .where('uid', '==', uid)
        .where('variant_id', '==', variantId)
        .where('status', '==', 'in_progress')
        .limit(1);
      const [inProgress, entSnap] = await Promise.all([tx.get(inProgressQuery), tx.get(entRef)]);
      const existing = inProgress.docs[0];
      const entitlement = parseEntitlement(entSnap.data());
      const decision = decideExamStart({ entitlement, inProgressAttemptId: existing?.id ?? null, freeExamsPerUser });

      if (decision.kind === 'resume') {
        const state = attemptFromDoc(existing!.data());
        if (!state) throw new DomainError(Reasons.ATTEMPT_NOT_FOUND, 'corrupt attempt');
        return { attemptId: decision.attemptId, state, source: 'resume' };
      }
      if (decision.kind === 'none') {
        throw new DomainError(Reasons.NO_ENTITLEMENT, 'no free exam or credits left', { credits: entitlement.credits });
      }

      const ref = db().collection('exam_attempts').doc();
      const state = buildInitialAttempt({ uid, variant, blueprint, nowMs, entitlementSource: decision.kind, clientAppVersion });
      const applied = applyStartDecision(entitlement, decision, ref.id, nowMs);
      tx.set(ref, { ...attemptToDoc(state), result: null, created_at: FieldValue.serverTimestamp() });
      tx.set(
        entRef,
        {
          free_exam_used: applied.entitlement.free_exam_used,
          free_exam_used_at: applied.entitlement.free_exam_used_at ? Timestamp.fromMillis(applied.entitlement.free_exam_used_at) : null,
          free_exam_attempt_id: applied.entitlement.free_exam_attempt_id,
          free_exams_used_count: applied.entitlement.free_exams_used_count,
          credits: applied.entitlement.credits,
          lifetime_credits_purchased: applied.entitlement.lifetime_credits_purchased,
          updated_at: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.set(entRef.collection('ledger').doc(), {
        ...applied.ledger,
        ref: ref.id,
        actor_uid: uid,
        at: FieldValue.serverTimestamp(),
      });
      return { attemptId: ref.id, state, source: applied.entitlementSource as string };
    });

    logger.info('examStart', { uid, variantId, attemptId: started.attemptId, source: started.source });
    return sessionPayload(started.attemptId, started.state, blueprint, started.source);
  }),
);

// ---------------------------------------------------------------------------
// examGetState {attemptId} -> ExamSessionPayload

export const examGetState = onCall(
  callableOptions(),
  wrap('examGetState', async (req) => {
    const uid = requireAuth(req);
    const attemptId = reqId(payload(req)['attemptId'], 'attemptId');
    const snap = await attemptRef(attemptId).get();
    const attempt = snap.exists ? attemptFromDoc(snap.data()) : null;
    assertOwner(attempt, uid);
    const blueprint = await requireBlueprint(attempt.blueprint_id);
    const result = (snap.get('result') ?? null) as ExamResult | null;
    return sessionPayload(attemptId, attempt, blueprint, undefined, result);
  }),
);

// ---------------------------------------------------------------------------
// examSubmitSection {attemptId, sectionId, answers, flags, clientElapsedSec, timings?}
//   -> {completed, next?, result?}
// timings {questionId: seconds} (ARCHITECTURE §9.5): current-section questions
// only, whole seconds in [0, section duration]; invalid entries are dropped.

export const examSubmitSection = onCall(
  callableOptions({ timeoutSeconds: 120, memory: '512MiB' }),
  wrap('examSubmitSection', async (req) => {
    const uid = requireAuth(req);
    const data = payload(req);
    const attemptId = reqId(data['attemptId'], 'attemptId');
    const sectionId = reqId(data['sectionId'], 'sectionId');
    const clientElapsedSec = Math.max(0, Math.min(24 * 3600, Math.trunc(num(data['clientElapsedSec'], 0))));

    const pre = await attemptRef(attemptId).get();
    const preState = pre.exists ? attemptFromDoc(pre.data()) : null;
    assertOwner(preState, uid);
    const blueprint = await requireBlueprint(preState.blueprint_id);
    // Grading content for the final section is read before the transaction.
    const isLastSection =
      preState.status === 'in_progress' &&
      preState.current_section_id === sectionId &&
      preState.current_section_index === preState.sections.length - 1;
    const content = isLastSection ? await loadScoringContent(preState) : undefined;

    const outcome = await db().runTransaction(async (tx: Transaction) => {
      const nowMs = Date.now();
      const snap = await tx.get(attemptRef(attemptId));
      const attempt = snap.exists ? attemptFromDoc(snap.data()) : null;
      assertOwner(attempt, uid);

      const cls = classifySubmit(attempt, sectionId);
      if (cls === 'already_submitted') {
        // Retry after a lost response: report the current state, accept nothing.
        return { kind: 'replay' as const, attempt, result: (snap.get('result') ?? null) as ExamResult | null };
      }
      if (cls === 'not_in_progress') throw new DomainError(Reasons.ATTEMPT_NOT_IN_PROGRESS, `attempt is ${attempt.status}`);
      if (cls === 'wrong_section') {
        throw new DomainError(Reasons.WRONG_SECTION, 'not the current section', { currentSectionId: attempt.current_section_id });
      }

      const sec = attempt.sections[attempt.current_section_index]!;
      const answers = sanitizeAnswers(data['answers'], sec.question_ids);
      const flags = sanitizeFlags(data['flags'], sec.question_ids);
      const bs = blueprint.sections.find((s) => s.id === sectionId);
      const timings = sanitizeTimings(data['timings'], sec.question_ids, (bs?.duration_minutes ?? 0) * 60);
      const transition = applySectionSubmit(attempt, blueprint, sectionId, nowMs);
      const answersDoc = {
        section_id: sectionId,
        answers,
        flags,
        timings,
        submitted_at: Timestamp.fromMillis(nowMs),
        late: transition.closed.late,
        client_elapsed_sec: clientElapsedSec,
        source: 'client',
      };

      if (!transition.completed) {
        tx.set(answersRef(attemptId, sectionId), answersDoc);
        tx.set(attemptRef(attemptId), { ...attemptToDoc(transition.attempt), updated_at: FieldValue.serverTimestamp() }, { merge: true });
        return { kind: 'advanced' as const, attempt: transition.attempt };
      }

      // Last section: read the other sections' answers + completion inputs, then write.
      const others = transition.attempt.sections.filter((s) => s.section_id !== sectionId);
      const otherSnaps = others.length > 0 ? await tx.getAll(...others.map((s) => answersRef(attemptId, s.section_id))) : [];
      const answersBySection: Record<string, Record<string, string | null>> = {};
      const timingsBySection: Record<string, Record<string, number>> = {};
      others.forEach((s, i) => {
        answersBySection[s.section_id] = answersFromSnap(otherSnaps[i]);
        timingsBySection[s.section_id] = timingsFromSnap(otherSnaps[i]);
      });
      answersBySection[sectionId] = answers;
      timingsBySection[sectionId] = timings;
      const ctx: CompletionContext = { uid, attemptId, attempt: transition.attempt, blueprint, answersBySection, timingsBySection, nowMs };
      const reads = await readCompletionInputs(tx, ctx, content);
      tx.set(answersRef(attemptId, sectionId), answersDoc);
      const result = writeCompletion(tx, ctx, reads);
      return { kind: 'completed' as const, attempt: transition.attempt, result };
    });

    if (outcome.kind === 'completed') {
      await bumpVariantStats(outcome.attempt.variant_id, outcome.result.percent);
      logger.info('exam completed', { uid, attemptId, percent: outcome.result.percent, eligible: outcome.result.leaderboard_eligible });
      return { completed: true, result: outcome.result };
    }
    if (outcome.kind === 'replay' && outcome.attempt.status !== 'in_progress') {
      return { completed: true, result: outcome.result };
    }
    return { completed: false, next: await sessionPayload(attemptId, outcome.attempt, blueprint) };
  }),
);

// ---------------------------------------------------------------------------
// examGetReview {attemptId} -> {items: [...]} (completed attempts only)

export const examGetReview = onCall(
  callableOptions({ memory: '512MiB' }),
  wrap('examGetReview', async (req) => {
    const uid = requireAuth(req);
    const attemptId = reqId(payload(req)['attemptId'], 'attemptId');
    const snap = await attemptRef(attemptId).get();
    const attempt = snap.exists ? attemptFromDoc(snap.data()) : null;
    assertOwner(attempt, uid);
    if (attempt.status === 'in_progress') {
      throw new DomainError(Reasons.ATTEMPT_NOT_IN_PROGRESS, 'review is available after the attempt is completed');
    }
    const blueprint = await requireBlueprint(attempt.blueprint_id);
    const qids = attempt.sections.flatMap((s) => s.question_ids);
    const [answerSnaps, questions, keys] = await Promise.all([
      db().getAll(...attempt.sections.map((s) => answersRef(attemptId, s.section_id))),
      loadQuestions(qids),
      loadKeys(qids),
    ]);
    const passageIds = [...questions.values()].map((q) => q.passage_id).filter((p): p is string => !!p);
    const passages = await loadPassages(passageIds);

    const items: Record<string, unknown>[] = [];
    attempt.sections.forEach((sec, si) => {
      const bs = blueprint.sections.find((s) => s.id === sec.section_id);
      const answers = answersFromSnap(answerSnaps[si]);
      sec.question_ids.forEach((qid, index) => {
        const q = questions.get(qid);
        if (!q) return;
        const part = bs ? (q.part_id ? bs.parts.find((p) => p.id === q.part_id) : undefined) ?? partForIndex(bs, index) : undefined;
        const key = keys.get(qid);
        const passage = q.passage_id ? passages.get(q.passage_id) : undefined;
        const userAnswer = typeof answers[qid] === 'string' ? answers[qid] : null;
        items.push({
          questionId: qid,
          sectionId: sec.section_id,
          partId: part?.id ?? q.part_id,
          type: part?.item_type ?? q.type,
          stem: q.stem,
          options: clientOptions(q, part, attempt.language),
          columnA: q.column_a,
          columnB: q.column_b,
          imagePath: q.image_path,
          table: q.table ?? null,
          passage: passage ? { id: passage.id, title: passage.title, text: passage.text } : null,
          userAnswer,
          correct: key?.correct ?? null,
          isCorrect: !!key?.correct && userAnswer === key.correct,
          explanation: key?.explanation ?? null,
          wrongOptionNotes: key?.wrong_option_notes ?? {},
          solutionSteps: key?.solution_steps ?? [],
          topicId: q.topic_id,
        });
      });
    });
    return { items };
  }),
);

// ---------------------------------------------------------------------------
// examExpireStale: every 30 min, close attempts whose current section deadline
// passed more than 15 min ago, using the saved drafts.

async function expireOne(attemptId: string): Promise<'expired' | 'skipped'> {
  const pre = await attemptRef(attemptId).get();
  const preState = pre.exists ? attemptFromDoc(pre.data()) : null;
  if (!preState || !isStale(preState, Date.now())) return 'skipped';
  const blueprint = await loadBlueprint(preState.blueprint_id);
  if (!blueprint) {
    logger.error('expire: blueprint missing', { attemptId, blueprintId: preState.blueprint_id });
    return 'skipped';
  }
  const content = await loadScoringContent(preState);
  return db().runTransaction(async (tx) => {
    const nowMs = Date.now();
    const snap = await tx.get(attemptRef(attemptId));
    const attempt = snap.exists ? attemptFromDoc(snap.data()) : null;
    if (!attempt || !isStale(attempt, nowMs)) return 'skipped' as const;

    const current = attempt.sections[attempt.current_section_index];
    const transition = applyExpiry(attempt, nowMs);
    const closedIds = new Set(transition.closed.map((c) => c.section_id));
    const submitted = attempt.sections.filter((s) => !closedIds.has(s.section_id));
    const refs = [
      ...(current ? [draftRef(attemptId, current.section_id)] : []),
      ...submitted.map((s) => answersRef(attemptId, s.section_id)),
    ];
    const snaps = refs.length > 0 ? await tx.getAll(...refs) : [];
    const draft = current ? snaps[0] : undefined;
    const answersBySection: Record<string, Record<string, string | null>> = {};
    const timingsBySection: Record<string, Record<string, number>> = {};
    submitted.forEach((s, i) => {
      answersBySection[s.section_id] = answersFromSnap(snaps[(current ? 1 : 0) + i]);
      timingsBySection[s.section_id] = timingsFromSnap(snaps[(current ? 1 : 0) + i]);
    });
    for (const s of transition.attempt.sections) {
      if (!closedIds.has(s.section_id)) continue;
      answersBySection[s.section_id] =
        current && s.section_id === current.section_id
          ? sanitizeAnswers(draft?.exists ? draft.get('answers') : null, s.question_ids)
          : sanitizeAnswers(null, s.question_ids);
    }

    const ctx: CompletionContext = { uid: attempt.uid, attemptId, attempt: transition.attempt, blueprint, answersBySection, timingsBySection, nowMs };
    const reads = await readCompletionInputs(tx, ctx, content);
    for (const c of transition.closed) {
      const flags = current && c.section_id === current.section_id && draft?.exists ? draft.get('flags') : [];
      tx.set(answersRef(attemptId, c.section_id), {
        section_id: c.section_id,
        answers: answersBySection[c.section_id] ?? {},
        flags: sanitizeFlags(flags, transition.attempt.sections.find((s) => s.section_id === c.section_id)?.question_ids ?? []),
        submitted_at: Timestamp.fromMillis(nowMs),
        late: true,
        client_elapsed_sec: null,
        source: current && c.section_id === current.section_id ? 'server_expiry_draft' : 'server_expiry_unstarted',
      });
    }
    const result = writeCompletion(tx, ctx, reads);
    logger.info('attempt expired', { attemptId, uid: attempt.uid, percent: result.percent });
    return 'expired' as const;
  });
}

export const examExpireStale = onSchedule(
  { schedule: 'every 30 minutes', timeZone: 'Asia/Bishkek', timeoutSeconds: 540, memory: '512MiB', retryCount: 0 },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - STALE_AFTER_MS);
    let expired = 0;
    let failed = 0;
    for (let page = 0; page < 5; page++) {
      const snap = await db()
        .collection('exam_attempts')
        .where('status', '==', 'in_progress')
        .where('current_deadline_at', '<', cutoff)
        .orderBy('current_deadline_at', 'asc')
        .limit(100)
        .get();
      if (snap.empty) break;
      const results = await mapLimit(snap.docs, 5, async (d) => {
        try {
          return await expireOne(d.id);
        } catch (e) {
          logger.error('expire failed', { attemptId: d.id, error: String(e) });
          return 'failed' as const;
        }
      });
      expired += results.filter((r) => r === 'expired').length;
      failed += results.filter((r) => r === 'failed').length;
      if (snap.size < 100 || results.every((r) => r !== 'expired')) break;
    }
    // Variant stats for expired attempts are intentionally not bumped (unfinished work).
    logger.info('examExpireStale done', { expired, failed });
  },
);
