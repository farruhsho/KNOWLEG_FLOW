import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { join } from 'node:path';
import { checkArithmetic } from '../src/arith';
import { lintBank, loadBank, questionContentHash, questionIdFromHash } from '../src/bank';
import { allTopicIds } from '../src/curriculum';
import { BankFile, ExamPassage, ExamQuestion, ExamQuestionKey, ExamVariant, exportJsonSchemas, formatIssues } from '../src/schema';
import { readJson } from '../src/io';
import { structuralProblems, translationPairs } from '../src/translate';
import { real, REPO_PATHS } from './fixtures';

const SAMPLE = join(REPO_PATHS.bank, 'sample', 'items.json');

describe('schemas (ARCHITECTURE §1.2–1.3)', () => {
  const sample = BankFile.parse(readJson(SAMPLE));
  const first = sample.items[0]!.question;

  it('the hand-written sample bank is schema-valid and lint-clean', () => {
    const bank = loadBank(REPO_PATHS.bank);
    const sampleIds = new Set(sample.items.map((i) => i.id));
    assert.deepEqual(bank.problems, []);
    assert.deepEqual(lintBank(bank).filter((p) => [...sampleIds].some((id) => p.startsWith(id))), []);
  });

  it('sample bank: 12 original ru items (4 comparison, 4 problems, 2 analogies, 2 completion) + 4 ky translations, all drafts', () => {
    const ru = sample.items.filter((i) => i.question.language === 'ru');
    const ky = sample.items.filter((i) => i.question.language === 'ky');
    assert.equal(ru.length, 12);
    assert.equal(ky.length, 4);
    const byPart = (part: string): number => ru.filter((i) => i.target.part_id === part).length;
    assert.equal(byPart('math_comparison'), 4);
    assert.equal(byPart('math_problems'), 4);
    assert.equal(byPart('analogies'), 2);
    assert.equal(byPart('completion'), 2);
    for (const it of sample.items) {
      assert.equal(it.question.source.kind, 'original');
      assert.equal(it.question.review.status, 'draft');
      assert.equal(it.question.content_hash, questionContentHash(it.question));
      assert.equal(it.id, questionIdFromHash(it.question.content_hash));
    }
    const topics = allTopicIds(real().curriculum);
    for (const it of sample.items) {
      assert.ok(topics.has(it.question.topic_id), it.question.topic_id);
      if (it.question.subtopic_id) assert.ok(topics.has(it.question.subtopic_id), it.question.subtopic_id);
    }
  });

  it('sample keys: every computable maths key is re-derived by the arithmetic checker', () => {
    const checked = sample.items.filter((i) => i.question.subject_id === 'math').map((i) => ({ id: i.id, r: checkArithmetic(i) })).filter((x) => x.r.checked);
    assert.ok(checked.length >= 5, `only ${checked.length} computable`);
    for (const { id, r } of checked) assert.equal(r.ok, true, `${id}: ${r.detail}`);
  });

  it('sample translations are structurally consistent with their Russian originals', () => {
    const pairs = translationPairs(sample.items);
    assert.equal(pairs.length, 4);
    for (const p of pairs) {
      assert.equal(p.a.question.language, 'ru', 'the original comes first');
      assert.deepEqual(structuralProblems(p.a, p.b, new Map()), []);
    }
  });

  it('rejects malformed questions', () => {
    const bad = (patch: Record<string, unknown>): string[] => {
      const r = ExamQuestion.safeParse({ ...first, ...patch });
      return r.success ? [] : formatIssues(r.error);
    };
    assert.deepEqual(bad({}), []);
    assert.ok(bad({ options: [{ id: 'B', text: 'x' }, { id: 'A', text: 'y' }] }).some((m) => m.includes('sequential')));
    assert.ok(bad({ options: [{ id: 'A', text: 'x' }, { id: 'B', text: 'X' }] }).some((m) => m.includes('unique')));
    assert.ok(bad({ table: null }).some((m) => m.includes('quantitative_comparison')));
    assert.ok(bad({ type: 'text_based' }).some((m) => m.includes('passage_id')));
    assert.ok(bad({ source: { kind: 'copied', basis: 'x', author: 'y' } }).length > 0, 'only original or licensed material');
    assert.ok(bad({ difficulty: 4 }).length > 0);
    assert.ok(bad({ language: 'kz' }).length > 0);
    assert.ok(bad({ content_hash: 'md5:abc' }).length > 0);
    assert.ok(bad({ image_path: 'https://example.com/a.png' }).length > 0);
    assert.ok(bad({ correct: 'A' }).length > 0, 'the key never lives on the public document');
    assert.ok(bad({ topicId: 'x' }).length > 0, 'snake_case only, no unknown fields');
  });

  it('keys, passages and variants follow the contract field names', () => {
    assert.ok(ExamQuestionKey.safeParse({ correct: 'A', explanation: 'e', wrong_option_notes: { B: 'b' }, solution_steps: ['s'] }).success);
    assert.ok(!ExamQuestionKey.safeParse({ correct: 'F', explanation: 'e', wrong_option_notes: {}, solution_steps: [] }).success);
    assert.ok(ExamPassage.safeParse({ language: 'ky', subject_id: 'reading', section_id: 'reading', title: 't', text: 'x', source: first.source }).success);
    const variant = {
      blueprint_id: 'ort_main_2026', blueprint_version: 1, number: 1, title: { ru: 'Вариант 1', ky: '1-вариант' }, language: 'ru', status: 'draft',
      sections: [{ section_id: 'math', question_ids: ['q_1'] }], content_version: 1, difficulty_label: 'standard', created_by: 'pipeline',
      published_at: null, published_by: null, stats: { attempts: 0, avg_percent: 0 },
    };
    assert.ok(ExamVariant.safeParse(variant).success);
    assert.ok(!ExamVariant.safeParse({ ...variant, status: 'live' }).success);
    assert.ok(!ExamVariant.safeParse({ ...variant, difficulty_label: 'easy' }).success);
  });

  it('exports JSON Schemas for every document type', () => {
    const s = exportJsonSchemas();
    assert.deepEqual(Object.keys(s).sort(), ['bank_file', 'exam_passage', 'exam_question', 'exam_question_key', 'exam_variant', 'variant_file']);
    const q = s.exam_question as { properties: Record<string, unknown>; required: string[] };
    assert.ok(q.required.includes('translation_group_id'));
    assert.ok('content_hash' in q.properties);
  });

  it('the committed content/schema files are up to date', () => {
    const s = exportJsonSchemas();
    for (const [name, schema] of Object.entries(s)) {
      assert.deepEqual(readJson(join(REPO_PATHS.schema, `${name}.schema.json`)), JSON.parse(JSON.stringify(schema)), `${name}: run \`npm run cli -- schemas\``);
    }
  });
});
