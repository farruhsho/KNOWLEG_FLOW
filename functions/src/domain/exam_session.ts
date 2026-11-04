/**
 * Exam attempt state machine (ARCHITECTURE §1.4, §4):
 *  - sections run strictly in blueprint order, forward-only;
 *  - each section has its own server deadline (`started_at + duration`);
 *  - a submission later than deadline + 120 s grace is accepted but flagged
 *    `late`, which makes the attempt ineligible for leaderboards;
 *  - the next section's clock starts only when the server accepted the
 *    previous one (new deadline = now + duration);
 *  - attempts whose current deadline passed > 15 min ago are closed by the
 *    scheduler from the saved drafts.
 * All times are epoch milliseconds; adapters convert to/from Timestamps.
 */
import { DomainError, Reasons } from './reasons';
import type { Blueprint, BlueprintSection, Variant } from './types';
import { isRecord } from './types';

export const LATE_GRACE_MS = 120_000;
export const STALE_AFTER_MS = 15 * 60_000;
export const MAX_ANSWER_ID_LENGTH = 8;

export type AttemptStatus = 'in_progress' | 'completed' | 'expired';
export type EntitlementSource = 'free_first' | 'credit' | 'admin_grant' | 'resume';

export interface AttemptSectionState {
  section_id: string;
  started_at: number | null;
  deadline_at: number | null;
  submitted_at: number | null;
  late: boolean;
  question_ids: string[];
}

export interface AttemptState {
  uid: string;
  variant_id: string;
  blueprint_id: string;
  blueprint_version: number;
  language: string;
  status: AttemptStatus;
  entitlement_source: EntitlementSource;
  current_section_index: number;
  current_section_id: string | null;
  current_deadline_at: number | null;
  sections: AttemptSectionState[];
  started_at: number;
  completed_at: number | null;
  integrity: {
    late_sections: number;
    client_app_version: string;
    expired_by_server: boolean;
  };
}

export function sectionDurationMs(section: BlueprintSection): number {
  return Math.round(section.duration_minutes * 60_000);
}

function blueprintSection(blueprint: Blueprint, sectionId: string): BlueprintSection {
  const s = blueprint.sections.find((x) => x.id === sectionId);
  if (!s) throw new DomainError(Reasons.VARIANT_NOT_AVAILABLE, `section ${sectionId} not in blueprint ${blueprint.id}`);
  return s;
}

export interface NewAttemptInput {
  uid: string;
  variant: Variant;
  blueprint: Blueprint;
  nowMs: number;
  entitlementSource: EntitlementSource;
  clientAppVersion: string;
}

/** Fresh attempt with the first section started now. */
export function buildInitialAttempt(input: NewAttemptInput): AttemptState {
  const { variant, blueprint, nowMs } = input;
  if (variant.blueprint_id !== blueprint.id) {
    throw new DomainError(Reasons.VARIANT_NOT_AVAILABLE, 'variant/blueprint mismatch');
  }
  const sections: AttemptSectionState[] = blueprint.sections.map((bs) => {
    const vs = variant.sections.find((x) => x.section_id === bs.id);
    if (!vs || vs.question_ids.length === 0) {
      throw new DomainError(Reasons.VARIANT_NOT_AVAILABLE, `variant ${variant.id} has no questions for section ${bs.id}`);
    }
    return { section_id: bs.id, started_at: null, deadline_at: null, submitted_at: null, late: false, question_ids: [...vs.question_ids] };
  });
  const first = sections[0]!;
  const firstBs = blueprint.sections[0]!;
  first.started_at = nowMs;
  first.deadline_at = nowMs + sectionDurationMs(firstBs);
  return {
    uid: input.uid,
    variant_id: variant.id,
    blueprint_id: blueprint.id,
    blueprint_version: blueprint.version,
    language: variant.language,
    status: 'in_progress',
    entitlement_source: input.entitlementSource,
    current_section_index: 0,
    current_section_id: first.section_id,
    current_deadline_at: first.deadline_at,
    sections,
    started_at: nowMs,
    completed_at: null,
    integrity: { late_sections: 0, client_app_version: input.clientAppVersion.slice(0, 40), expired_by_server: false },
  };
}

/** Throws the contract error when `uid` may not act on the attempt. */
export function assertOwner(attempt: AttemptState | null, uid: string): asserts attempt is AttemptState {
  // Same error for "missing" and "not yours" so ids cannot be probed.
  if (!attempt || attempt.uid !== uid) throw new DomainError(Reasons.ATTEMPT_NOT_FOUND, 'attempt not found');
}

/** Forward-only guard: only the current section of an in-progress attempt. */
export function assertCanSubmit(attempt: AttemptState, sectionId: string): void {
  if (attempt.status !== 'in_progress') {
    throw new DomainError(Reasons.ATTEMPT_NOT_IN_PROGRESS, `attempt is ${attempt.status}`);
  }
  if (attempt.current_section_id !== sectionId) {
    throw new DomainError(Reasons.WRONG_SECTION, `current section is ${attempt.current_section_id}`, {
      currentSectionId: attempt.current_section_id,
    });
  }
}

export function isLate(deadlineAt: number | null, submittedAt: number, graceMs = LATE_GRACE_MS): boolean {
  return deadlineAt !== null && submittedAt > deadlineAt + graceMs;
}

const ANSWER_RE = /^[A-Za-z0-9]{1,8}$/;

/**
 * Keeps only answers for questions of this section. Every section question
 * gets an entry (null = unanswered); anything malformed becomes null.
 */
export function sanitizeAnswers(raw: unknown, questionIds: readonly string[]): Record<string, string | null> {
  const src = isRecord(raw) ? raw : {};
  const out: Record<string, string | null> = {};
  for (const qid of questionIds) {
    const v = src[qid];
    out[qid] = typeof v === 'string' && ANSWER_RE.test(v.trim()) ? v.trim().toUpperCase() : null;
  }
  return out;
}

export function sanitizeFlags(raw: unknown, questionIds: readonly string[]): string[] {
  if (!Array.isArray(raw)) return [];
  const allowed = new Set(questionIds);
  return [...new Set(raw.filter((x): x is string => typeof x === 'string' && allowed.has(x)))];
}

function cloneAttempt(a: AttemptState): AttemptState {
  return { ...a, sections: a.sections.map((s) => ({ ...s, question_ids: [...s.question_ids] })), integrity: { ...a.integrity } };
}

export interface SectionClosure {
  section_id: string;
  submitted_at: number;
  late: boolean;
}

export interface SubmitTransition {
  attempt: AttemptState;
  closed: SectionClosure;
  completed: boolean;
}

/**
 * Closes the current section at `nowMs` and either starts the next one
 * (deadline = now + its duration) or completes the attempt.
 */
export function applySectionSubmit(attempt: AttemptState, blueprint: Blueprint, sectionId: string, nowMs: number): SubmitTransition {
  assertCanSubmit(attempt, sectionId);
  const a = cloneAttempt(attempt);
  const idx = a.current_section_index;
  const sec = a.sections[idx];
  if (!sec || sec.section_id !== sectionId) throw new DomainError(Reasons.WRONG_SECTION, 'section index out of sync');
  const late = isLate(sec.deadline_at, nowMs);
  sec.submitted_at = nowMs;
  sec.late = late;
  if (late) a.integrity.late_sections += 1;
  const next = a.sections[idx + 1];
  if (next) {
    const nbs = blueprintSection(blueprint, next.section_id);
    next.started_at = nowMs;
    next.deadline_at = nowMs + sectionDurationMs(nbs);
    a.current_section_index = idx + 1;
    a.current_section_id = next.section_id;
    a.current_deadline_at = next.deadline_at;
    return { attempt: a, closed: { section_id: sectionId, submitted_at: nowMs, late }, completed: false };
  }
  a.status = 'completed';
  a.completed_at = nowMs;
  a.current_section_id = null;
  a.current_deadline_at = null;
  return { attempt: a, closed: { section_id: sectionId, submitted_at: nowMs, late }, completed: true };
}

export function isStale(attempt: AttemptState, nowMs: number, staleAfterMs = STALE_AFTER_MS): boolean {
  return attempt.status === 'in_progress' && attempt.current_deadline_at !== null && nowMs > attempt.current_deadline_at + staleAfterMs;
}

export interface ExpiryTransition {
  attempt: AttemptState;
  /** Sections closed now: the current one (from drafts) and never-started ones. */
  closed: SectionClosure[];
}

/**
 * Server-side close of an abandoned attempt: the current section is closed
 * late (answers come from its draft), the remaining sections are closed
 * unanswered and late, and the attempt completes.
 */
export function applyExpiry(attempt: AttemptState, nowMs: number): ExpiryTransition {
  if (attempt.status !== 'in_progress') throw new DomainError(Reasons.ATTEMPT_NOT_IN_PROGRESS, 'not in progress');
  const a = cloneAttempt(attempt);
  const closed: SectionClosure[] = [];
  for (let i = a.current_section_index; i < a.sections.length; i++) {
    const s = a.sections[i]!;
    if (s.submitted_at !== null) continue;
    s.submitted_at = nowMs;
    s.late = true;
    a.integrity.late_sections += 1;
    closed.push({ section_id: s.section_id, submitted_at: nowMs, late: true });
  }
  a.status = 'completed';
  a.completed_at = nowMs;
  a.current_section_id = null;
  a.current_deadline_at = null;
  a.integrity.expired_by_server = true;
  return { attempt: a, closed };
}

/** Only attempts without late sections count for leaderboards. */
export function isLeaderboardEligible(attempt: AttemptState): boolean {
  return attempt.sections.every((s) => !s.late);
}

/** Remaining seconds of the current section (0 when overdue). */
export function remainingSec(attempt: AttemptState, nowMs: number): number {
  if (attempt.current_deadline_at === null) return 0;
  return Math.max(0, Math.round((attempt.current_deadline_at - nowMs) / 1000));
}
