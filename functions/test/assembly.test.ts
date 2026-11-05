import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { assembleFreshVariant, poolHealth, statusesAtLeast, type AssembleFreshInput, type PoolItem } from '../src/domain/assembly';
import { DIFFICULTIES, dkey, matrixProblems } from '../src/domain/exam_matrix';
import { combos, realMatrix, realSections, shuffled, synthBank, type SynthBank } from './assembly_fixtures';

function input(bpId: string, language: string, bank: SynthBank, extra: Partial<AssembleFreshInput> = {}): AssembleFreshInput {
  return {
    sections: realSections(bpId),
    matrix: realMatrix(bpId, language),
    pool: bank.items,
    passages: bank.passages,
    lastSeen: new Map(),
    seed: 'seed-1',
    ...extra,
  };
}

function ok(r: ReturnType<typeof assembleFreshVariant>) {
  if (!r.ok) assert.fail(`assembly failed at ${r.section_id}/${r.part_id}: ${r.problems.join('; ')}`);
  return r;
}

const byId = (bank: SynthBank) => new Map(bank.items.map((i) => [i.id, i]));

describe('topic matrices (content/matrix) fit the real blueprints', () => {
  it('covers every blueprint × language', () => {
    assert.equal(combos().length, 16);
  });
  for (const [bpId, language] of combos()) {
    it(`${bpId} [${language}]`, () => {
      assert.deepEqual(matrixProblems(realMatrix(bpId, language), realSections(bpId)), []);
    });
  }

  it('reports a part whose question count differs', () => {
    const sections = realSections('ort_subject_chemistry_2026').map((s) => ({ ...s, parts: s.parts.map((p) => ({ ...p, question_count: 41 })) }));
    assert.match(matrixProblems(realMatrix('ort_subject_chemistry_2026', 'ru'), sections)[0]!, /41/);
  });
});

describe('assembleFreshVariant on the real ORT 2026 blueprints', () => {
  for (const [bpId, language] of combos()) {
    it(`${bpId} [${language}]: exact counts, matrix, difficulty mix, passage layout`, () => {
      const bank = synthBank(bpId, language, { copies: 2 });
      const items = byId(bank);
      const r = ok(assembleFreshVariant(input(bpId, language, bank)));
      const matrix = realMatrix(bpId, language);
      const sections = realSections(bpId);
      assert.deepEqual(r.sections.map((s) => s.section_id), sections.map((s) => s.id));
      for (const s of sections) {
        const ids = r.sections.find((x) => x.section_id === s.id)!.question_ids;
        assert.equal(ids.length, s.question_count, `${s.id} count`);
        assert.equal(new Set(ids).size, ids.length, `${s.id} no duplicates`);
        let offset = 0;
        for (const p of s.parts) {
          const inPart = ids.slice(offset, offset + p.question_count).map((id) => items.get(id)!);
          offset += p.question_count;
          assert.ok(inPart.every((it) => it.part_id === p.id), `${s.id}/${p.id}: parts are laid out consecutively`);
          const pm = matrix.get(`${s.id}/${p.id}`)!;
          if (!pm.passage_plan) {
            assert.equal(r.fit[`${s.id}/${p.id}`], 'exact_cells');
            for (const d of DIFFICULTIES) {
              assert.equal(inPart.filter((it) => it.difficulty === d).length, pm.difficulty_counts[dkey(d)], `${p.id} difficulty ${d}`);
            }
            for (const t of pm.topics) assert.equal(inPart.filter((it) => it.topic_id === t.topic_id).length, t.target, `${p.id} topic ${t.topic_id}`);
            // easy → hard
            for (let i = 1; i < inPart.length; i++) assert.ok(inPart[i - 1]!.difficulty <= inPart[i]!.difficulty, `${p.id} easy→hard at ${i}`);
          } else {
            const plan = pm.passage_plan;
            const used = [...new Set(inPart.map((it) => it.passage_id).filter((x): x is string => !!x))];
            assert.equal(used.length, plan.standalone_texts + plan.paired_texts, `${p.id} texts`);
            assert.equal(used.filter((pid) => bank.passages.get(pid)!.layout === 'paired').length, plan.paired_texts, `${p.id} paired texts`);
          }
        }
      }
      assert.deepEqual(r.freshness, { total: sections.reduce((a, s) => a + s.question_count, 0), repeated: 0 });
      assert.deepEqual(r.repeated_parts, []);
    });
  }

  it('reading: 2 standalone texts then 1 paired, 10 questions each, each text consecutive and in text order', () => {
    const bank = synthBank('ort_main_2026', 'ru', { copies: 2 });
    const items = byId(bank);
    const r = ok(assembleFreshVariant(input('ort_main_2026', 'ru', bank)));
    const reading = r.sections.find((s) => s.section_id === 'reading')!.question_ids.map((id) => items.get(id)!);
    const runs: string[] = [];
    for (const it of reading) if (runs.at(-1) !== it.passage_id) runs.push(it.passage_id!);
    assert.equal(runs.length, 3, 'each passage is one consecutive run');
    assert.deepEqual(runs.map((pid) => bank.passages.get(pid)!.layout), ['standalone', 'standalone', 'paired']);
    for (const pid of runs) {
      const group = reading.filter((it) => it.passage_id === pid);
      assert.equal(group.length, 10);
      assert.deepEqual(group.map((it) => it.passage_order), [...group.map((it) => it.passage_order)].sort((a, b) => a! - b!), 'text order');
    }
    assert.equal(r.fit['reading/reading'], 'passages');
  });

  it('mixed part (russian_language: 15 standalone + 1 text of 5): standalone easy→hard first, then the text', () => {
    const bank = synthBank('ort_subject_russian_lit_2026', 'ru', { copies: 2 });
    const items = byId(bank);
    const r = ok(assembleFreshVariant(input('ort_subject_russian_lit_2026', 'ru', bank)));
    const part = r.sections[0]!.question_ids.slice(0, 20).map((id) => items.get(id)!);
    assert.ok(part.slice(0, 15).every((it) => it.passage_id === null));
    assert.ok(part.slice(15).every((it) => it.passage_id !== null));
    assert.equal(new Set(part.slice(15).map((it) => it.passage_id)).size, 1);
    for (let i = 1; i < 15; i++) assert.ok(part[i - 1]!.difficulty <= part[i]!.difficulty);
  });
});

describe('assembleFreshVariant: exact fit and shortages', () => {
  it('a pool of exactly one variant is used completely (exact cells)', () => {
    const bank = synthBank('ort_subject_chemistry_2026', 'ru', { copies: 1 });
    const r = ok(assembleFreshVariant(input('ort_subject_chemistry_2026', 'ru', bank)));
    assert.deepEqual(new Set(r.sections[0]!.question_ids), new Set(bank.items.map((i) => i.id)));
    assert.equal(r.fit['chemistry/chemistry'], 'exact_cells');
    assert.deepEqual(r.freshness, { total: 40, repeated: 0 });
  });

  it('the whole main test from exactly one variant worth of items (all four sections)', () => {
    const bank = synthBank('ort_main_2026', 'ky', { copies: 1 });
    const r = ok(assembleFreshVariant(input('ort_main_2026', 'ky', bank)));
    assert.equal(r.freshness.total, 150);
    assert.equal(new Set(r.sections.flatMap((s) => s.question_ids)).size, 150);
  });

  it('falls back to topic ranges when an exact cell is short (one item less in a cell)', () => {
    const bank = synthBank('ort_subject_chemistry_2026', 'ru', { copies: 1 });
    // chemistry.general d1 has 3 items; drop one and add a spare d1 item in another topic.
    const dropped = bank.items.filter((i) => !(i.topic_id === 'chemistry.general' && i.difficulty === 1 && i.id.endsWith('_0')));
    const spare: PoolItem = { ...bank.items.find((i) => i.topic_id === 'chemistry.inorganic' && i.difficulty === 1)!, id: 'spare_inorganic_d1' };
    const r = ok(assembleFreshVariant(input('ort_subject_chemistry_2026', 'ru', { ...bank, items: [...dropped, spare] })));
    assert.equal(r.fit['chemistry/chemistry'], 'topic_ranges');
    assert.equal(r.sections[0]!.question_ids.length, 40);
  });

  it('POOL_TOO_SMALL names the first part that cannot be filled (no hard items at all)', () => {
    const bank = synthBank('ort_subject_chemistry_2026', 'ru', { copies: 3 });
    const r = assembleFreshVariant(input('ort_subject_chemistry_2026', 'ru', { ...bank, items: bank.items.filter((i) => i.difficulty !== 3) }));
    assert.equal(r.ok, false);
    if (r.ok) return;
    assert.deepEqual([r.section_id, r.part_id], ['chemistry', 'chemistry']);
    assert.ok(r.problems.some((p) => /cannot pick 40 standalone items/.test(p)), r.problems.join());
  });

  it('POOL_TOO_SMALL for an empty pool stops at the first part of the first section', () => {
    const r = assembleFreshVariant(input('ort_main_2026', 'ru', { items: [], passages: new Map() }));
    assert.equal(r.ok, false);
    if (!r.ok) assert.deepEqual([r.section_id, r.part_id], ['math', 'math_comparison']);
  });

  it('POOL_TOO_SMALL in reading when the paired text is missing', () => {
    const bank = synthBank('ort_main_2026', 'ru', { copies: 1 });
    const paired = [...bank.passages.values()].find((p) => p.layout === 'paired')!.id;
    const r = assembleFreshVariant(input('ort_main_2026', 'ru', { ...bank, items: bank.items.filter((i) => i.passage_id !== paired) }));
    assert.equal(r.ok, false);
    if (!r.ok) {
      assert.deepEqual([r.section_id, r.part_id], ['reading', 'reading']);
      assert.match(r.problems.join(), /2 standalone \+ 1 paired/);
    }
  });

  it('passages without a stored layout may fill either kind of text slot', () => {
    const bank = synthBank('ort_main_2026', 'ru', { copies: 1, layout: false });
    const r = ok(assembleFreshVariant(input('ort_main_2026', 'ru', bank)));
    assert.equal(r.sections.find((s) => s.section_id === 'reading')!.question_ids.length, 30);
  });

  it('never uses items of other slots, other topics or without a valid difficulty', () => {
    const bank = synthBank('ort_subject_chemistry_2026', 'ru', { copies: 1 });
    const intruders: PoolItem[] = [
      { ...bank.items[0]!, id: 'zz_other_part', part_id: 'biology' },
      { ...bank.items[0]!, id: 'zz_off_matrix', topic_id: 'chemistry.not_in_matrix' },
      { ...bank.items[0]!, id: 'zz_bad_difficulty', difficulty: 4 },
    ];
    const r = ok(assembleFreshVariant(input('ort_subject_chemistry_2026', 'ru', { ...bank, items: [...bank.items, ...intruders] })));
    assert.ok(r.sections[0]!.question_ids.every((id) => !id.startsWith('zz_')));
  });
});

describe('assembleFreshVariant: freshness (unseen first, then least recently seen)', () => {
  const BP = 'ort_subject_chemistry_2026';

  it('prefers unseen items: with two disjoint variants in the pool and one seen, the other is chosen', () => {
    const a = synthBank(BP, 'ru', { copies: 1, prefix: 'a' });
    const b = synthBank(BP, 'ru', { copies: 1, prefix: 'b' });
    const lastSeen = new Map(a.items.map((i) => [i.id, 1_000]));
    const r = ok(assembleFreshVariant(input(BP, 'ru', { items: [...a.items, ...b.items], passages: new Map() }, { lastSeen })));
    assert.deepEqual(new Set(r.sections[0]!.question_ids), new Set(b.items.map((i) => i.id)));
    assert.deepEqual(r.freshness, { total: 40, repeated: 0 });
  });

  it('when every item was seen, the least recently seen are taken first', () => {
    const a = synthBank(BP, 'ru', { copies: 1, prefix: 'a' });
    const b = synthBank(BP, 'ru', { copies: 1, prefix: 'b' });
    const lastSeen = new Map([...a.items.map((i) => [i.id, 2_000] as const), ...b.items.map((i) => [i.id, 1_000] as const)]);
    const r = ok(assembleFreshVariant(input(BP, 'ru', { items: [...a.items, ...b.items], passages: new Map() }, { lastSeen })));
    assert.deepEqual(new Set(r.sections[0]!.question_ids), new Set(b.items.map((i) => i.id)), 'b was seen longer ago');
    assert.deepEqual(r.freshness, { total: 40, repeated: 40 });
    assert.deepEqual(r.repeated_parts, ['chemistry/chemistry']);
  });

  it('a 1.5× pool after one attempt: every unseen item is used and only the shortfall is repeated', () => {
    const one = synthBank(BP, 'ru', { copies: 1, prefix: 'a' });
    const half = synthBank(BP, 'ru', { copies: 1, prefix: 'b' });
    const matrix = realMatrix(BP, 'ru');
    // Keep ceil(n/2) of every b-cell: unseen items cover only part of each cell.
    const keep = new Set<string>();
    for (const t of matrix.get('chemistry/chemistry')!.topics) {
      for (const d of DIFFICULTIES) {
        const cell = half.items.filter((i) => i.topic_id === t.topic_id && i.difficulty === d);
        cell.slice(0, Math.ceil(cell.length / 2)).forEach((i) => keep.add(i.id));
      }
    }
    const unseen = half.items.filter((i) => keep.has(i.id));
    const lastSeen = new Map(one.items.map((i) => [i.id, 5_000]));
    const r = ok(assembleFreshVariant(input(BP, 'ru', { items: [...one.items, ...unseen], passages: new Map() }, { lastSeen })));
    const ids = new Set(r.sections[0]!.question_ids);
    for (const u of unseen) assert.ok(ids.has(u.id), `unseen ${u.id} used`);
    assert.equal(r.freshness.repeated, 40 - unseen.length);
    assert.equal(r.fit['chemistry/chemistry'], 'exact_cells');
  });

  it('freshness wins over the exact tier: unseen items in topic ranges beat exact cells with repeats', () => {
    const seen = synthBank(BP, 'ru', { copies: 1, prefix: 'a' });
    const fresh = synthBank(BP, 'ru', { copies: 1, prefix: 'b' });
    // Move one fresh general/d1 item to inorganic/d1: exact cells are impossible without a repeat, ranges are not.
    const moved = fresh.items.map((i) => (i.topic_id === 'chemistry.general' && i.difficulty === 1 && i.id.endsWith('_0') ? { ...i, topic_id: 'chemistry.inorganic' } : i));
    const lastSeen = new Map(seen.items.map((i) => [i.id, 1_000]));
    const r = ok(assembleFreshVariant(input(BP, 'ru', { items: [...seen.items, ...moved], passages: new Map() }, { lastSeen })));
    assert.equal(r.freshness.repeated, 0);
    assert.equal(r.fit['chemistry/chemistry'], 'topic_ranges');
  });

  it('passages: an unseen text is preferred; a seen text is avoided entirely while unseen ones suffice', () => {
    const bank = synthBank('ort_main_2026', 'ru', { copies: 2 });
    const items = byId(bank);
    const first = ok(assembleFreshVariant(input('ort_main_2026', 'ru', bank, { seed: 'first' })));
    const lastSeen = new Map(first.sections.flatMap((s) => s.question_ids).map((id) => [id, 1_000]));
    const second = ok(assembleFreshVariant(input('ort_main_2026', 'ru', bank, { seed: 'second', lastSeen })));
    assert.deepEqual(second.freshness, { total: 150, repeated: 0 });
    const textsOf = (r: typeof first) => new Set(r.sections.find((s) => s.section_id === 'reading')!.question_ids.map((id) => items.get(id)!.passage_id));
    for (const pid of textsOf(second)) assert.ok(!textsOf(first).has(pid), `text ${pid} repeated`);
  });
});

describe('assembleFreshVariant: determinism and order', () => {
  const BP = 'ort_subject_biology_2026';

  it('same pool (in any order), seen map and seed -> the same variant', () => {
    const bank = synthBank(BP, 'ky', { copies: 3 });
    const r1 = ok(assembleFreshVariant(input(BP, 'ky', bank, { seed: 'abc' })));
    const r2 = ok(assembleFreshVariant(input(BP, 'ky', { ...bank, items: shuffled(bank.items, 99) }, { seed: 'abc' })));
    assert.deepEqual(r1.sections, r2.sections);
  });

  it('different seeds give different variants from a large pool', () => {
    const bank = synthBank(BP, 'ky', { copies: 3 });
    const variants = ['s1', 's2', 's3'].map((seed) => ok(assembleFreshVariant(input(BP, 'ky', bank, { seed }))).sections[0]!.question_ids.join());
    assert.equal(new Set(variants).size, 3);
  });

  it('easy → hard inside every standalone part; ties broken by the seed (not by topic)', () => {
    const bank = synthBank(BP, 'ru', { copies: 2 });
    const items = byId(bank);
    const ids = ok(assembleFreshVariant(input(BP, 'ru', bank, { seed: 'order' }))).sections[0]!.question_ids;
    const ds = ids.map((id) => items.get(id)!.difficulty);
    assert.deepEqual(ds, [...ds].sort((a, b) => a - b));
    const easyTopics = ids.filter((id) => items.get(id)!.difficulty === 1).map((id) => items.get(id)!.topic_id);
    const grouped = easyTopics.every((t, i) => i === 0 || t === easyTopics[i - 1] || !easyTopics.slice(0, i - 1).includes(t));
    assert.equal(grouped, false, 'topics are mixed within a difficulty level');
  });
});

describe('statusesAtLeast', () => {
  it('maps config/exam_pool.min_review_status to the accepted statuses (never drafts)', () => {
    assert.deepEqual(statusesAtLeast('methodologist_approved'), ['methodologist_approved']);
    assert.deepEqual(statusesAtLeast('ai_verified'), ['ai_verified', 'methodologist_approved']);
    assert.deepEqual(statusesAtLeast('draft'), ['ai_verified', 'methodologist_approved']);
  });
});

describe('poolHealth', () => {
  it('counts fully disjoint variants; the shortfalls describe the next variant', () => {
    const bank = synthBank('ort_subject_chemistry_2026', 'ru', { copies: 3 });
    const h = poolHealth({ sections: realSections('ort_subject_chemistry_2026'), matrix: realMatrix('ort_subject_chemistry_2026', 'ru'), pool: bank.items, passages: bank.passages });
    assert.equal(h.disjoint_variants, 3);
    assert.equal(h.capped, false);
    // Every cell is empty for variant 4.
    const cells = realMatrix('ort_subject_chemistry_2026', 'ru').get('chemistry/chemistry')!.topics.flatMap((t) => DIFFICULTIES.filter((d) => t.difficulty_targets[dkey(d)] > 0));
    assert.equal(h.shortfalls.length, cells.length);
    assert.ok(h.shortfalls.every((s) => s.kind === 'cell' && s.available === 0));
  });

  it('names the missing cell when a topic has no hard items', () => {
    const bank = synthBank('ort_subject_chemistry_2026', 'ru', { copies: 1 });
    // Without calculations/d3 the 8 hard questions of the part cannot be met (only 6 left).
    const items = bank.items.filter((i) => !(i.topic_id === 'chemistry.calculations' && i.difficulty === 3));
    const h = poolHealth({ sections: realSections('ort_subject_chemistry_2026'), matrix: realMatrix('ort_subject_chemistry_2026', 'ru'), pool: items, passages: bank.passages });
    assert.equal(h.disjoint_variants, 0);
    assert.ok(h.shortfalls.some((s) => s.kind === 'cell' && s.topic_id === 'chemistry.calculations' && s.difficulty === 3 && s.available === 0));
  });

  it('reports passages by layout and a paired-text shortfall for the main test', () => {
    const bank = synthBank('ort_main_2026', 'ru', { copies: 1 });
    const h = poolHealth({ sections: realSections('ort_main_2026'), matrix: realMatrix('ort_main_2026', 'ru'), pool: bank.items, passages: bank.passages });
    assert.equal(h.disjoint_variants, 1);
    const reading = h.parts.find((p) => p.part_id === 'reading')!;
    assert.deepEqual(reading.passages, { standalone: 2, paired: 1, unknown: 0 });
    assert.ok(h.shortfalls.some((s) => s.kind === 'passages' && s.layout === 'paired' && s.needed === 1 && s.available === 0));
  });

  it('caps the simulation', () => {
    const bank = synthBank('ort_subject_chemistry_2026', 'ru', { copies: 3 });
    const h = poolHealth({ sections: realSections('ort_subject_chemistry_2026'), matrix: realMatrix('ort_subject_chemistry_2026', 'ru'), pool: bank.items, passages: bank.passages, maxVariants: 2 });
    assert.equal(h.disjoint_variants, 2);
    assert.equal(h.capped, true);
  });
});

describe('the pilot bank (content/bank/pilot_main_ru_v1_*, emulator seed)', () => {
  interface BankFile {
    passages?: Array<{ id: string; layout: 'standalone' | 'paired' }>;
    items: Array<{
      id: string;
      target: { section_id: string; part_id: string };
      passage_order: number | null;
      question: { topic_id: string; difficulty: number; passage_id: string | null; review: { status: string } };
    }>;
  }

  function pilot(withLayout: boolean): SynthBank {
    const dir = path.resolve(__dirname, '..', '..', 'content', 'bank');
    const items: PoolItem[] = [];
    const passages: SynthBank['passages'] = new Map();
    for (const d of readdirSync(dir).filter((x) => x.startsWith('pilot_main_ru_v1_'))) {
      const f = JSON.parse(readFileSync(path.join(dir, d, 'items.json'), 'utf8')) as BankFile;
      for (const p of f.passages ?? []) passages.set(p.id, { id: p.id, layout: withLayout ? p.layout : 'unknown' });
      for (const it of f.items) {
        items.push({
          id: it.id,
          section_id: it.target.section_id,
          part_id: it.target.part_id,
          topic_id: it.question.topic_id,
          difficulty: it.question.difficulty,
          passage_id: it.question.passage_id,
          passage_order: withLayout ? it.passage_order : null,
          review_status: it.question.review.status,
        });
      }
    }
    return { items, passages };
  }

  it('assembles exactly one complete ort_main_2026 ru variant from the 150 ai_verified items', () => {
    const bank = pilot(true);
    assert.equal(bank.items.length, 150);
    const r = ok(assembleFreshVariant(input('ort_main_2026', 'ru', bank)));
    assert.deepEqual(r.freshness, { total: 150, repeated: 0 });
    for (const part of ['math/math_comparison', 'math/math_problems', 'verbal/analogies', 'verbal/completion', 'grammar/grammar']) {
      assert.equal(r.fit[part], 'exact_cells', part);
    }
    const items = byId(bank);
    const reading = r.sections.find((s) => s.section_id === 'reading')!.question_ids.map((id) => items.get(id)!);
    assert.equal(bank.passages.get(reading.at(-1)!.passage_id!)!.layout, 'paired', 'the paired text comes last');
    // A second attempt can only repeat, and says so.
    const lastSeen = new Map(r.sections.flatMap((s) => s.question_ids).map((id) => [id, 1]));
    assert.deepEqual(ok(assembleFreshVariant(input('ort_main_2026', 'ru', bank, { lastSeen, seed: 'again' }))).freshness, { total: 150, repeated: 150 });
  });

  it('still assembles when the import carries no passage layout / order (pipeline importer today)', () => {
    ok(assembleFreshVariant(input('ort_main_2026', 'ru', pilot(false))));
  });

  it('questions without passage_order keep a stable text order (by id), whatever the seed', () => {
    const bank = pilot(false);
    const items = byId(bank);
    const orders = ['s1', 's2', 's3'].map((seed) => {
      const reading = ok(assembleFreshVariant(input('ort_main_2026', 'ru', bank, { seed }))).sections.find((s) => s.section_id === 'reading')!.question_ids;
      const groups = new Map<string, string[]>();
      for (const id of reading) {
        const pid = items.get(id)!.passage_id!;
        groups.set(pid, [...(groups.get(pid) ?? []), id]);
      }
      for (const ids of groups.values()) assert.deepEqual(ids, [...ids].sort(), 'by id inside each text');
      return groups;
    });
    for (const [pid, ids] of orders[0]!) assert.deepEqual(orders[1]!.get(pid), ids, `${pid}: same order for another seed`);
  });
});
