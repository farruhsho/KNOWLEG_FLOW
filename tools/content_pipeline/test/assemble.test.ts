import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { variantIdFor } from '../src/assemble';
import { Language } from '../src/schema';
import { estimateVariantTiming } from '../src/timing';
import { hasErrors, validateVariant, validateVariantSet } from '../src/validate';
import { dkey, languageMatrix } from '../src/matrix';
import { real, realBlueprint, realMatrix, syntheticBank } from './fixtures';
import { assembleMany, ctxFor } from './helpers';

const COMBOS: Array<[string, Language]> = real().blueprints.flatMap((bp) => bp.languages.map((l) => [bp.id, l] as [string, Language]));

describe('assemble against the real ORT 2026 blueprints (synthetic bank)', () => {
  it('covers every blueprint × language', () => {
    assert.equal(COMBOS.length, 16);
  });

  for (const [bpId, language] of COMBOS) {
    it(`${bpId} [${language}]: 2 variants, exact counts, no reuse, publishable, timing fits`, () => {
      const { items, passages } = syntheticBank(bpId, language, 2, { spare: 1 });
      const { files, failures } = assembleMany(bpId, language, items, passages, 2);
      assert.deepEqual(failures, []);
      assert.equal(files.length, 2);
      const bp = realBlueprint(bpId);
      const lm = languageMatrix(realMatrix(bpId), language);
      const ctx = ctxFor(items, passages);
      const itemMap = new Map(items.map((i) => [i.id, i]));
      const passageMap = new Map(passages.map((p) => [p.id, p]));
      for (const f of files) {
        assert.equal(f.id, variantIdFor(bpId, language, f.variant.number));
        assert.equal(f.variant.status, 'draft');
        assert.deepEqual(f.variant.sections.map((s) => s.section_id), [...bp.sections].sort((a, b) => a.order - b.order).map((s) => s.id));
        for (const s of bp.sections) {
          const vs = f.variant.sections.find((x) => x.section_id === s.id)!;
          assert.equal(vs.question_ids.length, s.question_count, `${s.id} count`);
          for (const part of s.parts) {
            const inPart = vs.question_ids.map((id) => itemMap.get(id)!).filter((it) => it.target.part_id === part.id);
            assert.equal(inPart.length, part.question_count, `${s.id}/${part.id} count`);
            const pm = lm.sections.find((x) => x.section_id === s.id)!.parts.find((x) => x.part_id === part.id)!;
            if (!pm.passage_plan) {
              // Standalone parts match the difficulty mix and topic targets exactly.
              for (const d of ['1', '2', '3'] as const) {
                assert.equal(inPart.filter((it) => dkey(it.question.difficulty) === d).length, pm.difficulty_counts[d], `${part.id} difficulty ${d}`);
              }
              for (const t of pm.topics) assert.equal(inPart.filter((it) => it.question.topic_id === t.topic_id).length, t.target, `${part.id} topic ${t.topic_id}`);
            } else {
              const passagesUsed = new Set(inPart.map((it) => it.question.passage_id).filter(Boolean));
              assert.equal(passagesUsed.size, pm.passage_plan.standalone_texts + pm.passage_plan.paired_texts, `${part.id} passages`);
              const paired = [...passagesUsed].filter((pid) => passageMap.get(pid!)!.layout === 'paired').length;
              assert.equal(paired, pm.passage_plan.paired_texts, `${part.id} paired passages`);
            }
          }
        }
        const problems = validateVariant(f.id, { ...f.variant, status: 'published' }, ctx, { publish: true, matrix: lm });
        assert.equal(hasErrors(problems), false, JSON.stringify(problems.filter((p) => p.severity === 'error'), null, 1));
        const timing = estimateVariantTiming(f.variant, bp, itemMap, passageMap);
        assert.equal(timing.fits, true, JSON.stringify(timing.sections));
      }
      const [a, b] = files.map((f) => new Set(f.variant.sections.flatMap((s) => s.question_ids)));
      for (const id of a!) assert.equal(b!.has(id), false, `item ${id} reused`);
      const set = validateVariantSet(files.map((f) => ({ id: f.id, variant: f.variant })), ctx, { allowReuse: false, requireLanguages: false });
      assert.equal(set.filter((p) => p.code === 'ITEM_REUSED').length, 0);
    });
  }

  it('reading: 2 standalone texts + 1 paired, 10 questions each, kept consecutive', () => {
    const { items, passages } = syntheticBank('ort_main_2026', 'ru', 1);
    const { files } = assembleMany('ort_main_2026', 'ru', items, passages, 1);
    const reading = files[0]!.variant.sections.find((s) => s.section_id === 'reading')!;
    const itemMap = new Map(items.map((i) => [i.id, i]));
    const runs: string[] = [];
    for (const id of reading.question_ids) {
      const pid = itemMap.get(id)!.question.passage_id!;
      if (runs.at(-1) !== pid) runs.push(pid);
    }
    assert.equal(runs.length, 3, 'each passage is one consecutive run');
    const layouts = runs.map((pid) => passages.find((p) => p.id === pid)!.layout).sort();
    assert.deepEqual(layouts, ['paired', 'standalone', 'standalone']);
    for (const pid of runs) assert.equal(reading.question_ids.filter((id) => itemMap.get(id)!.question.passage_id === pid).length, 10);
  });

  it('never reuses items: a bank for 2 variants cannot produce a 3rd unless --allow-reuse', () => {
    const { items, passages } = syntheticBank('ort_main_2026', 'ky', 2);
    const strict = assembleMany('ort_main_2026', 'ky', items, passages, 3);
    assert.equal(strict.files.length, 2);
    assert.equal(strict.failures.length, 1);
    assert.match(strict.failures[0]!.join('\n'), /cannot pick|need .* passages/);
    const reuse = assembleMany('ort_main_2026', 'ky', items, passages, 3, { allowReuse: true });
    assert.equal(reuse.files.length, 3);
  });

  it('drafts and rejected items are never used; ai_verified only with --allow-unapproved', () => {
    const verified = syntheticBank('ort_subject_chemistry_2026', 'ru', 1, { status: 'ai_verified' });
    assert.equal(assembleMany('ort_subject_chemistry_2026', 'ru', verified.items, verified.passages, 1).files.length, 0);
    const ok = assembleMany('ort_subject_chemistry_2026', 'ru', verified.items, verified.passages, 1, { allowUnapproved: true });
    assert.equal(ok.files.length, 1);
    assert.equal(ok.files[0]!.assembly.allow_unapproved, true);
    const drafts = syntheticBank('ort_subject_chemistry_2026', 'ru', 1, { status: 'draft' });
    assert.equal(assembleMany('ort_subject_chemistry_2026', 'ru', drafts.items, drafts.passages, 1, { allowUnapproved: true }).files.length, 0);
  });

  it('is deterministic for a given seed and bank', () => {
    const { items, passages } = syntheticBank('ort_subject_physics_2026', 'ky', 1, { spare: 2 });
    const a = assembleMany('ort_subject_physics_2026', 'ky', items, passages, 1).files[0]!;
    const b = assembleMany('ort_subject_physics_2026', 'ky', [...items].reverse(), passages, 1).files[0]!;
    assert.deepEqual(a.variant.sections, b.variant.sections);
  });

  it('falls back to topic ranges when exact cells are not available', () => {
    const { items, passages } = syntheticBank('ort_subject_biology_2026', 'ru', 1);
    // Move one difficulty-2 item of the first topic to another topic so exact cells fail.
    const lm = languageMatrix(realMatrix('ort_subject_biology_2026'), 'ru');
    const topics = lm.sections[0]!.parts[0]!.topics;
    const moved = items.find((i) => i.question.topic_id === topics[0]!.topic_id && i.question.difficulty === 2)!;
    moved.question.topic_id = topics[1]!.topic_id;
    const res = assembleMany('ort_subject_biology_2026', 'ru', items, passages, 1);
    assert.equal(res.files.length, 1);
    assert.equal(res.files[0]!.assembly.matrix_fit && (res.files[0]!.assembly.matrix_fit as Record<string, string>)['ort_subject_biology_2026/biology/biology'], 'topic_ranges');
  });
});
