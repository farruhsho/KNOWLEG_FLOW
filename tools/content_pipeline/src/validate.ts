/**
 * Stage 9 — validation of variants. `validateVariant` holds the publish rules
 * of adminPublishVariant (ARCHITECTURE §1.3: every question
 * methodologist_approved and keyed, counts exactly per blueprint). It has no
 * file-system or Firestore dependency so the Cloud Function can run the same
 * code over Firestore documents. Problems with severity "error" block
 * publishing; "warning" problems are pipeline quality signals.
 */
import { Blueprint, BlueprintSection, fixedOptionsFor, sectionsInOrder } from './blueprints';
import { DifficultyKey, LanguageMatrix } from './matrix';
import { ExamPassage, ExamQuestion, ExamQuestionKey, ExamVariant, formatIssues, ItemType } from './schema';

export type Severity = 'error' | 'warning';

export interface Problem {
  code: string;
  severity: Severity;
  message: string;
  variant_id?: string;
  section_id?: string;
  question_id?: string;
}

export interface ValidationContext {
  blueprints: Blueprint[];
  question(id: string): ExamQuestion | undefined;
  key(id: string): ExamQuestionKey | undefined;
  passage(id: string): (ExamPassage & { layout?: 'standalone' | 'paired' }) | undefined;
  /** Pipeline-only: blueprint part of an item (bank wrapper target). Enables matrix checks. */
  partOf?(id: string): string | undefined;
}

export interface ValidateOptions {
  /** true = rules for status 'published' (adminPublishVariant). */
  publish: boolean;
  /** Pipeline-only matrix checks (difficulty mix, topic ranges). */
  matrix?: LanguageMatrix;
  /** Allowed |actual − target| per difficulty in parts with passages (passage groups cannot be split freely). */
  passageDifficultyTolerance?: number;
}

export function validateVariant(variantId: string, doc: unknown, ctx: ValidationContext, opts: ValidateOptions): Problem[] {
  const problems: Problem[] = [];
  const err = (code: string, message: string, extra: Partial<Problem> = {}): void => {
    problems.push({ code, severity: 'error', message, variant_id: variantId, ...extra });
  };
  const warn = (code: string, message: string, extra: Partial<Problem> = {}): void => {
    problems.push({ code, severity: 'warning', message, variant_id: variantId, ...extra });
  };

  const parsed = ExamVariant.safeParse(doc);
  if (!parsed.success) {
    for (const m of formatIssues(parsed.error)) err('VARIANT_SCHEMA', m);
    return problems;
  }
  const v = parsed.data;
  const bp = ctx.blueprints.find((b) => b.id === v.blueprint_id);
  if (!bp) {
    err('BLUEPRINT_NOT_FOUND', `blueprint ${v.blueprint_id} not found`);
    return problems;
  }
  if (bp.version !== v.blueprint_version) err('BLUEPRINT_VERSION_MISMATCH', `variant targets v${v.blueprint_version}, blueprint is v${bp.version}`);
  if (!bp.languages.includes(v.language)) err('LANGUAGE_NOT_IN_BLUEPRINT', `${v.language} not in ${bp.languages.join(', ')}`);
  if (opts.publish && v.status === 'archived') err('VARIANT_ARCHIVED', 'archived variants cannot be published');

  const bsections = sectionsInOrder(bp);
  const vIds = v.sections.map((s) => s.section_id);
  const bIds = bsections.map((s) => s.id);
  if (vIds.join(',') !== bIds.join(',')) err('SECTION_MISMATCH', `sections [${vIds.join(', ')}] must be [${bIds.join(', ')}] in this order`);

  const seenIds = new Set<string>();
  const seenHashes = new Map<string, string>();
  for (const bs of bsections) {
    const vs = v.sections.find((s) => s.section_id === bs.id);
    if (!vs) continue;
    const sec = { section_id: bs.id };
    if (vs.question_ids.length !== bs.question_count) err('SECTION_COUNT', `${bs.id}: ${vs.question_ids.length} questions, blueprint needs ${bs.question_count}`, sec);

    const typeCount = new Map<string, number>();
    const passageRuns = new Map<string, number[]>();
    const sectionQuestions: Array<{ id: string; q: ExamQuestion; k: ExamQuestionKey | undefined }> = [];
    vs.question_ids.forEach((qid, idx) => {
      const at = { ...sec, question_id: qid };
      if (seenIds.has(qid)) err('DUPLICATE_QUESTION_ID', `${qid} appears more than once`, at);
      seenIds.add(qid);
      const q = ctx.question(qid);
      if (!q) {
        err('QUESTION_NOT_FOUND', `${qid} does not exist`, at);
        return;
      }
      const k = ctx.key(qid);
      sectionQuestions.push({ id: qid, q, k });
      const prevHash = seenHashes.get(q.content_hash);
      if (prevHash && prevHash !== qid) err('DUPLICATE_CONTENT', `${qid} has the same content_hash as ${prevHash}`, at);
      seenHashes.set(q.content_hash, qid);
      if (q.language !== v.language) err('QUESTION_LANGUAGE', `${qid} is ${q.language}, variant is ${v.language}`, at);
      if (q.section_id !== bs.id) err('QUESTION_SECTION', `${qid} belongs to section ${q.section_id}`, at);
      typeCount.set(q.type, (typeCount.get(q.type) ?? 0) + 1);

      const parts = bs.parts.filter((p) => p.item_type === q.type);
      if (parts.length === 0) {
        err('QUESTION_TYPE', `${qid}: type ${q.type} is not used in section ${bs.id}`, at);
      } else {
        const expectedOptions = new Set(parts.map((p) => p.options_per_question));
        if (!expectedOptions.has(q.options.length)) err('OPTIONS_COUNT', `${qid}: ${q.options.length} options, part needs ${[...expectedOptions].join('/')}`, at);
        const fixedPart = parts.find((p) => p.fixed_options && p.fixed_options.length);
        if (fixedPart) {
          const fixed = fixedOptionsFor(fixedPart, v.language) ?? [];
          const same = fixed.length === q.options.length && fixed.every((f, i) => q.options[i]!.id === f.id && q.options[i]!.text === f.text);
          if (!same) err('FIXED_OPTIONS', `${qid}: options must be the blueprint's fixed options for ${v.language}`, at);
        }
      }
      if (!k) err('KEY_MISSING', `${qid} has no exam_question_keys document`, at);
      else if (!q.options.some((o) => o.id === k.correct)) err('KEY_INVALID', `${qid}: key ${k.correct} is not an option`, at);

      const st = q.review.status;
      if (st === 'rejected') err('REVIEW_REJECTED', `${qid} is rejected`, at);
      else if (opts.publish && st !== 'methodologist_approved') err('REVIEW_NOT_APPROVED', `${qid} is ${st}; publishing needs methodologist_approved`, at);
      else if (st === 'draft') warn('REVIEW_DRAFT', `${qid} is still a draft`, at);

      if (q.type === 'text_based' && !q.passage_id) err('PASSAGE_MISSING', `${qid}: text_based item without passage`, at);
      if (q.passage_id) {
        const p = ctx.passage(q.passage_id);
        if (!p) err('PASSAGE_MISSING', `${qid}: passage ${q.passage_id} not found`, at);
        else if (p.language !== q.language) err('PASSAGE_LANGUAGE', `${qid}: passage is ${p.language}`, at);
        passageRuns.set(q.passage_id, [...(passageRuns.get(q.passage_id) ?? []), idx]);
      }
    });

    const expectedTypes = new Map<string, number>();
    for (const p of bs.parts) expectedTypes.set(p.item_type, (expectedTypes.get(p.item_type) ?? 0) + p.question_count);
    for (const [t, n] of expectedTypes) {
      const got = typeCount.get(t) ?? 0;
      if (got !== n) err('TYPE_COUNT', `${bs.id}: ${got} ${t} items, blueprint needs ${n}`, sec);
    }
    for (const [pid, idxs] of passageRuns) {
      const contiguous = idxs.every((x, i) => i === 0 || x === idxs[i - 1]! + 1);
      if (!contiguous) err('PASSAGE_NOT_CONTIGUOUS', `${bs.id}: questions of passage ${pid} must be consecutive`, sec);
    }
    checkPassageLayout(bs, passageRuns, ctx, err, warn);
    checkKeySkew(bs, sectionQuestions, ctx, warn);
    if (opts.matrix) checkMatrix(bs, sectionQuestions, ctx, opts, warn);
  }
  return problems;
}

function checkPassageLayout(
  bs: BlueprintSection,
  runs: Map<string, number[]>,
  ctx: ValidationContext,
  err: (c: string, m: string, e?: Partial<Problem>) => void,
  warn: (c: string, m: string, e?: Partial<Problem>) => void,
): void {
  const layout = bs.passage_layout;
  if (!layout) return;
  const expected = layout.standalone_texts + layout.paired_texts;
  if (runs.size !== expected) {
    err('PASSAGE_LAYOUT', `${bs.id}: ${runs.size} passages, blueprint layout needs ${expected} (${layout.standalone_texts} standalone + ${layout.paired_texts} paired)`, { section_id: bs.id });
    return;
  }
  const layouts = [...runs.keys()].map((id) => ctx.passage(id)?.layout);
  if (layouts.every((l) => l !== undefined)) {
    const paired = layouts.filter((l) => l === 'paired').length;
    if (paired !== layout.paired_texts) warn('PASSAGE_PAIRED', `${bs.id}: ${paired} paired passage(s), layout needs ${layout.paired_texts}`, { section_id: bs.id });
  }
}

function checkKeySkew(
  bs: BlueprintSection,
  qs: Array<{ id: string; q: ExamQuestion; k: ExamQuestionKey | undefined }>,
  ctx: ValidationContext,
  warn: (c: string, m: string, e?: Partial<Problem>) => void,
): void {
  const groups = new Map<string, string[]>();
  for (const { id, q, k } of qs) {
    if (!k) continue;
    const part = ctx.partOf?.(id) ?? q.type;
    groups.set(part, [...(groups.get(part) ?? []), k.correct]);
  }
  for (const [part, keys] of groups) {
    if (keys.length < 10) continue;
    const counts = new Map<string, number>();
    for (const k of keys) counts.set(k, (counts.get(k) ?? 0) + 1);
    for (const [letter, n] of counts) {
      if (n / keys.length > 0.4) warn('KEY_SKEW', `${bs.id}/${part}: ${n} of ${keys.length} keys are ${letter}`, { section_id: bs.id });
    }
  }
}

function checkMatrix(
  bs: BlueprintSection,
  qs: Array<{ id: string; q: ExamQuestion }>,
  ctx: ValidationContext,
  opts: ValidateOptions,
  warn: (c: string, m: string, e?: Partial<Problem>) => void,
): void {
  const sm = opts.matrix!.sections.find((s) => s.section_id === bs.id);
  if (!sm) return;
  for (const pm of sm.parts) {
    const inPart = qs.filter(({ id, q }) => (ctx.partOf ? ctx.partOf(id) === pm.part_id : q.type === pm.item_type));
    if (inPart.length === 0) continue;
    const tol = pm.passage_plan ? (opts.passageDifficultyTolerance ?? 2) : 0;
    for (const d of ['1', '2', '3'] as DifficultyKey[]) {
      const got = inPart.filter(({ q }) => String(q.difficulty) === d).length;
      const want = pm.difficulty_counts[d];
      if (Math.abs(got - want) > tol) warn('DIFFICULTY_MIX', `${bs.id}/${pm.part_id}: ${got} items of difficulty ${d}, matrix ${want}${tol ? ` ±${tol}` : ''}`, { section_id: bs.id });
    }
    for (const t of pm.topics) {
      const got = inPart.filter(({ q }) => q.topic_id === t.topic_id).length;
      if (got < t.min || got > t.max) warn('TOPIC_MATRIX', `${bs.id}/${pm.part_id}: ${got} items of ${t.topic_id}, range [${t.min}, ${t.max}]`, { section_id: bs.id });
    }
    const known = new Set(pm.topics.map((t) => t.topic_id));
    for (const { id, q } of inPart) if (!known.has(q.topic_id)) warn('TOPIC_UNKNOWN', `${id}: topic ${q.topic_id} is not in the matrix of ${pm.part_id}`, { section_id: bs.id, question_id: id });
  }
}

export interface VariantRef {
  id: string;
  variant: ExamVariant;
}

/** Rules across a set of variants (numbers, reuse, language coverage). */
export function validateVariantSet(
  variants: VariantRef[],
  ctx: ValidationContext,
  opts: { allowReuse: boolean; requireLanguages: boolean },
): Problem[] {
  const problems: Problem[] = [];
  const byBpLang = new Map<string, VariantRef[]>();
  for (const v of variants) {
    const k = `${v.variant.blueprint_id}|${v.variant.language}`;
    byBpLang.set(k, [...(byBpLang.get(k) ?? []), v]);
  }
  for (const [k, list] of byBpLang) {
    const numbers = new Map<number, string>();
    const used = new Map<string, string>();
    for (const v of list) {
      if (v.variant.status === 'archived') continue;
      const prev = numbers.get(v.variant.number);
      if (prev) problems.push({ code: 'DUPLICATE_VARIANT_NUMBER', severity: 'error', message: `${k}: number ${v.variant.number} used by ${prev} and ${v.id}`, variant_id: v.id });
      numbers.set(v.variant.number, v.id);
      for (const s of v.variant.sections) {
        for (const qid of s.question_ids) {
          const other = used.get(qid);
          if (other && other !== v.id) {
            problems.push({
              code: 'ITEM_REUSED',
              severity: opts.allowReuse ? 'warning' : 'error',
              message: `${qid} is used in ${other} and ${v.id}`,
              variant_id: v.id,
              question_id: qid,
            });
          }
          used.set(qid, v.id);
        }
      }
    }
  }
  const blueprints = new Set(variants.map((v) => v.variant.blueprint_id));
  for (const bpId of blueprints) {
    const bp = ctx.blueprints.find((b) => b.id === bpId);
    if (!bp) continue;
    const langs = new Map<string, Set<number>>();
    for (const v of variants.filter((x) => x.variant.blueprint_id === bpId && x.variant.status !== 'archived')) {
      langs.set(v.variant.language, (langs.get(v.variant.language) ?? new Set()).add(v.variant.number));
    }
    for (const lang of bp.languages) {
      if (!langs.has(lang)) {
        problems.push({ code: 'LANGUAGE_MISSING', severity: opts.requireLanguages ? 'error' : 'warning', message: `${bpId}: no ${lang} variants in the set` });
      }
    }
    if (bp.languages.length > 1) {
      const all = new Set([...langs.values()].flatMap((s) => [...s]));
      for (const n of [...all].sort((a, b) => a - b)) {
        const missing = bp.languages.filter((l) => !langs.get(l)?.has(n));
        if (missing.length && missing.length < bp.languages.length) {
          problems.push({ code: 'LANGUAGE_PAIR_MISSING', severity: 'warning', message: `${bpId}: variant ${n} has no ${missing.join(', ')} version` });
        }
      }
    }
  }
  return problems;
}

export const hasErrors = (ps: Problem[]): boolean => ps.some((p) => p.severity === 'error');

export function formatProblems(ps: Problem[]): string {
  return ps.map((p) => `${p.severity === 'error' ? 'ERROR' : 'warn '} ${p.code} ${p.variant_id ?? ''} ${p.message}`).join('\n');
}

/** Item types whose options must come from the blueprint, for generation. */
export const FIXED_OPTION_TYPES: ItemType[] = ['quantitative_comparison'];
