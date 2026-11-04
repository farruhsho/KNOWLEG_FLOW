/**
 * AI callables (ARCHITECTURE §6): aiTutor for students and
 * adminAiDraftQuestions for content roles. The Anthropic key is the
 * ANTHROPIC_API_KEY secret; it never reaches the client.
 */
import '../config';
import Anthropic from '@anthropic-ai/sdk';
import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { AI_TUTOR_MODEL, ANTHROPIC_API_KEY } from '../config';
import { assertOwner } from '../domain/exam_session';
import { clientOptions } from '../domain/payload';
import { DomainError, Reasons } from '../domain/reasons';
import { bishkekDayKey } from '../domain/time';
import {
  buildContextBlock,
  buildTutorMessages,
  emptyReplyText,
  refusalText,
  TUTOR_SYSTEM_PROMPT,
  type QuestionContext,
} from '../domain/tutor_prompt';
import {
  decideQuota,
  estimateCostUsd,
  normalizeUsage,
  parseTutorConfig,
  sanitizeTutorInput,
  type TutorInput,
  type UsageNumbers,
} from '../domain/tutor_quota';
import { isRecord, localized, partForIndex, pickLang, str, strOrNull, type BlueprintPart } from '../domain/types';
import { callableOptions, db, FieldValue, payload, reqId, reqInt, requireAuth, requirePermission, wrap, writeAdminLog } from './common';
import { attemptFromDoc, attemptRef, bundledBlueprints, loadBlueprint, loadKeys, loadPassages, loadQuestions } from './content';
import { parseBlueprint } from '../domain/types';

const FALLBACK_BETA = 'server-side-fallback-2026-07-01';

function anthropic(): Anthropic {
  return new Anthropic({ apiKey: ANTHROPIC_API_KEY.value(), maxRetries: 2, timeout: 90_000 });
}

function mapAnthropicError(e: unknown): never {
  if (e instanceof Anthropic.RateLimitError) {
    logger.warn('anthropic rate limited');
    throw new HttpsError('unavailable', 'The tutor is busy, please retry in a minute.');
  }
  if (e instanceof Anthropic.AuthenticationError || e instanceof Anthropic.PermissionDeniedError) {
    logger.error('anthropic auth/config error', { error: String(e) });
    throw new HttpsError('internal', 'The tutor is temporarily unavailable.');
  }
  if (e instanceof Anthropic.BadRequestError) {
    logger.error('anthropic bad request', { error: String(e) });
    throw new HttpsError('internal', 'The tutor is temporarily unavailable.');
  }
  if (e instanceof Anthropic.APIError || e instanceof Anthropic.APIConnectionError) {
    logger.warn('anthropic api error', { error: String(e) });
    throw new HttpsError('unavailable', 'The tutor is temporarily unavailable, please retry.');
  }
  throw e;
}

function usageRef(uid: string, day: string) {
  return db().doc(`ai_usage/${uid}/days/${day}`);
}

async function logUsage(uid: string, day: string, model: string, usage: UsageNumbers, kind: string): Promise<void> {
  try {
    await usageRef(uid, day).set(
      {
        input_tokens: FieldValue.increment(usage.input_tokens),
        output_tokens: FieldValue.increment(usage.output_tokens),
        cache_creation_input_tokens: FieldValue.increment(usage.cache_creation_input_tokens),
        cache_read_input_tokens: FieldValue.increment(usage.cache_read_input_tokens),
        cost_usd_estimate: FieldValue.increment(estimateCostUsd(model, usage)),
        [`by_kind.${kind}`]: FieldValue.increment(1),
        last_model: model,
        updated_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } catch (e) {
    logger.warn('ai_usage log failed', { uid, error: String(e) });
  }
}

function textOf(content: readonly { type: string }[]): string {
  return content
    .filter((b): b is { type: 'text'; text: string } => b.type === 'text' && typeof (b as { text?: unknown }).text === 'string')
    .map((b) => b.text)
    .join('\n')
    .trim();
}

// ---------------------------------------------------------------------------
// Exam integrity + question context

async function assertNotInLiveExam(uid: string, input: TutorInput): Promise<void> {
  if (input.attemptId) {
    const snap = await attemptRef(input.attemptId).get();
    const a = snap.exists ? attemptFromDoc(snap.data()) : null;
    if (a && a.uid === uid && a.status === 'in_progress') {
      throw new DomainError(Reasons.AI_EXAM_IN_PROGRESS, 'finish the exam first');
    }
  }
  if (input.questionId) {
    const live = await db().collection('exam_attempts').where('uid', '==', uid).where('status', '==', 'in_progress').limit(10).get();
    for (const d of live.docs) {
      const a = attemptFromDoc(d.data());
      if (a?.sections.some((s) => s.question_ids.includes(input.questionId!))) {
        throw new DomainError(Reasons.AI_EXAM_IN_PROGRESS, 'question belongs to an exam in progress');
      }
    }
  }
}

/** Exam question context: only from the user's own COMPLETED attempt (keys are paid content). */
async function examQuestionContext(uid: string, attemptId: string, questionId: string): Promise<QuestionContext | null> {
  const snap = await attemptRef(attemptId).get();
  const attempt = snap.exists ? attemptFromDoc(snap.data()) : null;
  try {
    assertOwner(attempt, uid);
  } catch {
    return null;
  }
  if (attempt.status === 'in_progress') return null;
  const sectionIndex = attempt.sections.findIndex((s) => s.question_ids.includes(questionId));
  const section = attempt.sections[sectionIndex];
  if (!section) return null;
  const [questions, keys, answersSnap, blueprint] = await Promise.all([
    loadQuestions([questionId]),
    loadKeys([questionId]),
    attemptRef(attemptId).collection('answers').doc(section.section_id).get(),
    loadBlueprint(attempt.blueprint_id),
  ]);
  const q = questions.get(questionId);
  if (!q) return null;
  const bs = blueprint?.sections.find((s) => s.id === section.section_id);
  const index = section.question_ids.indexOf(questionId);
  const part: BlueprintPart | undefined = bs ? (q.part_id ? bs.parts.find((p) => p.id === q.part_id) : undefined) ?? partForIndex(bs, index) : undefined;
  const passage = q.passage_id ? (await loadPassages([q.passage_id])).get(q.passage_id) : undefined;
  const answers = answersSnap.get('answers');
  const userAnswer = isRecord(answers) && typeof answers[questionId] === 'string' ? (answers[questionId] as string) : null;
  const key = keys.get(questionId);
  const stem = [q.stem, q.column_a ? `Column A: ${q.column_a}` : '', q.column_b ? `Column B: ${q.column_b}` : ''].filter(Boolean).join('\n');
  return {
    stem,
    options: clientOptions(q, part, attempt.language),
    passageTitle: passage?.title ?? null,
    passageExcerpt: passage ? passage.text.slice(0, 3000) : null,
    userAnswer,
    correct: key?.correct ?? null,
    explanation: key?.explanation ?? null,
    topicId: q.topic_id,
  };
}

/** Legacy practice bank (`questions`): already client-readable, safe to quote. */
async function practiceQuestionContext(questionId: string, language: string): Promise<QuestionContext | null> {
  const snap = await db().doc(`questions/${questionId}`).get();
  if (!snap.exists) return null;
  const d = snap.data() ?? {};
  const options = (Array.isArray(d['options']) ? d['options'] : [])
    .map((o, i) => {
      if (typeof o === 'string') return { id: String.fromCharCode(65 + i), text: o };
      if (!isRecord(o)) return null;
      return { id: str(o['id'], String.fromCharCode(65 + i)), text: pickLang(localized(o['text']), language) };
    })
    .filter((o): o is { id: string; text: string } => o !== null);
  const correct = d['correct_answer'] ?? d['correct'];
  return {
    stem: pickLang(localized(d['stem'] ?? d['question'] ?? d['text']), language),
    options,
    correct: typeof correct === 'string' ? correct : null,
    explanation: pickLang(localized(d['explanation']), language) || null,
    topicId: strOrNull(d['topic_id'] ?? d['topicId']),
  };
}

// ---------------------------------------------------------------------------
// aiTutor {mode, message, language, questionId?, attemptId?, history?} -> {reply, remainingToday}

export const aiTutor = onCall(
  callableOptions({ secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 120, memory: '512MiB' }),
  wrap('aiTutor', async (req) => {
    const uid = requireAuth(req);
    const input = sanitizeTutorInput(req.data);
    const cfg = parseTutorConfig((await db().doc('config/ai_tutor').get()).data());
    if (!cfg.enabled || cfg.daily_limit === 0) throw new DomainError(Reasons.AI_DISABLED, 'AI tutor is disabled');

    await assertNotInLiveExam(uid, input);

    let context: QuestionContext | null = null;
    if (input.questionId) {
      context = input.attemptId
        ? await examQuestionContext(uid, input.attemptId, input.questionId)
        : await practiceQuestionContext(input.questionId, input.language);
    }

    // Reserve one request of today's quota atomically.
    const day = bishkekDayKey(Date.now());
    const ref = usageRef(uid, day);
    const quota = await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const used = typeof snap.get('count') === 'number' ? (snap.get('count') as number) : 0;
      const decision = decideQuota(used, cfg.daily_limit);
      if (!decision.allowed) {
        throw new DomainError(Reasons.AI_QUOTA_EXCEEDED, 'daily AI tutor limit reached', { remainingToday: 0, dailyLimit: cfg.daily_limit });
      }
      tx.set(ref, { day, count: used + 1, daily_limit: cfg.daily_limit, updated_at: FieldValue.serverTimestamp() }, { merge: true });
      return decision;
    });

    const model = AI_TUTOR_MODEL.value();
    const messages = buildTutorMessages(input.history, input.message, buildContextBlock(input.mode, input.language, context));
    let response: Anthropic.Beta.BetaMessage;
    try {
      response = await anthropic().beta.messages.create({
        model,
        max_tokens: cfg.max_tokens,
        betas: [FALLBACK_BETA],
        fallbacks: 'default',
        output_config: { effort: 'low' },
        system: [{ type: 'text', text: TUTOR_SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } }],
        messages,
      });
    } catch (e) {
      // Failed calls do not burn the student's quota.
      await ref.set({ count: FieldValue.increment(-1), errors: FieldValue.increment(1) }, { merge: true }).catch(() => undefined);
      mapAnthropicError(e);
    }

    const usage = normalizeUsage(response.usage);
    await logUsage(uid, day, response.model || model, usage, input.mode);

    if (response.stop_reason === 'refusal') {
      logger.info('aiTutor refusal', { uid, category: response.stop_details?.category ?? null });
      return { reply: refusalText(input.language), remainingToday: quota.remainingAfter, refused: true };
    }
    const reply = textOf(response.content) || emptyReplyText(input.language);
    return {
      reply,
      remainingToday: quota.remainingAfter,
      truncated: response.stop_reason === 'max_tokens',
      model: response.model,
    };
  }),
);

// ---------------------------------------------------------------------------
// adminAiDraftQuestions {subjectId, sectionId, partId, topicId, difficulty, language, count<=10}

interface DraftPartInfo {
  item_type: string;
  options_per_question: number;
  fixed_options: { id: string; text: string }[] | null;
  section_title: string;
  part_title: string;
}

async function findPart(sectionId: string, partId: string, language: string): Promise<DraftPartInfo> {
  for (const [id, raw] of bundledBlueprints()) {
    let bp;
    try {
      bp = (await loadBlueprint(id)) ?? parseBlueprint(id, raw);
    } catch {
      continue;
    }
    const s = bp.sections.find((x) => x.id === sectionId);
    const p = s?.parts.find((x) => x.id === partId);
    if (s && p) {
      return {
        item_type: p.item_type,
        options_per_question: p.options_per_question,
        fixed_options: p.fixed_options ? p.fixed_options.map((o) => ({ id: o.id, text: pickLang(o.text, language) })) : null,
        section_title: pickLang(s.title, language),
        part_title: pickLang(p.title, language),
      };
    }
  }
  return { item_type: 'single_choice', options_per_question: 4, fixed_options: null, section_title: sectionId, part_title: partId };
}

const DRAFT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['drafts'],
  properties: {
    drafts: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['stem', 'column_a', 'column_b', 'options', 'correct', 'explanation', 'wrong_option_notes', 'solution_steps'],
        properties: {
          stem: { type: 'string' },
          column_a: { type: 'string' },
          column_b: { type: 'string' },
          options: {
            type: 'array',
            items: {
              type: 'object',
              additionalProperties: false,
              required: ['id', 'text'],
              properties: { id: { type: 'string' }, text: { type: 'string' } },
            },
          },
          correct: { type: 'string' },
          explanation: { type: 'string' },
          wrong_option_notes: {
            type: 'array',
            items: {
              type: 'object',
              additionalProperties: false,
              required: ['option_id', 'note'],
              properties: { option_id: { type: 'string' }, note: { type: 'string' } },
            },
          },
          solution_steps: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  },
} as const;

const DRAFT_SYSTEM = `You write original practice items for the Kyrgyz ORT (national university admission test) in the exact format of the official test. Items must be original (never copied from published tests), factually correct, unambiguous, with exactly one correct option, plausible distractors based on typical student mistakes, and appropriate for school-leavers. Kyrgyz text must be natural Cyrillic Kyrgyz with ң, ө, ү. Write mathematics in LaTeX between single dollar signs. Every draft is reviewed by a methodologist before use.`;

export const adminAiDraftQuestions = onCall(
  callableOptions({ secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 300, memory: '512MiB' }),
  wrap('adminAiDraftQuestions', async (req) => {
    const actor = await requirePermission(req, 'edit_questions');
    const data = payload(req);
    const subjectId = reqId(data['subjectId'], 'subjectId');
    const sectionId = reqId(data['sectionId'], 'sectionId');
    const partId = reqId(data['partId'], 'partId');
    const topicId = reqId(data['topicId'], 'topicId', true);
    const difficulty = reqInt(data['difficulty'], 'difficulty', 1, 3);
    const language = data['language'] === 'ky' ? 'ky' : data['language'] === 'ru' ? 'ru' : null;
    if (!language) throw new DomainError(Reasons.VALIDATION_FAILED, 'language must be ru or ky');
    const count = reqInt(data['count'], 'count', 1, 10);

    const part = await findPart(sectionId, partId, language);
    const isQc = part.item_type === 'quantitative_comparison';
    const request = [
      `Write ${count} ORT items.`,
      `subject: ${subjectId}; section: ${part.section_title} (${sectionId}); part: ${part.part_title} (${partId}); item type: ${part.item_type}`,
      `topic: ${topicId}; difficulty: ${difficulty} of 3; language: ${language === 'ky' ? 'Kyrgyz' : 'Russian'}`,
      isQc && part.fixed_options
        ? `Quantitative comparison: put the two quantities in column_a and column_b, any shared condition in stem; options must be exactly: ${part.fixed_options.map((o) => `${o.id}) ${o.text}`).join('; ')}.`
        : `Use exactly ${part.options_per_question} options with ids ${Array.from({ length: part.options_per_question }, (_, i) => String.fromCharCode(65 + i)).join(', ')}; set column_a and column_b to empty strings.`,
      'explanation: why the correct option is right; wrong_option_notes: one note per wrong option; solution_steps: short ordered steps.',
    ].join('\n');

    const model = AI_TUTOR_MODEL.value();
    let response: Anthropic.Beta.BetaMessage;
    try {
      response = await anthropic().beta.messages.create({
        model,
        max_tokens: 12000,
        betas: [FALLBACK_BETA],
        fallbacks: 'default',
        output_config: { effort: 'medium', format: { type: 'json_schema', schema: DRAFT_SCHEMA as unknown as Record<string, unknown> } },
        system: [{ type: 'text', text: DRAFT_SYSTEM, cache_control: { type: 'ephemeral' } }],
        messages: [{ role: 'user', content: request }],
      });
    } catch (e) {
      mapAnthropicError(e);
    }
    const day = bishkekDayKey(Date.now());
    await logUsage(actor.uid, day, response.model || model, normalizeUsage(response.usage), 'admin_draft');
    if (response.stop_reason === 'refusal') {
      return { drafts: [], refused: true };
    }
    let parsed: unknown;
    try {
      parsed = JSON.parse(textOf(response.content));
    } catch {
      logger.error('draft JSON parse failed', { stop: response.stop_reason });
      throw new HttpsError('internal', 'The model returned an unreadable draft, please retry.');
    }
    const raw = isRecord(parsed) && Array.isArray(parsed['drafts']) ? parsed['drafts'] : [];
    const drafts = raw
      .filter(isRecord)
      .map((d) => {
        const options = isQc && part.fixed_options
          ? part.fixed_options
          : (Array.isArray(d['options']) ? d['options'] : []).filter(isRecord).map((o) => ({ id: str(o['id']), text: str(o['text']) }));
        const correct = str(d['correct']).trim().toUpperCase();
        const notes: Record<string, string> = {};
        for (const n of Array.isArray(d['wrong_option_notes']) ? d['wrong_option_notes'] : []) {
          if (isRecord(n) && typeof n['option_id'] === 'string' && typeof n['note'] === 'string') notes[n['option_id']] = n['note'];
        }
        return {
          question: {
            subject_id: subjectId,
            section_id: sectionId,
            part_id: partId,
            topic_id: topicId,
            difficulty,
            language,
            type: part.item_type,
            stem: str(d['stem']),
            column_a: isQc ? str(d['column_a']) || null : null,
            column_b: isQc ? str(d['column_b']) || null : null,
            options: isQc ? [] : options,
            passage_id: null,
            image_path: null,
            table: null,
            source: { kind: 'ai_draft', basis: `topic ${topicId}`, author: `ai:${response.model || model}` },
            review: { status: 'draft', reviewed_by: null, reviewed_at: null, notes: '' },
            content_version: 1,
          },
          key: {
            correct,
            explanation: str(d['explanation']),
            wrong_option_notes: notes,
            solution_steps: (Array.isArray(d['solution_steps']) ? d['solution_steps'] : []).filter((s): s is string => typeof s === 'string'),
          },
          valid: options.length === (isQc ? options.length : part.options_per_question) && options.some((o) => o.id === correct),
        };
      });
    await writeAdminLog(actor, 'ai_draft_questions', { subjectId, sectionId, partId, topicId }, { count, returned: drafts.length, model: response.model });
    return { drafts };
  }),
);
