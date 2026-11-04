import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { join } from 'node:path';
import { apportion, boundedMatrix } from '../src/flow';
import { readJson } from '../src/io';
import { bankTargets, BlueprintMatrix, buildBlueprintMatrix, difficultyCounts, topicRange } from '../src/matrix';
import { real, REPO_PATHS } from './fixtures';

describe('flow helpers', () => {
  it('apportion keeps the total and follows the weights', () => {
    assert.deepEqual(apportion(30, [0.3, 0.5, 0.2]), [9, 15, 6]);
    assert.deepEqual(apportion(15, [0.3, 0.5, 0.2]), [4, 8, 3]);
    assert.equal(apportion(7, [1, 1, 1]).reduce((a, b) => a + b, 0), 7);
    assert.deepEqual(apportion(5, [0, 0]), [0, 0]);
  });

  it('boundedMatrix finds an integer matrix with exact margins or reports infeasibility', () => {
    const x = boundedMatrix([{ lo: 3, hi: 3 }, { lo: 2, hi: 2 }], [{ lo: 1, hi: 1 }, { lo: 4, hi: 4 }], [[0, 0], [0, 0]], [[1, 3], [1, 2]])!;
    assert.deepEqual(x.map((r) => r.reduce((a, b) => a + b, 0)), [3, 2]);
    assert.deepEqual([x[0]![0]! + x[1]![0]!, x[0]![1]! + x[1]![1]!], [1, 4]);
    assert.equal(boundedMatrix([{ lo: 5, hi: 5 }], [{ lo: 5, hi: 5 }], [[0]], [[4]]), null);
  });
});

describe('matrix stage on the real blueprints and curriculum', () => {
  const { blueprints, curriculum } = real();

  it('difficulty counts follow the 30/50/20 mix exactly', () => {
    assert.deepEqual(difficultyCounts(30, { '1': 0.3, '2': 0.5, '3': 0.2 }), { '1': 9, '2': 15, '3': 6 });
    assert.deepEqual(difficultyCounts(40, { '1': 0.3, '2': 0.5, '3': 0.2 }), { '1': 12, '2': 20, '3': 8 });
    assert.deepEqual(topicRange(6), { min: 4, max: 8 });
    assert.deepEqual(topicRange(1), { min: 0, max: 2 });
  });

  for (const bp of blueprints) {
    it(`${bp.id}: every part is fully covered by topics, rows and columns add up, no warnings`, () => {
      const m = buildBlueprintMatrix(bp, curriculum);
      assert.deepEqual(m.warnings, []);
      assert.deepEqual(m.languages.map((l) => l.language), bp.languages);
      for (const lm of m.languages) {
        for (const s of lm.sections) {
          const bs = bp.sections.find((x) => x.id === s.section_id)!;
          assert.equal(s.parts.reduce((a, p) => a + p.question_count, 0), bs.question_count);
          for (const p of s.parts) {
            assert.ok(p.topics.length > 0, `${p.slot}: no topics`);
            assert.equal(p.topics.reduce((a, t) => a + t.target, 0), p.question_count, `${p.slot} topic targets`);
            const dc = p.difficulty_counts;
            assert.equal(dc['1'] + dc['2'] + dc['3'], p.question_count);
            for (const d of ['1', '2', '3'] as const) {
              assert.equal(p.topics.reduce((a, t) => a + t.difficulty_targets[d], 0), dc[d], `${p.slot} column ${d}`);
            }
            for (const t of p.topics) {
              const row = t.difficulty_targets['1'] + t.difficulty_targets['2'] + t.difficulty_targets['3'];
              assert.equal(row, t.target, `${p.slot} ${t.topic_id} row`);
              assert.ok(t.min <= t.target && t.target <= t.max);
              assert.ok(t.grades[0] >= 5 && t.grades[1] <= 11, `${t.topic_id}: grades of the KR school programme`);
            }
            if (p.item_type === 'text_based') assert.ok(p.passage_plan, `${p.slot}: text_based part needs a passage plan`);
            if (p.item_type === 'quantitative_comparison') assert.equal(p.fixed_options, true);
          }
        }
      }
    });
  }

  it('grammar topics are language-specific in the main test', () => {
    const m = buildBlueprintMatrix(blueprints.find((b) => b.id === 'ort_main_2026')!, curriculum);
    for (const lm of m.languages) {
      const grammar = lm.sections.find((s) => s.section_id === 'grammar')!.parts[0]!;
      assert.ok(grammar.topics.every((t) => t.topic_id.startsWith(`grammar_${lm.language}.`)), lm.language);
      assert.equal(grammar.topics.length, 6, 'the 6 task types of the blueprint');
    }
  });

  it('reading: 2 standalone + 1 paired text, 10 questions each', () => {
    const m = buildBlueprintMatrix(blueprints.find((b) => b.id === 'ort_main_2026')!, curriculum);
    const plan = m.languages[0]!.sections.find((s) => s.section_id === 'reading')!.parts[0]!.passage_plan!;
    assert.equal(plan.standalone_texts, 2);
    assert.equal(plan.paired_texts, 1);
    assert.equal(plan.questions_per_text, 10);
  });

  it('bank targets scale per variant with overgeneration', () => {
    const m = buildBlueprintMatrix(blueprints.find((b) => b.id === 'ort_subject_chemistry_2026')!, curriculum);
    const t = bankTargets(m, 'ru', 100, 1.3);
    assert.equal(t.reduce((a, c) => a + c.per_variant, 0), 40);
    assert.ok(t.reduce((a, c) => a + c.bank_target, 0) >= 40 * 100 * 1.3);
  });

  it('the committed content/matrix files match the current catalog', () => {
    for (const bp of blueprints) {
      const committed = readJson<BlueprintMatrix>(join(REPO_PATHS.matrix, `${bp.id}.json`));
      assert.deepEqual(committed, JSON.parse(JSON.stringify(buildBlueprintMatrix(bp, curriculum))), `${bp.id}: run \`npm run cli -- matrix\``);
    }
  });
});
