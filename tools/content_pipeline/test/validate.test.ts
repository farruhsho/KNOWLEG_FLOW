import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { ExamVariant } from '../src/schema';
import { hasErrors, Problem, validateVariant, validateVariantSet } from '../src/validate';
import { languageMatrix } from '../src/matrix';
import { assembleMany, ctxFor } from './helpers';
import { realMatrix, syntheticBank } from './fixtures';

const codes = (ps: Problem[], severity: 'error' | 'warning' = 'error'): string[] => [...new Set(ps.filter((p) => p.severity === severity).map((p) => p.code))].sort();

describe('validate (adminPublishVariant rules)', () => {
  const bank = syntheticBank('ort_main_2026', 'ru', 2);
  const ctx = ctxFor(bank.items, bank.passages);
  const { files } = assembleMany('ort_main_2026', 'ru', bank.items, bank.passages, 2);
  const base = files[0]!;
  const clone = (): ExamVariant => structuredClone(base.variant);
  const itemMap = new Map(bank.items.map((i) => [i.id, i]));

  it('accepts an assembled variant of approved items for publishing', () => {
    const ps = validateVariant(base.id, { ...clone(), status: 'published' }, ctx, { publish: true, matrix: languageMatrix(realMatrix('ort_main_2026'), 'ru') });
    assert.deepEqual(codes(ps), []);
  });

  it('rejects publishing when an item is not methodologist_approved', () => {
    const v = clone();
    const qid = v.sections[0]!.question_ids[0]!;
    const local = ctxFor(
      bank.items.map((i) => (i.id === qid ? { ...i, question: { ...i.question, review: { ...i.question.review, status: 'ai_verified' as const } } } : i)),
      bank.passages,
    );
    assert.deepEqual(codes(validateVariant(base.id, v, local, { publish: true })), ['REVIEW_NOT_APPROVED']);
    // The same variant is fine as a draft.
    assert.equal(hasErrors(validateVariant(base.id, v, local, { publish: false })), false);
  });

  it('rejects rejected items even for drafts', () => {
    const qid = base.variant.sections[1]!.question_ids[3]!;
    const local = ctxFor(
      bank.items.map((i) => (i.id === qid ? { ...i, question: { ...i.question, review: { ...i.question.review, status: 'rejected' as const } } } : i)),
      bank.passages,
    );
    assert.deepEqual(codes(validateVariant(base.id, clone(), local, { publish: false })), ['REVIEW_REJECTED']);
  });

  it('needs a key for every question', () => {
    const qid = base.variant.sections[2]!.question_ids[0]!;
    const local = { ...ctx, key: (id: string) => (id === qid ? undefined : ctx.key(id)) };
    assert.deepEqual(codes(validateVariant(base.id, clone(), local, { publish: true })), ['KEY_MISSING']);
  });

  it('checks counts per section and per item type', () => {
    const v = clone();
    v.sections[0]!.question_ids.pop();
    assert.deepEqual(codes(validateVariant(base.id, v, ctx, { publish: false })), ['SECTION_COUNT', 'TYPE_COUNT']);
  });

  it('checks section order and presence', () => {
    const v = clone();
    [v.sections[0], v.sections[1]] = [v.sections[1]!, v.sections[0]!];
    assert.ok(codes(validateVariant(base.id, v, ctx, { publish: false })).includes('SECTION_MISMATCH'));
  });

  it('detects duplicate questions and questions from another section', () => {
    const v = clone();
    const math = v.sections[0]!.question_ids;
    math[1] = math[0]!;
    const verbalId = v.sections[1]!.question_ids[0]!;
    math[2] = verbalId;
    const c = codes(validateVariant(base.id, v, ctx, { publish: false }));
    assert.ok(c.includes('DUPLICATE_QUESTION_ID'));
    assert.ok(c.includes('QUESTION_SECTION'));
  });

  it('requires the blueprint fixed options for quantitative comparison', () => {
    const v = clone();
    const qcId = v.sections[0]!.question_ids.find((id) => itemMap.get(id)!.question.type === 'quantitative_comparison')!;
    const local = {
      ...ctx,
      question: (id: string) => {
        const q = ctx.question(id);
        return q && id === qcId ? { ...q, options: q.options.map((o, i) => (i === 3 ? { ...o, text: 'Нельзя сравнить' } : o)) } : q;
      },
    };
    assert.deepEqual(codes(validateVariant(base.id, v, local, { publish: false })), ['FIXED_OPTIONS']);
  });

  it('keeps passage questions consecutive and checks the passage layout', () => {
    const v = clone();
    const reading = v.sections[2]!.question_ids;
    [reading[0], reading[15]] = [reading[15]!, reading[0]!];
    assert.ok(codes(validateVariant(base.id, v, ctx, { publish: false })).includes('PASSAGE_NOT_CONTIGUOUS'));
    const noPassage = { ...ctx, passage: () => undefined };
    assert.ok(codes(validateVariant(base.id, clone(), noPassage, { publish: false })).includes('PASSAGE_MISSING'));
  });

  it('rejects language mismatches and unknown blueprints', () => {
    const v = clone();
    v.language = 'ky';
    assert.ok(codes(validateVariant(base.id, v, ctx, { publish: false })).includes('QUESTION_LANGUAGE'));
    const w = clone();
    w.blueprint_id = 'ort_main_2099';
    assert.deepEqual(codes(validateVariant(base.id, w, ctx, { publish: false })), ['BLUEPRINT_NOT_FOUND']);
    const x = clone();
    x.blueprint_version = 2;
    assert.ok(codes(validateVariant(base.id, x, ctx, { publish: false })).includes('BLUEPRINT_VERSION_MISMATCH'));
  });

  it('rejects documents that do not match the exam_variants schema', () => {
    const bad = { ...clone(), status: 'live', extra_field: 1 } as unknown;
    assert.deepEqual(codes(validateVariant(base.id, bad, ctx, { publish: false })), ['VARIANT_SCHEMA']);
  });

  it('flags item reuse, duplicate numbers and missing languages across a set', () => {
    const second = files[1]!;
    const okSet = validateVariantSet([{ id: base.id, variant: base.variant }, { id: second.id, variant: second.variant }], ctx, { allowReuse: false, requireLanguages: false });
    assert.deepEqual(codes(okSet), []);
    assert.deepEqual(codes(okSet, 'warning'), ['LANGUAGE_MISSING']);
    const strict = validateVariantSet([{ id: base.id, variant: base.variant }], ctx, { allowReuse: false, requireLanguages: true });
    assert.deepEqual(codes(strict), ['LANGUAGE_MISSING']);

    const copy = { ...structuredClone(base.variant), number: 2 };
    const reused = validateVariantSet([{ id: base.id, variant: base.variant }, { id: 'v_copy', variant: copy }], ctx, { allowReuse: false, requireLanguages: false });
    assert.deepEqual(codes(reused), ['ITEM_REUSED']);
    const allowed = validateVariantSet([{ id: base.id, variant: base.variant }, { id: 'v_copy', variant: copy }], ctx, { allowReuse: true, requireLanguages: false });
    assert.deepEqual(codes(allowed), []);

    const sameNumber = { ...structuredClone(second.variant), number: 1 };
    const dup = validateVariantSet([{ id: base.id, variant: base.variant }, { id: second.id, variant: sameNumber }], ctx, { allowReuse: false, requireLanguages: false });
    assert.deepEqual(codes(dup), ['DUPLICATE_VARIANT_NUMBER']);
  });
});
