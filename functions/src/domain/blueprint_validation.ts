/**
 * Checks a variant against its blueprint before publishing (ARCHITECTURE
 * §1.3: a variant may be published only if every question is
 * `methodologist_approved` and has a key). Pure; returns a list of problems
 * (empty = publishable).
 */
import type { Blueprint, BlueprintPart, BlueprintSection, ExamQuestion, QuestionKey, Variant } from './types';
import { partForIndex } from './types';

export type ProblemCode =
  | 'blueprint_mismatch'
  | 'blueprint_version_mismatch'
  | 'language_not_supported'
  | 'section_missing'
  | 'section_unexpected'
  | 'section_order'
  | 'section_count'
  | 'part_count'
  | 'duplicate_question'
  | 'question_missing'
  | 'question_wrong_section'
  | 'question_wrong_part'
  | 'question_wrong_language'
  | 'question_type_mismatch'
  | 'question_not_approved'
  | 'question_empty_stem'
  | 'options_count'
  | 'passage_missing'
  | 'key_missing'
  | 'key_invalid';

export interface Problem {
  code: ProblemCode;
  sectionId?: string;
  partId?: string;
  questionId?: string;
  expected?: string | number;
  actual?: string | number | null;
}

export interface ValidationInput {
  blueprint: Blueprint;
  variant: Variant;
  questions: ReadonlyMap<string, ExamQuestion | undefined>;
  keys: ReadonlyMap<string, QuestionKey | undefined>;
  /** Ids of exam_passages docs that exist (to check passage_id references). */
  passageIds?: ReadonlySet<string>;
}

/** Analogy/completion/text-based items may be stored as plain single_choice. */
export function typeMatches(part: BlueprintPart, questionType: string): boolean {
  if (part.item_type === questionType) return true;
  return questionType === 'single_choice' && part.item_type !== 'quantitative_comparison';
}

/** Option ids a key may name: the blueprint's fixed options for quantitative comparison, else the question's. */
export function allowedOptionIds(part: BlueprintPart, q: Pick<ExamQuestion, 'options'>): string[] {
  if (part.item_type === 'quantitative_comparison' && part.fixed_options) return part.fixed_options.map((o) => o.id);
  return q.options.map((o) => o.id);
}

/** A question needs a stem, unless it is a two-column comparison or an image item. */
export function hasStem(q: Pick<ExamQuestion, 'stem' | 'column_a' | 'column_b' | 'image_path'>): boolean {
  return q.stem.trim().length > 0 || !!(q.column_a && q.column_b) || !!q.image_path;
}

/**
 * Per-question checks against the blueprint part (no key, review or
 * section/language checks): type, option count (not for quantitative
 * comparison, whose options are the blueprint's fixed ones), stem, and a
 * passage for text_based parts. Used by the fresh pool (exam_pool.ts
 * poolItemFromDoc). validateVariant runs the same rules through its own
 * per-problem reporting (it shares typeMatches, allowedOptionIds and
 * hasStem) — change both together.
 */
export function questionPartProblems(part: BlueprintPart, q: ExamQuestion): ProblemCode[] {
  const out: ProblemCode[] = [];
  if (!typeMatches(part, q.type)) out.push('question_type_mismatch');
  if (part.item_type !== 'quantitative_comparison' && q.options.length !== part.options_per_question) out.push('options_count');
  if (part.item_type === 'text_based' && !q.passage_id) out.push('passage_missing');
  if (!hasStem(q)) out.push('question_empty_stem');
  return out;
}

/**
 * Part a question counts towards when a variant is validated.
 *
 * - An explicit `part_id` must name one of the section's parts (a stale or
 *   foreign id is `question_wrong_part`).
 * - A question without `part_id` in a single-part section belongs to that
 *   part. The CMS stores `part_id: null` there while the pipeline writes the
 *   part id, and both kinds of item may be mixed in one section.
 * - In a multi-part section a missing `part_id` is ambiguous once any
 *   question of the section is explicit, so it resolves to nothing
 *   (`question_wrong_part`). Only a section where no question carries a
 *   `part_id` falls back to positional parts (legacy variants).
 *
 * `explicitParts`: whether any question of the section has a `part_id`.
 */
export function partForValidation(
  section: BlueprintSection,
  q: Pick<ExamQuestion, 'part_id'>,
  index: number,
  explicitParts: boolean,
): BlueprintPart | undefined {
  if (q.part_id) return section.parts.find((p) => p.id === q.part_id);
  if (section.parts.length === 1) return section.parts[0];
  return explicitParts ? undefined : partForIndex(section, index);
}

export function validateVariant(input: ValidationInput): Problem[] {
  const { blueprint, variant } = input;
  const problems: Problem[] = [];

  if (variant.blueprint_id !== blueprint.id) {
    problems.push({ code: 'blueprint_mismatch', expected: blueprint.id, actual: variant.blueprint_id });
    return problems;
  }
  if (variant.blueprint_version !== blueprint.version) {
    problems.push({ code: 'blueprint_version_mismatch', expected: blueprint.version, actual: variant.blueprint_version });
  }
  if (blueprint.languages.length > 0 && !blueprint.languages.includes(variant.language)) {
    problems.push({ code: 'language_not_supported', expected: blueprint.languages.join(','), actual: variant.language });
  }

  const bpIds = blueprint.sections.map((s) => s.id);
  const vIds = variant.sections.map((s) => s.section_id);
  for (const id of bpIds) if (!vIds.includes(id)) problems.push({ code: 'section_missing', sectionId: id });
  for (const id of vIds) if (!bpIds.includes(id)) problems.push({ code: 'section_unexpected', sectionId: id });
  const common = vIds.filter((id) => bpIds.includes(id));
  const expectedOrder = bpIds.filter((id) => common.includes(id));
  if (common.join('|') !== expectedOrder.join('|')) {
    problems.push({ code: 'section_order', expected: expectedOrder.join(','), actual: common.join(',') });
  }

  const seen = new Set<string>();
  for (const bs of blueprint.sections) {
    const vs = variant.sections.find((s) => s.section_id === bs.id);
    if (!vs) continue;
    if (vs.question_ids.length !== bs.question_count) {
      problems.push({ code: 'section_count', sectionId: bs.id, expected: bs.question_count, actual: vs.question_ids.length });
    }

    // Explicit part_id on questions wins; see partForValidation for the
    // single-part fallback and the positional (no part_id at all) mode.
    const explicitParts = vs.question_ids.some((qid) => !!input.questions.get(qid)?.part_id);
    const partCounts = new Map<string, number>();

    vs.question_ids.forEach((qid, index) => {
      if (seen.has(qid)) problems.push({ code: 'duplicate_question', sectionId: bs.id, questionId: qid });
      seen.add(qid);

      const q = input.questions.get(qid);
      if (!q) {
        problems.push({ code: 'question_missing', sectionId: bs.id, questionId: qid });
        return;
      }
      const part = partForValidation(bs, q, index, explicitParts);
      if (!part) {
        problems.push({
          code: 'question_wrong_part',
          sectionId: bs.id,
          questionId: qid,
          expected: bs.parts.map((p) => p.id).join(','),
          actual: q.part_id,
        });
      } else {
        partCounts.set(part.id, (partCounts.get(part.id) ?? 0) + 1);
        if (!typeMatches(part, q.type)) {
          problems.push({ code: 'question_type_mismatch', sectionId: bs.id, partId: part.id, questionId: qid, expected: part.item_type, actual: q.type });
        }
        if (part.item_type !== 'quantitative_comparison' && q.options.length !== part.options_per_question) {
          problems.push({ code: 'options_count', sectionId: bs.id, partId: part.id, questionId: qid, expected: part.options_per_question, actual: q.options.length });
        }
        if (part.item_type === 'text_based' && !q.passage_id) {
          problems.push({ code: 'passage_missing', sectionId: bs.id, partId: part.id, questionId: qid });
        }
        const key = input.keys.get(qid);
        if (!key || !key.correct) {
          problems.push({ code: 'key_missing', sectionId: bs.id, questionId: qid });
        } else if (!allowedOptionIds(part, q).includes(key.correct)) {
          problems.push({ code: 'key_invalid', sectionId: bs.id, questionId: qid, actual: key.correct });
        }
      }
      if (q.section_id && q.section_id !== bs.id) {
        problems.push({ code: 'question_wrong_section', sectionId: bs.id, questionId: qid, actual: q.section_id });
      }
      if (q.language && q.language !== variant.language) {
        problems.push({ code: 'question_wrong_language', sectionId: bs.id, questionId: qid, expected: variant.language, actual: q.language });
      }
      if (q.review_status !== 'methodologist_approved') {
        problems.push({ code: 'question_not_approved', sectionId: bs.id, questionId: qid, actual: q.review_status });
      }
      if (!hasStem(q)) {
        problems.push({ code: 'question_empty_stem', sectionId: bs.id, questionId: qid });
      }
      if (q.passage_id && input.passageIds && !input.passageIds.has(q.passage_id)) {
        problems.push({ code: 'passage_missing', sectionId: bs.id, questionId: qid, actual: q.passage_id });
      }
    });

    for (const part of bs.parts) {
      const got = partCounts.get(part.id) ?? 0;
      if (got !== part.question_count) {
        problems.push({ code: 'part_count', sectionId: bs.id, partId: part.id, expected: part.question_count, actual: got });
      }
    }
  }
  return problems;
}
