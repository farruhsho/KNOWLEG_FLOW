import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { validateVariant } from '../src/domain/blueprint_validation';
import { parseBlueprint } from '../src/domain/types';
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
