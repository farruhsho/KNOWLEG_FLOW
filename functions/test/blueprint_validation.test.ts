import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { partForValidation, validateVariant } from '../src/domain/blueprint_validation';
import { parseBlueprint, parseQuestion } from '../src/domain/types';
import { blueprint, buildBank, rawBlueprints } from './fixtures';

const bp = blueprint('ort_main_2026');

function codes(problems: { code: string }[]): string[] {
  return [...new Set(problems.map((p) => p.code))].sort();
}

describe('bundled ORT 2026 blueprints', () => {
  it('all parse, and section/part counts add up', () => {
    for (const raw of rawBlueprints()) {
      const b = parseBlueprint(String(raw['id']), raw);
      for (const s of b.sections) {
        const parts = s.parts.reduce((n, p) => n + p.question_count, 0);
        assert.equal(parts, s.question_count, `${b.id}/${s.id}`);
      }
    }
    assert.deepEqual(bp.sections.map((s) => [s.id, s.question_count, s.duration_minutes]), [
      ['math', 60, 90],
      ['verbal', 30, 30],
      ['reading', 30, 60],
      ['grammar', 30, 35],
    ]);
  });
});

describe('validateVariant', () => {
  it('accepts a complete, approved, keyed variant (positional parts)', () => {
    const bank = buildBank(bp);
    assert.deepEqual(validateVariant({ blueprint: bp, ...bank }), []);
  });

  it('accepts explicit part ids too', () => {
    const bank = buildBank(bp, 'ky', true);
    assert.deepEqual(validateVariant({ blueprint: bp, ...bank }), []);
  });

  it('reports unapproved questions and missing keys', () => {
    const bank = buildBank(bp);
    bank.questions.set('math_q1', { ...bank.questions.get('math_q1')!, review_status: 'ai_verified' });
    bank.keys.delete('verbal_q3');
    const problems = validateVariant({ blueprint: bp, ...bank });
    assert.deepEqual(codes(problems), ['key_missing', 'question_not_approved']);
    assert.equal(problems.find((p) => p.code === 'key_missing')?.questionId, 'verbal_q3');
  });

  it('reports wrong counts per section and per part', () => {
    const bank = buildBank(bp);
    bank.variant.sections[0]!.question_ids.pop();
    const problems = validateVariant({ blueprint: bp, ...bank });
    assert.ok(problems.some((p) => p.code === 'section_count' && p.sectionId === 'math' && p.actual === 59));
    assert.ok(problems.some((p) => p.code === 'part_count' && p.partId === 'math_problems' && p.actual === 29));
  });

  it('reports missing sections, wrong order and duplicates', () => {
    const bank = buildBank(bp);
    const [m, v, r, g] = bank.variant.sections;
    bank.variant.sections = [v!, m!, r!];
    bank.variant.sections[2]!.question_ids[0] = 'math_q1';
    bank.questions.set('dup', bank.questions.get('math_q1')!);
    void g;
    assert.deepEqual(
      codes(validateVariant({ blueprint: bp, ...bank })).filter((c) => ['section_missing', 'section_order', 'duplicate_question'].includes(c)),
      ['duplicate_question', 'section_missing', 'section_order'],
    );
  });

  it('checks option counts, keys within options, passages and language', () => {
    const bank = buildBank(bp);
    const q2 = bank.questions.get('math_q31')!; // part II: 5 options
    bank.questions.set('math_q31', { ...q2, options: q2.options.slice(0, 4) });
    bank.keys.set('math_q32', { correct: 'Z', explanation: null, wrong_option_notes: {}, solution_steps: [] });
    bank.questions.set('reading_q1', { ...bank.questions.get('reading_q1')!, passage_id: null });
    bank.questions.set('grammar_q1', { ...bank.questions.get('grammar_q1')!, language: 'ky' });
    const c = codes(validateVariant({ blueprint: bp, ...bank }));
    for (const expected of ['options_count', 'key_invalid', 'passage_missing', 'question_wrong_language']) {
      assert.ok(c.includes(expected), expected);
    }
  });

  it('quantitative comparison keys must be one of the fixed options', () => {
    const bank = buildBank(bp);
    bank.keys.set('math_q1', { correct: 'E', explanation: null, wrong_option_notes: {}, solution_steps: [] });
    const problems = validateVariant({ blueprint: bp, ...bank });
    assert.deepEqual(problems.map((p) => [p.code, p.questionId]), [['key_invalid', 'math_q1']]);
  });

  it('flags a variant of another blueprint', () => {
    const bank = buildBank(blueprint('ort_subject_chemistry_2026'));
    assert.equal(validateVariant({ blueprint: bp, ...bank })[0]?.code, 'blueprint_mismatch');
  });
});

// CP-06: the pipeline writes part_id on every item, the CMS writes part_id:
// null in single-part sections, and auto-fill mixes both in one section.
describe('validateVariant part resolution (CP-06)', () => {
  /** Sets part_id to null on every `step`-th question of a section (CMS-style items). */
  function nullPartIds(bank: ReturnType<typeof buildBank>, sectionId: string, step = 2): string[] {
    const ids = bank.variant.sections.find((s) => s.section_id === sectionId)!.question_ids.filter((_, i) => i % step === 0);
    for (const id of ids) bank.questions.set(id, { ...bank.questions.get(id)!, part_id: null });
    return ids;
  }

  it('single-part subject section: pipeline items (part_id) mixed with CMS items (null) publish', () => {
    const chem = blueprint('ort_subject_chemistry_2026');
    assert.equal(chem.sections[0]!.parts.length, 1);
    const bank = buildBank(chem, 'ru', true);
    const cms = nullPartIds(bank, 'chemistry');
    assert.ok(cms.length > 0 && cms.length < 40);
    assert.deepEqual(validateVariant({ blueprint: chem, ...bank }), []);
  });

  it('every single-part subject blueprint accepts the mix', () => {
    for (const raw of rawBlueprints()) {
      const b = parseBlueprint(String(raw['id']), raw);
      const bank = buildBank(b, b.languages[0] ?? 'ru', true);
      for (const s of b.sections) if (s.parts.length === 1) nullPartIds(bank, s.id, 3);
      assert.deepEqual(validateVariant({ blueprint: b, ...bank }), [], b.id);
    }
  });

  it('main exam: reading and grammar (single-part) accept the mix next to explicit multi-part sections', () => {
    const bank = buildBank(bp, 'ru', true);
    nullPartIds(bank, 'reading');
    nullPartIds(bank, 'grammar', 1); // a section where every item is a CMS item
    assert.deepEqual(validateVariant({ blueprint: bp, ...bank }), []);
  });

  it('missing part_id read from Firestore (absent field or empty string) counts as missing', () => {
    const chem = blueprint('ort_subject_chemistry_2026');
    const bank = buildBank(chem, 'ru', true);
    const [a, b] = bank.variant.sections[0]!.question_ids;
    const { part_id: _drop, ...rest } = bank.questions.get(a!)!;
    void _drop;
    bank.questions.set(a!, parseQuestion(a!, { ...rest, review: { status: 'methodologist_approved' } }));
    bank.questions.set(b!, parseQuestion(b!, { ...bank.questions.get(b!)!, part_id: '', review: { status: 'methodologist_approved' } }));
    assert.equal(bank.questions.get(a!)!.part_id, null);
    assert.equal(bank.questions.get(b!)!.part_id, null);
    assert.deepEqual(validateVariant({ blueprint: chem, ...bank }), []);
  });

  it('multi-part section: a missing part_id next to explicit ones is still rejected', () => {
    const bank = buildBank(bp, 'ru', true);
    // math_q31 is a math_problems item; the rest of the section is explicit.
    bank.questions.set('math_q31', { ...bank.questions.get('math_q31')!, part_id: null });
    const problems = validateVariant({ blueprint: bp, ...bank });
    const wrong = problems.filter((p) => p.code === 'question_wrong_part');
    assert.deepEqual(wrong.map((p) => [p.sectionId, p.questionId, p.actual]), [['math', 'math_q31', null]]);
    assert.equal(wrong[0]!.expected, 'math_comparison,math_problems');
    assert.ok(problems.some((p) => p.code === 'part_count' && p.partId === 'math_problems' && p.actual === 29));
    assert.deepEqual(codes(problems), ['part_count', 'question_wrong_part']);
  });

  it('multi-part section: no type inference for a missing part_id (subject english, kyrgyz_lit)', () => {
    for (const [id, qid] of [
      ['ort_subject_english_2026', 'english_q45'], // text_based: the only text_based part
      ['ort_subject_kyrgyz_lit_2026', 'kyrgyz_lit_q1'], // two single_choice parts
    ] as const) {
      const b = blueprint(id);
      const bank = buildBank(b, b.languages[0] ?? 'ru', true);
      bank.questions.set(qid, { ...bank.questions.get(qid)!, part_id: null });
      const wrong = validateVariant({ blueprint: b, ...bank }).filter((p) => p.code === 'question_wrong_part');
      assert.deepEqual(wrong.map((p) => p.questionId), [qid], id);
    }
  });

  it('multi-part section with no part_id at all stays positional', () => {
    const bank = buildBank(bp, 'ru', true);
    nullPartIds(bank, 'math', 1);
    nullPartIds(bank, 'verbal', 1);
    assert.deepEqual(validateVariant({ blueprint: bp, ...bank }), []);
  });

  it('an explicit part_id must exist even in a single-part section', () => {
    const chem = blueprint('ort_subject_chemistry_2026');
    const bank = buildBank(chem, 'ru', true);
    bank.questions.set('chemistry_q2', { ...bank.questions.get('chemistry_q2')!, part_id: 'biology' });
    const problems = validateVariant({ blueprint: chem, ...bank });
    assert.deepEqual(
      problems.map((p) => [p.code, p.questionId ?? p.partId, p.actual]),
      [
        ['question_wrong_part', 'chemistry_q2', 'biology'],
        ['part_count', 'chemistry', 39],
      ],
    );
  });

  it('partForValidation', () => {
    const math = bp.sections.find((s) => s.id === 'math')!;
    const reading = bp.sections.find((s) => s.id === 'reading')!;
    assert.equal(partForValidation(reading, { part_id: null }, 5, true)?.id, 'reading');
    assert.equal(partForValidation(reading, { part_id: null }, 5, false)?.id, 'reading');
    assert.equal(partForValidation(reading, { part_id: 'reading' }, 5, true)?.id, 'reading');
    assert.equal(partForValidation(reading, { part_id: 'grammar' }, 5, true), undefined);
    assert.equal(partForValidation(math, { part_id: 'math_problems' }, 0, true)?.id, 'math_problems');
    assert.equal(partForValidation(math, { part_id: null }, 0, true), undefined);
    assert.equal(partForValidation(math, { part_id: null }, 0, false)?.id, 'math_comparison');
    assert.equal(partForValidation(math, { part_id: null }, 30, false)?.id, 'math_problems');
  });
});
