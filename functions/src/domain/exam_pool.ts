/**
 * Phase 4 exam start options and the fresh-variant pool settings
 * (ARCHITECTURE §10.1, §10.2):
 *   examStart {variantId?, blueprintId?, language?, mode?: 'library'|'fresh',
 *              examStyle?: 'standard'|'strict', clientAppVersion}
 *   config/exam_pool {fresh_enabled (default true), min_review_status
 *              ('methodologist_approved' default | 'ai_verified'), updated_at, updated_by}
 */
import type { PassageLayout, PoolItem } from './assembly';
import type { AssemblySection } from './exam_matrix';
import { DomainError, Reasons } from './reasons';
import { isRecord, type Blueprint } from './types';

export type StartMode = 'library' | 'fresh';
export type ExamStyle = 'standard' | 'strict';
export type MinReviewStatus = 'methodologist_approved' | 'ai_verified';

export const MIN_REVIEW_STATUSES: readonly MinReviewStatus[] = ['methodologist_approved', 'ai_verified'];
export const DEFAULT_MIN_REVIEW_STATUS: MinReviewStatus = 'methodologist_approved';
/** Item languages of exam content (one variant = one language). */
export const EXAM_LANGUAGES = ['ru', 'ky', 'en'] as const;
/** Attempts of the same blueprint + language whose questions count as "seen". */
export const SEEN_ATTEMPTS_WINDOW = 50;

const ID_RE = /^[A-Za-z0-9_-]{1,128}$/;

export interface ExamPoolConfig {
  fresh_enabled: boolean;
  min_review_status: MinReviewStatus;
}

export function isMinReviewStatus(v: unknown): v is MinReviewStatus {
  return typeof v === 'string' && (MIN_REVIEW_STATUSES as readonly string[]).includes(v);
}

export function parseExamPoolConfig(raw: unknown): ExamPoolConfig {
  const r = isRecord(raw) ? raw : {};
  return {
    fresh_enabled: typeof r['fresh_enabled'] === 'boolean' ? r['fresh_enabled'] : true,
    min_review_status: isMinReviewStatus(r['min_review_status']) ? r['min_review_status'] : DEFAULT_MIN_REVIEW_STATUS,
  };
}

/** adminUpdateExamPool {freshEnabled?, minReviewStatus?} -> the fields to write. */
export function parseExamPoolUpdate(data: Record<string, unknown>): Partial<ExamPoolConfig> {
  const out: Partial<ExamPoolConfig> = {};
  if (data['freshEnabled'] !== undefined) {
    if (typeof data['freshEnabled'] !== 'boolean') throw new DomainError(Reasons.VALIDATION_FAILED, 'freshEnabled must be a boolean', { field: 'freshEnabled' });
    out.fresh_enabled = data['freshEnabled'];
  }
  if (data['minReviewStatus'] !== undefined) {
    if (!isMinReviewStatus(data['minReviewStatus'])) {
      throw new DomainError(Reasons.VALIDATION_FAILED, `minReviewStatus must be one of ${MIN_REVIEW_STATUSES.join(', ')}`, { field: 'minReviewStatus' });
    }
    out.min_review_status = data['minReviewStatus'];
  }
  if (Object.keys(out).length === 0) throw new DomainError(Reasons.VALIDATION_FAILED, 'nothing to update', { field: 'freshEnabled' });
  return out;
}

export type ExamStartInput =
  | { mode: 'library'; variantId: string; examStyle: ExamStyle; clientAppVersion: string }
  | { mode: 'fresh'; blueprintId: string; language: string; examStyle: ExamStyle; clientAppVersion: string };

function invalid(field: string, message: string): DomainError {
  return new DomainError(Reasons.VALIDATION_FAILED, message, { field });
}

function id(v: unknown, field: string): string {
  if (typeof v !== 'string' || !ID_RE.test(v) || v.startsWith('__')) throw invalid(field, `${field} is invalid`);
  return v;
}

/**
 * Validates the examStart payload. `mode` defaults to library when a
 * variantId is given (the phase 1–3 client), to fresh when only a
 * blueprintId is given; anything else is VALIDATION_FAILED.
 */
export function parseExamStartInput(data: Record<string, unknown>): ExamStartInput {
  const rawMode = data['mode'];
  if (rawMode !== undefined && rawMode !== null && rawMode !== 'library' && rawMode !== 'fresh') throw invalid('mode', 'mode must be library or fresh');
  const rawStyle = data['examStyle'];
  if (rawStyle !== undefined && rawStyle !== null && rawStyle !== 'standard' && rawStyle !== 'strict') {
    throw invalid('examStyle', 'examStyle must be standard or strict');
  }
  const examStyle: ExamStyle = rawStyle === 'strict' ? 'strict' : 'standard';
  const v = data['clientAppVersion'];
  if (v !== undefined && v !== null && (typeof v !== 'string' || v.length > 40)) throw invalid('clientAppVersion', 'clientAppVersion is invalid');
  const clientAppVersion = typeof v === 'string' ? v : '';
  const hasVariant = data['variantId'] !== undefined && data['variantId'] !== null;
  const mode: StartMode = rawMode === 'library' || rawMode === 'fresh' ? rawMode : hasVariant ? 'library' : 'fresh';
  if (mode === 'library') return { mode, variantId: id(data['variantId'], 'variantId'), examStyle, clientAppVersion };
  const blueprintId = id(data['blueprintId'], 'blueprintId');
  const language = data['language'];
  if (typeof language !== 'string' || !(EXAM_LANGUAGES as readonly string[]).includes(language)) throw invalid('language', 'language is invalid');
  return { mode, blueprintId, language, examStyle, clientAppVersion };
}

/**
 * A fresh variant needs an active blueprint in one of its languages
 * (`ort_state_language_*` lists only `ky`, the English subject test only
 * `en`). VARIANT_NOT_AVAILABLE / VALIDATION_FAILED otherwise.
 */
export function assertFreshBlueprint(bp: Blueprint, language: string): void {
  if (bp.status !== 'active') throw new DomainError(Reasons.VARIANT_NOT_AVAILABLE, `blueprint ${bp.id} is ${bp.status}`, { why: 'blueprint_inactive' });
  const languages = bp.languages.length > 0 ? bp.languages : ['ru', 'ky'];
  if (!languages.includes(language)) {
    throw new DomainError(Reasons.VALIDATION_FAILED, `blueprint ${bp.id} has no ${language} version`, { field: 'language', languages });
  }
}

/** Section/part structure of a parsed blueprint (already in exam order). */
export function assemblySections(bp: Blueprint): AssemblySection[] {
  return bp.sections.map((s) => ({ id: s.id, question_count: s.question_count, parts: s.parts.map((p) => ({ id: p.id, question_count: p.question_count })) }));
}

/**
 * Seen questions from the user's last attempts of the blueprint + language,
 * newest first: questionId -> started_at of the most recent attempt.
 */
export function lastSeenMap(attempts: ReadonlyArray<{ started_at: number; question_ids: readonly string[] }>): Map<string, number> {
  const out = new Map<string, number>();
  const sorted = [...attempts].sort((a, b) => b.started_at - a.started_at).slice(0, SEEN_ATTEMPTS_WINDOW);
  for (const a of sorted) for (const qid of a.question_ids) if (!out.has(qid)) out.set(qid, a.started_at);
  return out;
}

/** Fields of exam_questions the pool query reads (`select`). */
export const POOL_FIELDS = [
  'section_id',
  'part_id',
  'topic_id',
  'difficulty',
  'language',
  'passage_id',
  'passage_order',
  'blueprint_id',
  'review.status',
  'dedup_excluded',
  'duplicate_of',
] as const;

/**
 * exam_questions document -> pool item, or null when it can never be used:
 * rejected, excluded by deduplication (`dedup_excluded: true` or a
 * `duplicate_of` id), written for another blueprint (`blueprint_id`, when the
 * document carries it), or without a topic / valid difficulty. The review
 * status floor and the key / passage checks are applied by the caller.
 */
export function poolItemFromDoc(id: string, raw: unknown, blueprintId: string): PoolItem | null {
  if (!isRecord(raw)) return null;
  const review = isRecord(raw['review']) ? raw['review'] : {};
  const status = typeof review['status'] === 'string' ? review['status'] : 'draft';
  if (status === 'rejected') return null;
  if (raw['dedup_excluded'] === true || (typeof raw['duplicate_of'] === 'string' && raw['duplicate_of'].length > 0)) return null;
  if (typeof raw['blueprint_id'] === 'string' && raw['blueprint_id'] !== '' && raw['blueprint_id'] !== blueprintId) return null;
  const topic = typeof raw['topic_id'] === 'string' ? raw['topic_id'] : '';
  const difficulty = typeof raw['difficulty'] === 'number' ? Math.trunc(raw['difficulty']) : NaN;
  if (!topic || !(difficulty >= 1 && difficulty <= 3)) return null;
  const sectionId = typeof raw['section_id'] === 'string' ? raw['section_id'] : '';
  const partId = typeof raw['part_id'] === 'string' ? raw['part_id'] : '';
  if (!sectionId || !partId) return null;
  const passageId = typeof raw['passage_id'] === 'string' && raw['passage_id'].length > 0 ? raw['passage_id'] : null;
  const order = raw['passage_order'];
  return {
    id,
    section_id: sectionId,
    part_id: partId,
    topic_id: topic,
    difficulty,
    passage_id: passageId,
    passage_order: typeof order === 'number' && Number.isFinite(order) ? order : null,
    review_status: status,
  };
}

/** exam_passages.layout (`standalone` | `paired`); documents imported without it are `unknown`. */
export function passageLayoutOf(raw: unknown): PassageLayout {
  const layout = isRecord(raw) ? raw['layout'] : null;
  return layout === 'standalone' || layout === 'paired' ? layout : 'unknown';
}

/** Document id of the variant assembled for an attempt. */
export const freshVariantId = (attemptId: string): string => `fresh_${attemptId}`;
export const isFreshVariantId = (variantId: string): boolean => variantId.startsWith('fresh_');

/** Variant title (never shown as an official variant number). */
export const FRESH_VARIANT_TITLE = Object.freeze({ ru: 'Новый вариант', ky: 'Жаңы вариант', en: 'New variant' });
