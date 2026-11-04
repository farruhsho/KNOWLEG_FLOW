/** End-to-end run of the free stages through the CLI in a temporary repo root. */
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { main, parseArgs } from '../src/cli';
import { readJson, writeJsonAtomic } from '../src/io';
import { BankFile, VariantFile } from '../src/schema';
import { captureOut, syntheticBank, tempRepo } from './fixtures';
import { FakeFirestore } from './helpers';

const BP = 'ort_subject_chemistry_2026';

async function run(root: string, ...args: string[]): Promise<{ code: number; text: string }> {
  const { out, lines } = captureOut();
  const code = await main([...args, '--root', root], out);
  return { code, text: lines.join('\n') };
}

async function runDb(db: FakeFirestore, root: string, ...args: string[]): Promise<{ code: number; text: string }> {
  const { out, lines } = captureOut();
  const code = await main([...args, '--root', root], out, { openFirestore: async () => db });
  return { code, text: lines.join('\n') };
}

describe('cli', () => {
  it('parses flags', () => {
    assert.deepEqual(parseArgs(['assemble', '--blueprint', 'x', '--allow-reuse', '--ids', 'a', '--ids', 'b']), {
      cmd: 'assemble',
      opts: { blueprint: 'x', 'allow-reuse': true, ids: ['a', 'b'] },
    });
    assert.throws(() => parseArgs(['assemble', 'stray']));
    assert.throws(() => parseArgs(['assemble', '--blueprint']));
  });

  it('runs matrix → lint → dedup → assemble → timing → validate → import (dry) → registry → review end to end', async () => {
    const root = tempRepo();
    const bank = syntheticBank(BP, 'ru', 2, { spare: 1 });
    const bankFile: BankFile = { schema_version: 1, batch: { id: 'synth', kind: 'sample', created_at: '2026-11-01T00:00:00.000Z', note: 'test' }, passages: bank.passages, items: bank.items };
    writeJsonAtomic(join(root, 'content', 'bank', 'synth', 'items.json'), bankFile);

    assert.equal((await run(root, 'matrix', '--blueprint', BP)).code, 0);
    assert.ok(existsSync(join(root, 'content', 'matrix', `${BP}.json`)));

    const lint = await run(root, 'lint');
    assert.equal(lint.code, 0, lint.text);

    const dedup = await run(root, 'dedup', '--mark');
    assert.equal(dedup.code, 0);
    assert.match(dedup.text, /0 cluster/);

    const asm = await run(root, 'assemble', '--blueprint', BP, '--language', 'ru', '--count', '2');
    assert.equal(asm.code, 0, asm.text);
    const v1 = join(root, 'content', 'variants', BP, 'ru', `v_${BP}_ru_001.json`);
    const v2 = join(root, 'content', 'variants', BP, 'ru', `v_${BP}_ru_002.json`);
    assert.ok(existsSync(v1) && existsSync(v2));
    const f1 = VariantFile.parse(readJson(v1));
    assert.equal(f1.variant.status, 'draft');
    assert.equal(f1.variant.sections[0]!.question_ids.length, 40);

    // Rebuilding the same number with the same seed keeps the content version.
    const again = await run(root, 'assemble', '--blueprint', BP, '--language', 'ru', '--numbers', '1');
    assert.equal(again.code, 0, again.text);
    assert.equal(VariantFile.parse(readJson(v1)).variant.content_version, 1);

    // A third variant would need reused items.
    const third = await run(root, 'assemble', '--blueprint', BP, '--language', 'ru', '--count', '1', '--dry-run');
    assert.equal(third.code, 1);

    const timing = await run(root, 'timing');
    assert.equal(timing.code, 0, timing.text);
    assert.match(timing.text, /^fits /m);

    const validate = await run(root, 'validate', '--publish');
    assert.equal(validate.code, 0, validate.text);
    const strictLang = await run(root, 'validate', '--require-languages');
    assert.equal(strictLang.code, 1, 'no ky variants yet');

    const imp = await run(root, 'import', '--blueprint', BP);
    assert.equal(imp.code, 0);
    assert.match(imp.text, /DRY RUN — nothing written/);
    const plan = readJson<{ summary: Record<string, number>; ops: unknown[] }>(join(root, 'content', 'reports', 'import-plan.json'));
    assert.deepEqual(plan.summary, { exam_blueprints: 1, exam_passages: 0, exam_questions: 80, exam_question_keys: 80, exam_variants: 2 });

    const reg = await run(root, 'registry');
    assert.equal(reg.code, 0);
    const registry = readJson<{ rows: Array<{ blueprint_id: string; language: string; variants: Record<string, number> }> }>(join(root, 'content', 'registry.json'));
    const row = registry.rows.find((r) => r.blueprint_id === BP && r.language === 'ru')!;
    assert.deepEqual(row.variants, { drafted: 2, ai_verified: 2, approved: 2, published: 0, archived: 0 });
    assert.match(readFileSync(join(root, 'content', 'REGISTRY.md'), 'utf8'), new RegExp(`\`${BP}\` \\| ru \\| 100 \\| 2 \\| 2 \\| 2 \\| 0 \\|`));

    // Humans approve/reject; drafts need an explicit --from-draft.
    const id = f1.variant.sections[0]!.question_ids[0]!;
    assert.equal((await run(root, 'review', '--ids', id, '--status', 'rejected', '--by', 'uid_m', '--notes', 'неоднозначно')).code, 0);
    const reloaded = BankFile.parse(readJson(join(root, 'content', 'bank', 'synth', 'items.json')));
    assert.equal(reloaded.items.find((i) => i.id === id)!.question.review.status, 'rejected');
    await assert.rejects(() => run(root, 'review', '--ids', id, '--status', 'ai_verified', '--by', 'uid_m'), /humans set/);
    const afterReject = await run(root, 'validate');
    assert.equal(afterReject.code, 1, 'a rejected item blocks its variant');
  });

  it('import --commit never changes an existing variant status; review-sync pulls admin-panel statuses; edits made there are reported (CP-04, CP-10)', async () => {
    const root = tempRepo();
    const bank = syntheticBank(BP, 'ru', 2, { spare: 1 });
    const bankFile: BankFile = { schema_version: 1, batch: { id: 'synth', kind: 'sample', created_at: '2026-11-01T00:00:00.000Z', note: 'test' }, passages: bank.passages, items: bank.items };
    writeJsonAtomic(join(root, 'content', 'bank', 'synth', 'items.json'), bankFile);
    assert.equal((await run(root, 'assemble', '--blueprint', BP, '--language', 'ru', '--count', '2')).code, 0);
    const id1 = `v_${BP}_ru_001`;
    const id2 = `v_${BP}_ru_002`;
    const p1 = join(root, 'content', 'variants', BP, 'ru', `${id1}.json`);
    const p2 = join(root, 'content', 'variants', BP, 'ru', `${id2}.json`);
    const db = new FakeFirestore();

    const first = await runDb(db, root, 'import', '--blueprint', BP, '--commit');
    assert.equal(first.code, 0, first.text);
    assert.equal(db.get('exam_variants', id1)!.status, 'draft');

    // --publish does not flip variants that already exist in Firestore, and the local files stay honest.
    const pub = await runDb(db, root, 'import', '--blueprint', BP, '--publish', '--published-by', 'uid_admin', '--commit');
    assert.equal(pub.code, 0, pub.text);
    assert.ok(pub.text.includes(`publish in the admin panel, adminPublishVariant): ${id1}, ${id2}`), pub.text);
    assert.equal(db.get('exam_variants', id1)!.status, 'draft');
    assert.equal(VariantFile.parse(readJson(p1)).variant.status, 'draft');

    // The admin panel unpublishes 001 and publishes 002.
    Object.assign(db.get('exam_variants', id1)!, { status: 'archived', archived_by: 'uid_admin' });
    Object.assign(db.get('exam_variants', id2)!, { status: 'published', published_at: '2026-11-03T10:00:00.000Z', published_by: 'uid_admin' });
    const sync = await runDb(db, root, 'review-sync', '--blueprint', BP);
    assert.equal(sync.code, 0, sync.text);
    assert.ok(sync.text.includes(`${id1}: draft → archived`), sync.text);
    assert.equal(VariantFile.parse(readJson(p1)).variant.status, 'archived');
    const f2 = VariantFile.parse(readJson(p2)).variant;
    assert.deepEqual([f2.status, f2.published_by, f2.published_at], ['published', 'uid_admin', '2026-11-03T10:00:00.000Z']);

    const again = await runDb(db, root, 'import', '--blueprint', BP, '--publish', '--published-by', 'uid_admin', '--commit');
    assert.equal(again.code, 0, again.text);
    assert.ok(again.text.includes(`skipped ${id1}: archived`), again.text);
    assert.equal(db.get('exam_variants', id1)!.status, 'archived', 'an archived variant is never revived');
    const rebuild = await run(root, 'assemble', '--blueprint', BP, '--language', 'ru', '--numbers', '1');
    assert.match(rebuild.text, /archived variants are never rebuilt/);
    assert.equal(VariantFile.parse(readJson(p1)).variant.status, 'archived');

    // A question edited in the admin panel is reported, not reverted, until --overwrite.
    const qid = f2.sections[0]!.question_ids[0]!;
    Object.assign(db.get('exam_questions', qid)!, { stem: 'Правка методиста', edited_in_cms_at: '2026-11-03T11:00:00.000Z' });
    const conflict = await runDb(db, root, 'import', '--blueprint', BP, '--all-items', '--commit');
    assert.equal(conflict.code, 0, conflict.text);
    assert.ok(conflict.text.includes('NOT overwritten (cms_conflicts)'), conflict.text);
    assert.equal(db.get('exam_questions', qid)!.stem, 'Правка методиста');
    const report = readJson<{ cms_conflicts: Array<{ collection: string; id: string }> }>(join(root, 'content', 'reports', 'import-report.json'));
    assert.deepEqual(report.cms_conflicts.map((c) => `${c.collection}/${c.id}`), [`exam_questions/${qid}`, `exam_question_keys/${qid}`]);
    const over = await runDb(db, root, 'import', '--blueprint', BP, '--all-items', '--commit', '--overwrite');
    assert.ok(over.text.includes(`OVERWRITTEN exam_questions/${qid}`), over.text);
    assert.notEqual(db.get('exam_questions', qid)!.stem, 'Правка методиста');

    // A save in the admin panel that left the content as the bank has it is taken back; a re-link is kept (CP-NEW-1, CP-NEW-2).
    const other = f2.sections[0]!.question_ids[1]!;
    Object.assign(db.get('exam_questions', qid)!, { edited_in_cms_at: '2026-11-03T12:00:00.000Z', updated_by: 'uid_m' });
    db.get('exam_questions', other)!.translation_group_id = 'tg_q_cms_link';
    const caught = await runDb(db, root, 'import', '--blueprint', BP, '--all-items', '--commit');
    assert.equal(caught.code, 0, caught.text);
    assert.ok(caught.text.includes(`caught up exam_questions/${qid}: the admin-panel edit is in the bank`), caught.text);
    assert.ok(caught.text.includes(`exam_questions/${other}: Firestore tg_q_cms_link, bank tg_`), caught.text);
    assert.ok(!caught.text.includes('cms_conflicts'), caught.text);
    assert.equal('edited_in_cms_at' in db.get('exam_questions', qid)!, false);
    assert.equal(db.get('exam_questions', other)!.translation_group_id, 'tg_q_cms_link');
    const caughtReport = readJson<{ cms_caught_up: Array<{ id: string }>; translation_links_kept: Array<{ id: string }> }>(join(root, 'content', 'reports', 'import-report.json'));
    assert.deepEqual(caughtReport.cms_caught_up.map((c) => c.id), [qid]);
    assert.deepEqual(caughtReport.translation_links_kept.map((c) => c.id), [other]);
  });

  it('paid stages without the flag only print a plan and never call the API', async () => {
    const root = tempRepo();
    const saved = process.env.ANTHROPIC_API_KEY;
    delete process.env.ANTHROPIC_API_KEY;
    try {
      const gen = await run(root, 'generate', '--blueprint', 'ort_main_2026', '--language', 'ky', '--section', 'verbal');
      assert.equal(gen.code, 0);
      assert.match(gen.text, /dry plan only/);
      assert.match(gen.text, /estimate ≈ \$/);
      assert.equal(existsSync(join(root, 'content', 'bank')), false, 'nothing was written');
      const ver = await run(root, 'verify');
      assert.match(ver.text, /dry plan only/);
      await assert.rejects(() => run(root, 'generate', '--blueprint', 'ort_main_2026', '--language', 'ky', '--i-understand-this-costs-money'), /ANTHROPIC_API_KEY is not set/);
    } finally {
      if (saved !== undefined) process.env.ANTHROPIC_API_KEY = saved;
    }
  });

  it('unknown stages print help', async () => {
    const r = await run(tempRepo(), 'publish-everything');
    assert.equal(r.code, 2);
    assert.match(r.text, /unknown stage/);
  });
});
