/**
 * The paid stages (generate, verify, translate-check --api) with a fake LLM:
 * no network, no key. Checks the consent guard, conversion into bank items,
 * the blind-verification verdicts and the bilingual check bookkeeping.
 */
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { join } from 'node:path';
import { loadBank, newBankFile } from '../src/bank';
import { findPart } from '../src/blueprints';
import { convertTranslation, planGeneration, runGeneration, translationCandidates, translationRequest } from '../src/generate';
import { readJson } from '../src/io';
import { COST_FLAG, costUsd, CostMeter, LlmClient, LlmRequest, LlmResponse, parseJsonText, requirePaidConsent } from '../src/llm';
import { BankFile, BankItem, OPTION_IDS } from '../src/schema';
import { apiCheck, mergeRecord, pairRecord, structuralProblems, translationPairs } from '../src/translate';
import { applyVerifyRecord, buildRecord, needsVerify, verifyRequest, VerifyOut } from '../src/verify';
import { realBlueprint, realMatrix, REPO_PATHS, tempRepo } from './fixtures';

class FakeLlm implements LlmClient {
  readonly model = 'claude-opus-5-5';
  readonly requests: LlmRequest[] = [];
  constructor(private readonly reply: (req: LlmRequest, n: number) => unknown) {}
  async complete(req: LlmRequest): Promise<LlmResponse> {
    this.requests.push(req);
    return { json: this.reply(req, this.requests.length), model: this.model, usage: { input_tokens: 1000, output_tokens: 2000, cost_usd: costUsd(this.model, 1000, 2000) } };
  }
}

const sample = BankFile.parse(readJson(join(REPO_PATHS.bank, 'sample', 'items.json')));
const sampleItem = (pred: (i: BankItem) => boolean): BankItem => structuredClone(sample.items.find(pred)!);

describe('paid-stage guard', () => {
  it('refuses without the cost flag or without a key in the environment', () => {
    assert.throws(() => requirePaidConsent(false, { ANTHROPIC_API_KEY: 'x' }), new RegExp(COST_FLAG));
    assert.throws(() => requirePaidConsent(true, {}), /ANTHROPIC_API_KEY is not set/);
    assert.doesNotThrow(() => requirePaidConsent(true, { ANTHROPIC_API_KEY: 'x' }));
  });

  it('prices the 2026 models per MTok', () => {
    assert.equal(costUsd('claude-opus-5-5', 1_000_000, 1_000_000), 24);
    assert.equal(costUsd('claude-sonnet-5-5', 1_000_000, 1_000_000), 12);
    assert.equal(costUsd('claude-haiku-5-5', 1_000_000, 1_000_000), 0.6);
    const m = new CostMeter(0.05);
    m.add({ input_tokens: 1000, output_tokens: 2000, cost_usd: 0.044 });
    assert.equal(m.exhausted(), false);
    m.add({ input_tokens: 1000, output_tokens: 2000, cost_usd: 0.044 });
    assert.equal(m.exhausted(), true);
  });

  it('extracts JSON from fenced text as a fallback', () => {
    assert.deepEqual(parseJsonText('```json\n{"a":1}\n```'), { a: 1 });
    assert.throws(() => parseJsonText('no json here'));
  });
});

describe('generate (fake model)', () => {
  const bp = realBlueprint('ort_main_2026');
  const matrix = realMatrix('ort_main_2026');

  it('plans deficits per topic × difficulty and per passage layout', () => {
    const bank = loadBank(join(tempRepo(), 'content', 'bank'));
    const rows = planGeneration(matrix, 'ru', bank, 10, 1.3);
    const qc = rows.filter((r) => r.part_id === 'math_comparison');
    assert.equal(qc.reduce((a, r) => a + r.target, 0) >= 30 * 10 * 1.3, true);
    const reading = rows.filter((r) => r.part_id === 'reading');
    assert.deepEqual(reading.map((r) => [r.kind, r.layout, r.target]), [['passage_group', 'standalone', 26], ['passage_group', 'paired', 13]]);
  });

  it('turns structured output into draft bank items with blueprint fixed options; nothing is approved', async () => {
    const root = tempRepo();
    const bank = loadBank(join(root, 'content', 'bank'));
    const file = newBankFile(join(root, 'content', 'bank'), 'gen_test', 'generated', 'test', '2026-11-04T00:00:00.000Z');
    const rows = planGeneration(matrix, 'ru', bank, 1, 1, { part: 'math_comparison', topic: 'math.arithmetic' });
    const llm = new FakeLlm((req, n) => {
      const spec = JSON.parse(req.user) as { count: number; difficulty: number };
      return {
        items: Array.from({ length: spec.count }, (_, i) => ({
          subtopic_id: 'math.arithmetic.powers_roots',
          condition: '',
          column_a: `$${n * 100 + i + 1}$`,
          column_b: `$${n * 100 + i}$`,
          correct: 'A',
          explanation: 'Число в колонке А на 1 больше.',
          solution_steps: ['Сравниваем числа.'],
          wrong_option_notes: [{ option: 'B', note: 'перепутаны колонки' }, { option: 'A', note: 'must be dropped: correct option' }],
          basis: 'Программа 5 кл., натуральные числа',
        })),
      };
    });
    const res = await runGeneration({ blueprint: bp, matrix, language: 'ru', bank, file, llm, rows, perRequest: 5, maxItems: 100, meter: new CostMeter(null), now: () => '2026-11-04T00:00:00.000Z', log: () => {} });
    assert.equal(res.failures.length, 0);
    const want = rows.reduce((a, r) => a + r.deficit, 0);
    assert.equal(res.items_added, want);
    assert.ok(llm.requests.every((r) => r.system.includes('Never reproduce') && JSON.stringify(r.schema).includes('column_a')));
    assert.ok(llm.requests.every((r) => JSON.parse(r.user).fixed_options.length === 4));
    const saved = BankFile.parse(readJson(file.path));
    assert.equal(saved.items.length, want);
    const fixed = findPart(bp, 'math', 'math_comparison').part.fixed_options!.map((o) => o.text.ru);
    for (const it of saved.items) {
      assert.equal(it.question.review.status, 'draft');
      assert.equal(it.question.source.kind, 'original');
      assert.deepEqual(it.question.options.map((o) => o.text), fixed);
      assert.equal(it.question.table!.rows[0]!.length, 2);
      assert.deepEqual(Object.keys(it.key.wrong_option_notes), ['B']);
      assert.equal(it.pipeline.generated_by, 'model:claude-opus-5-5');
    }
    // Resumable: the deficit is now covered, a second plan asks for nothing.
    const again = planGeneration(matrix, 'ru', loadBank(join(root, 'content', 'bank')), 1, 1, { part: 'math_comparison', topic: 'math.arithmetic' });
    assert.equal(again.reduce((a, r) => a + r.deficit, 0), 0);
  });

  it('drops malformed model items instead of saving them', async () => {
    const root = tempRepo();
    const bank = loadBank(join(root, 'content', 'bank'));
    const file = newBankFile(join(root, 'content', 'bank'), 'gen_bad', 'generated', 'test', '2026-11-04T00:00:00.000Z');
    const rows = planGeneration(matrix, 'ru', bank, 1, 1, { part: 'math_problems', topic: 'math.sequences' });
    const llm = new FakeLlm(() => ({ items: [{ subtopic_id: 'x', stem: 'Найдите', options: ['1', '2', '3'], correct: 'A', explanation: 'e', solution_steps: [], wrong_option_notes: [], basis: 'b' }] }));
    const res = await runGeneration({ blueprint: bp, matrix, language: 'ru', bank, file, llm, rows, perRequest: 5, maxItems: 10, meter: new CostMeter(null), now: () => '2026-11-04T00:00:00.000Z', log: () => {} });
    assert.equal(res.items_added, 0);
    assert.ok(res.failures.some((f) => f.error.includes('expected 5 options')));
  });

  it('translation keeps the key and the option order, and refuses to change the key', () => {
    const src = sampleItem((i) => i.question.language === 'ru' && i.question.translation_group_id === 'tg_sample_p3');
    src.question.review.status = 'ai_verified';
    const { part } = findPart(bp, 'math', 'math_problems');
    const req = translationRequest(src, 'ky');
    assert.equal(JSON.parse(req.user).item.correct, 'C');
    const out = {
      translatable: true, reason: '', stem: 'Эсептеңиз: $\\frac{3}{4} + \\frac{5}{6} - \\frac{1}{3}$.', table_rows: [],
      options: src.question.options.map((o) => o.text), correct: 'C', explanation: 'Жалпы бөлүмү 12.', solution_steps: ['12'], wrong_option_notes: [{ option: 'A', note: 'ката' }],
    };
    const ky = convertTranslation(src, 'ky', part, out, { batchId: 'tr', model: 'claude-opus-5-5', now: '2026-11-04T00:00:00.000Z' });
    assert.equal(ky.question.language, 'ky');
    assert.equal(ky.question.translation_group_id, src.question.translation_group_id);
    assert.equal(ky.key.correct, 'C');
    assert.equal(ky.question.review.status, 'draft');
    assert.equal(ky.pipeline.translated_from, src.id);
    assert.deepEqual(structuralProblems(src, ky, new Map()), []);
    assert.throws(() => convertTranslation(src, 'ky', part, { ...out, correct: 'B' }, { batchId: 'tr', model: 'm', now: '2026-11-04T00:00:00.000Z' }), /changed the key/);
  });

  it('only verified, not-yet-translated standalone items are translation candidates', async () => {
    const bank = loadBank(REPO_PATHS.bank);
    assert.equal(translationCandidates(bank, 'ru', 'ky', 'ort_main_2026').length, 0, 'sample items are drafts');
  });
});

describe('verify (fake blind solver)', () => {
  const out = (answer: string, extra: Partial<VerifyOut> = {}): VerifyOut => ({
    answer, correct_options: [answer], confidence: 'high', issues: [], language_quality: 'ok', solution: '...', ...extra,
  });

  it('never shows the key to the solver', () => {
    const it = sampleItem((i) => i.question.translation_group_id === 'tg_sample_p1' && i.question.language === 'ru');
    const req = verifyRequest(it, undefined);
    assert.ok(!req.user.includes('"correct"'));
    assert.ok(!req.user.includes(it.key.explanation));
  });

  it('agreement → ai_verified; disagreement, ambiguity or bad arithmetic → rejected; never methodologist_approved', () => {
    const base = sampleItem((i) => i.question.translation_group_id === 'tg_sample_p3' && i.question.language === 'ru');
    const at = '2026-11-04T00:00:00.000Z';

    const ok = structuredClone(base);
    applyVerifyRecord(ok, buildRecord(ok, out('C'), 'm', at, null));
    assert.equal(ok.question.review.status, 'ai_verified');
    assert.equal(ok.pipeline.verify!.agrees, true);
    assert.equal(ok.pipeline.verify!.arithmetic.ok, true);

    const disagree = structuredClone(base);
    applyVerifyRecord(disagree, buildRecord(disagree, out('B'), 'm', at, null));
    assert.equal(disagree.question.review.status, 'rejected');
    assert.match(disagree.question.review.notes, /REJECTED/);

    const ambiguous = structuredClone(base);
    applyVerifyRecord(ambiguous, buildRecord(ambiguous, out('C', { issues: [{ kind: 'multiple_correct', severity: 'major', note: 'B тоже' }] }), 'm', at, null));
    assert.equal(ambiguous.question.review.status, 'rejected');

    const multi = structuredClone(base);
    applyVerifyRecord(multi, buildRecord(multi, out('MULTIPLE', { correct_options: ['B', 'C'] }), 'm', at, null));
    assert.equal(multi.question.review.status, 'rejected');

    // The model agrees with a wrong key, but the exact checker does not.
    const wrongKey = structuredClone(base);
    wrongKey.key.correct = 'A';
    applyVerifyRecord(wrongKey, buildRecord(wrongKey, out('A'), 'm', at, null));
    assert.equal(wrongKey.question.review.status, 'rejected');
    assert.match(wrongKey.question.review.notes, /arithmetic/);

    const minor = structuredClone(base);
    applyVerifyRecord(minor, buildRecord(minor, out('C', { issues: [{ kind: 'language_quality', severity: 'minor', note: 'запятая' }], language_quality: 'minor_issues' }), 'm', at, null));
    assert.equal(minor.question.review.status, 'ai_verified');

    const approved = structuredClone(base);
    approved.question.review = { status: 'methodologist_approved', reviewed_by: 'uid', reviewed_at: at, notes: 'ok' };
    applyVerifyRecord(approved, buildRecord(approved, out('B'), 'm', at, null));
    assert.equal(approved.question.review.status, 'methodologist_approved', 'human decisions are never overwritten');
    assert.equal(approved.pipeline.verify!.verdict, 'unchanged');
    assert.equal(approved.pipeline.verify!.agrees, false);
  });

  it('re-verifies only new or edited items', () => {
    const it = sampleItem((i) => i.question.translation_group_id === 'tg_sample_a1');
    assert.equal(needsVerify(it, false), true);
    applyVerifyRecord(it, buildRecord(it, out('A'), 'm', '2026-11-04T00:00:00.000Z', null));
    assert.equal(needsVerify(it, false), false);
    it.question.content_hash = `sha256:${'1'.repeat(64)}`;
    assert.equal(needsVerify(it, false), true);
  });
});

describe('translate-check', () => {
  const pairs = translationPairs(sample.items.map((i) => structuredClone(i)));

  it('structural check catches a changed key, option count or number', () => {
    const p = pairs.find((x) => x.a.question.translation_group_id === 'tg_sample_p2')!;
    const b = structuredClone(p.b);
    b.key.correct = 'A';
    b.question.stem = b.question.stem.replace('800', '900');
    b.question.options = b.question.options.slice(0, 4);
    const problems = structuralProblems(p.a, b, new Map());
    assert.ok(problems.some((x) => x.startsWith('key')));
    assert.ok(problems.some((x) => x.startsWith('options count')));
    assert.ok(problems.some((x) => x.startsWith('numbers differ')));
  });

  it('the bilingual API check marks non-equivalent pairs as failed and merges per item', async () => {
    const p = pairs[0]!;
    const llm = new FakeLlm(() => ({ equivalent: false, target_language_quality: 'ok', issues: [{ field: 'stem', severity: 'major', note: 'смысл изменён' }] }));
    const api = await apiCheck(p, new Map(), llm);
    assert.equal(llm.requests[0]!.purpose, 'translate_check');
    const rec = pairRecord(p, [], api, '2026-11-04T00:00:00.000Z', p.a);
    assert.equal(rec.status, 'failed');
    assert.deepEqual(rec.counterpart_ids, [p.b.id]);
    const okRec = pairRecord(p, [], { ...api, equivalent: true, issues: [] }, '2026-11-04T00:00:00.000Z', p.a);
    assert.equal(okRec.status, 'passed');
    assert.equal(mergeRecord(rec, okRec).status, 'failed', 'a failure anywhere stays a failure');
  });

  it('option ids in translation schemas cover 4 and 5 option items', () => {
    const five = sampleItem((i) => i.question.options.length === 5);
    const schema = JSON.stringify(translationRequest(five, 'ky').schema);
    for (const id of OPTION_IDS) assert.ok(schema.includes(`"${id}"`));
  });
});
