/** End-to-end run of the free stages through the CLI in a temporary repo root. */
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { main, parseArgs } from '../src/cli';
import { readJson, writeJsonAtomic } from '../src/io';
import { BankFile, VariantFile } from '../src/schema';
import { captureOut, syntheticBank, tempRepo } from './fixtures';

const BP = 'ort_subject_chemistry_2026';

async function run(root: string, ...args: string[]): Promise<{ code: number; text: string }> {
  const { out, lines } = captureOut();
  const code = await main([...args, '--root', root], out);
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
