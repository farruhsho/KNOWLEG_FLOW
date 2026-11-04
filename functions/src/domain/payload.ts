/**
 * Builds the client-facing ExamSessionPayload (ARCHITECTURE §3). The client
 * only ever receives questions of the CURRENT section and never keys or
 * explanations: ClientQuestion is assembled field by field from the parsed
 * ExamQuestion, so stray fields on a Firestore document can never leak.
 */
import type { AttemptState } from './exam_session';
import type { ExamResult } from './scoring';
import type { Blueprint, BlueprintPart, ExamQuestion, Passage, QuestionOption } from './types';
import { partForIndex, pickLang } from './types';

export interface ClientQuestion {
  id: string;
  stem: string;
  options: QuestionOption[];
  passageId: string | null;
  imageUrl: string | null;
  imagePath: string | null;
  table: unknown;
  topicId: string | null;
  partId: string | null;
  type: string;
  columnA: string | null;
  columnB: string | null;
}

export interface SectionPayload {
  sectionId: string;
  index: number;
  deadlineAt: number;
  durationSec: number;
  questions: ClientQuestion[];
  passages: Record<string, { title: string; text: string }>;
}

export interface ExamSessionPayload {
  attemptId: string;
  variantId: string;
  blueprint: Record<string, unknown>;
  status: string;
  currentSectionIndex: number;
  section: SectionPayload | null;
  serverNow: number;
  entitlementSource: string;
  language: string;
  sectionsTotal: number;
  result?: ExamResult | null;
}

function isHttpUrl(v: string | null): v is string {
  return v !== null && /^https:\/\//i.test(v);
}

/** Options for a question: blueprint fixed options for quantitative comparison. */
export function clientOptions(q: ExamQuestion, part: BlueprintPart | undefined, language: string): QuestionOption[] {
  if (part?.item_type === 'quantitative_comparison' && part.fixed_options) {
    return part.fixed_options.map((o) => ({ id: o.id, text: pickLang(o.text, language) }));
  }
  return q.options.map((o) => ({ id: o.id, text: o.text }));
}

export function toClientQuestion(q: ExamQuestion, part: BlueprintPart | undefined, language: string): ClientQuestion {
  return {
    id: q.id,
    stem: q.stem,
    options: clientOptions(q, part, language),
    passageId: q.passage_id,
    imageUrl: isHttpUrl(q.image_path) ? q.image_path : null,
    imagePath: isHttpUrl(q.image_path) ? null : q.image_path,
    table: q.table ?? null,
    topicId: q.topic_id,
    partId: part?.id ?? q.part_id,
    type: part?.item_type ?? q.type,
    columnA: q.column_a,
    columnB: q.column_b,
  };
}

export interface BuildPayloadInput {
  attemptId: string;
  attempt: AttemptState;
  blueprint: Blueprint;
  /** Questions of the current section (others are ignored). */
  questions: ReadonlyMap<string, ExamQuestion>;
  passages: ReadonlyMap<string, Passage>;
  nowMs: number;
  entitlementSource?: string;
  result?: ExamResult | null;
}

export function buildSessionPayload(input: BuildPayloadInput): ExamSessionPayload {
  const { attempt, blueprint } = input;
  const base: ExamSessionPayload = {
    attemptId: input.attemptId,
    variantId: attempt.variant_id,
    blueprint: blueprint.raw,
    status: attempt.status,
    currentSectionIndex: attempt.current_section_index,
    section: null,
    serverNow: input.nowMs,
    entitlementSource: input.entitlementSource ?? attempt.entitlement_source,
    language: attempt.language,
    sectionsTotal: attempt.sections.length,
  };
  if (attempt.status !== 'in_progress') {
    base.result = input.result ?? null;
    return base;
  }
  const sec = attempt.sections[attempt.current_section_index];
  const bs = sec ? blueprint.sections.find((s) => s.id === sec.section_id) : undefined;
  if (!sec || !bs || sec.deadline_at === null) return base;

  const explicitParts = sec.question_ids.some((qid) => input.questions.get(qid)?.part_id);
  const questions: ClientQuestion[] = [];
  const passageIds = new Set<string>();
  sec.question_ids.forEach((qid, index) => {
    const q = input.questions.get(qid);
    if (!q) return; // missing content is reported by admin validation, not to students
    const part = explicitParts ? bs.parts.find((p) => p.id === q.part_id) ?? partForIndex(bs, index) : partForIndex(bs, index);
    questions.push(toClientQuestion(q, part, attempt.language));
    if (q.passage_id) passageIds.add(q.passage_id);
  });
  const passages: Record<string, { title: string; text: string }> = {};
  for (const pid of passageIds) {
    const p = input.passages.get(pid);
    if (p) passages[pid] = { title: p.title, text: p.text };
  }
  base.section = {
    sectionId: sec.section_id,
    index: attempt.current_section_index,
    deadlineAt: sec.deadline_at,
    durationSec: Math.round(bs.duration_minutes * 60),
    questions,
    passages,
  };
  return base;
}

/**
 * Classifies a submit call so retries after a lost response are idempotent:
 * re-submitting an already closed section returns the current state instead
 * of an error, while a future/unknown section is WRONG_SECTION.
 */
export type SubmitClass = 'current' | 'already_submitted' | 'wrong_section' | 'not_in_progress';

export function classifySubmit(attempt: AttemptState, sectionId: string): SubmitClass {
  const sec = attempt.sections.find((s) => s.section_id === sectionId);
  if (sec && sec.submitted_at !== null) return 'already_submitted';
  if (attempt.status !== 'in_progress') return 'not_in_progress';
  if (attempt.current_section_id === sectionId) return 'current';
  return 'wrong_section';
}
