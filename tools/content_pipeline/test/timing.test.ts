import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { estimateItemSeconds, estimateVariantTiming, itemWords, passageSeconds } from '../src/timing';
import { wordCount } from '../src/text';
import { real, realBlueprint, syntheticBank } from './fixtures';
import { assembleMany } from './helpers';

describe('timing', () => {
  it('counts words without LaTeX commands', () => {
    assert.equal(wordCount('Найдите $\\frac{3}{4} + x$ сейчас'), 5);
    assert.equal(wordCount('Төрт жүз жыйырма'), 3);
  });

  it('harder and longer items take longer', () => {
    const { items } = syntheticBank('ort_main_2026', 'ru', 1);
    const prob = items.find((i) => i.target.part_id === 'math_problems' && i.question.difficulty === 1)!;
    const hard = { ...prob.question, difficulty: 3 as const };
    assert.ok(estimateItemSeconds(hard) > estimateItemSeconds(prob.question));
    const long = { ...prob.question, stem: `${prob.question.stem} ${'слово '.repeat(150)}` };
    assert.ok(itemWords(long) > itemWords(prob.question));
    assert.ok(estimateItemSeconds(long) - estimateItemSeconds(prob.question) >= 40, 'roughly a minute of extra reading for 150 words');
    const qc = items.find((i) => i.question.type === 'quantitative_comparison')!;
    assert.ok(estimateItemSeconds(qc.question) < estimateItemSeconds(prob.question), 'comparison items are faster than problems');
  });

  it('passage reading time grows with length', () => {
    const { passages } = syntheticBank('ort_main_2026', 'ru', 1);
    const paired = passages.find((p) => p.layout === 'paired')!;
    const single = passages.find((p) => p.layout === 'standalone')!;
    assert.ok(passageSeconds(paired) > passageSeconds(single));
  });

  for (const bp of real().blueprints) {
    it(`${bp.id}: a typical variant fits every section with a 10 % margin`, () => {
      const language = bp.languages[0]!;
      const { items, passages } = syntheticBank(bp.id, language, 1);
      const { files } = assembleMany(bp.id, language, items, passages, 1);
      const t = estimateVariantTiming(files[0]!.variant, realBlueprint(bp.id), new Map(items.map((i) => [i.id, i])), new Map(passages.map((p) => [p.id, p])));
      assert.equal(t.fits, true, JSON.stringify(t.sections));
      for (const s of t.sections) {
        assert.equal(s.duration_minutes, bp.sections.find((x) => x.id === s.section_id)!.duration_minutes);
        assert.ok(s.estimated_minutes > s.duration_minutes * 0.3, `${s.section_id}: estimate ${s.estimated_minutes} looks implausibly low`);
      }
    });
  }

  it('reports a section that does not fit and missing items', () => {
    const { items, passages } = syntheticBank('ort_main_2026', 'ru', 1);
    const { files } = assembleMany('ort_main_2026', 'ru', items, passages, 1);
    const v = structuredClone(files[0]!.variant);
    const map = new Map(items.map((i) => [i.id, i]));
    // Inflate every verbal item to a 300-word stem: 30 such items cannot be read in 30 minutes.
    for (const id of v.sections.find((s) => s.section_id === 'verbal')!.question_ids) {
      const it = map.get(id)!;
      map.set(id, { ...it, question: { ...it.question, stem: `${it.question.stem} ${'длинный '.repeat(300)}` } });
    }
    v.sections[0]!.question_ids[0] = 'q_missing00000000000';
    const t = estimateVariantTiming(v, realBlueprint('ort_main_2026'), map, new Map(passages.map((p) => [p.id, p])));
    assert.equal(t.fits, false);
    assert.equal(t.sections.find((s) => s.section_id === 'verbal')!.fits, false);
    assert.equal(t.sections.find((s) => s.section_id === 'math')!.fits, true);
    assert.deepEqual(t.missing_items, ['q_missing00000000000']);
  });
});
