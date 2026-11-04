import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { computeRegistry, registryMarkdown, TARGET_VARIANTS } from '../src/registry';
import { readFileSync } from 'node:fs';
import { bankItemsList, loadBank } from '../src/bank';
import { listFiles, readJson } from '../src/io';
import { BankItem, VariantFile } from '../src/schema';
import { real, REPO_PATHS, syntheticBank } from './fixtures';
import { assembleMany } from './helpers';

describe('registry', () => {
  const { blueprints } = real();

  it('empty content: zero everywhere, target 100 per blueprint × language', () => {
    const r = computeRegistry(blueprints, [], []);
    assert.equal(r.rows.length, 16);
    assert.equal(r.totals.target_variants, 16 * TARGET_VARIANTS);
    assert.equal(r.totals.drafted + r.totals.approved + r.totals.published + r.totals.items, 0);
    assert.equal(r.as_of, null);
    const main = r.rows.find((x) => x.blueprint_id === 'ort_main_2026' && x.language === 'ru')!;
    assert.equal(main.items_per_variant, 150);
    assert.equal(r.directions.length, 10);
    assert.equal(r.totals.target_numbers, 1000, '100 variants × 10 directions');
  });

  it('a variant number counts for its direction only when every language version is approved', () => {
    const ru = syntheticBank('ort_subject_biology_2026', 'ru', 2);
    const ky = syntheticBank('ort_subject_biology_2026', 'ky', 1);
    const ruFiles = assembleMany('ort_subject_biology_2026', 'ru', ru.items, ru.passages, 2).files;
    const kyFiles = assembleMany('ort_subject_biology_2026', 'ky', ky.items, ky.passages, 1).files;
    const r = computeRegistry(blueprints, [...ru.items, ...ky.items], [...ruFiles, ...kyFiles]);
    const d = r.directions.find((x) => x.blueprint_id === 'ort_subject_biology_2026')!;
    assert.deepEqual(d.languages, ['ru', 'ky']);
    assert.equal(d.approved_numbers, 1, 'number 2 exists only in Russian');
    assert.equal(d.published_numbers, 0);
    assert.match(registryMarkdown(r), /\| `ort_subject_biology_2026` \| ru, ky \| 100 \| 1 \| 0 \|/);
  });

  it('counts variants by the weakest review status of their items and items per stage', () => {
    const { items, passages } = syntheticBank('ort_subject_history_2026', 'ky', 3);
    const { files } = assembleMany('ort_subject_history_2026', 'ky', items, passages, 3);
    assert.equal(files.length, 3);
    // Variant 2: one item only ai_verified. Variant 3: published.
    const v2ids = new Set(files[1]!.variant.sections.flatMap((s) => s.question_ids));
    const downgraded = [...v2ids][0]!;
    const its: BankItem[] = items.map((i) => (i.id === downgraded ? { ...i, question: { ...i.question, review: { ...i.question.review, status: 'ai_verified' as const } } } : i));
    files[2]!.variant.status = 'published';
    files[2]!.variant.published_at = '2026-11-03T10:00:00.000Z';
    const extraDraft: BankItem = { ...items[0]!, id: 'q_ffffffffffffffffffff', question: { ...items[0]!.question, review: { ...items[0]!.question.review, status: 'draft' } } };
    const r = computeRegistry(blueprints, [...its, extraDraft], files);
    const row = r.rows.find((x) => x.blueprint_id === 'ort_subject_history_2026' && x.language === 'ky')!;
    assert.deepEqual(row.variants, { drafted: 3, ai_verified: 3, approved: 2, published: 1, archived: 0 });
    assert.equal(row.items.total, items.length + 1);
    assert.equal(row.items.ai_verified, 1);
    assert.equal(row.items.draft, 1);
    assert.equal(row.items.methodologist_approved, items.length - 1);
    const other = r.rows.find((x) => x.blueprint_id === 'ort_subject_history_2026' && x.language === 'ru')!;
    assert.equal(other.variants.drafted, 0, 'languages are counted separately');
    assert.equal(r.as_of, '2026-11-03T10:00:00.000Z');
    const md = registryMarkdown(r);
    assert.match(md, /\| `ort_subject_history_2026` \| ky \| 100 \| 3 \| 3 \| 2 \| 1 \| 40 \|/);
  });

  it('the committed content/registry.json and REGISTRY.md match the files under content/', () => {
    const bank = loadBank(REPO_PATHS.bank, { strict: true });
    const variants = listFiles(REPO_PATHS.variants, /^v_.*\.json$/).map((p) => VariantFile.parse(readJson(p)));
    const r = computeRegistry(blueprints, bankItemsList(bank), variants);
    assert.deepEqual(readJson(REPO_PATHS.registryJson), JSON.parse(JSON.stringify(r)), 'run `npm run cli -- registry`');
    assert.equal(readFileSync(REPO_PATHS.registryMd, 'utf8').replace(/\r\n/g, '\n'), registryMarkdown(r));
  });

  it('archived variants are not counted as drafted', () => {
    const { items, passages } = syntheticBank('ort_subject_physics_2026', 'ru', 1);
    const { files } = assembleMany('ort_subject_physics_2026', 'ru', items, passages, 1);
    files[0]!.variant.status = 'archived';
    const row = computeRegistry(blueprints, items, files).rows.find((x) => x.blueprint_id === 'ort_subject_physics_2026' && x.language === 'ru')!;
    assert.equal(row.variants.drafted, 0);
    assert.equal(row.variants.archived, 1);
  });
});
