import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { applySectionSubmit, buildInitialAttempt } from '../src/domain/exam_session';
import { buildSessionPayload } from '../src/domain/payload';
import { examContextStem } from '../src/domain/tutor_prompt';
import { normalizeTable, parseQuestion } from '../src/domain/types';
import { blueprint, buildBank } from './fixtures';

const T0 = 1_762_000_000_000;
const bp = blueprint('ort_main_2026');

describe('ExamSessionPayload', () => {
  const bank = buildBank(bp, 'ky');
  const attempt = buildInitialAttempt({ uid: 'u', variant: bank.variant, blueprint: bp, nowMs: T0, entitlementSource: 'free_first', clientAppVersion: '1' });

  it('contains only the current section, never keys or explanations', () => {
    // Simulate a Firestore doc that wrongly carries key fields: parsing drops them.
    const leaky = parseQuestion('math_q31', {
      ...bank.questions.get('math_q31'),
      correct: 'A',
      correct_answer: 'A',
      explanation: 'secret',
      review: { status: 'methodologist_approved' },
    });
    const questions = new Map(bank.questions);
    questions.set('math_q31', leaky);
    const p = buildSessionPayload({ attemptId: 'a1', attempt, blueprint: bp, questions, passages: new Map(), nowMs: T0 + 1000 });
    assert.equal(p.section?.sectionId, 'math');
    assert.equal(p.section?.questions.length, 60);
    assert.ok(p.section?.questions.every((q) => q.id.startsWith('math_')));
    const json = JSON.stringify(p.section);
    for (const forbidden of ['"correct"', 'correct_answer', 'explanation', 'secret', 'review']) {
      assert.ok(!json.includes(forbidden), `payload leaks ${forbidden}`);
    }
    assert.equal(p.serverNow, T0 + 1000);
    assert.equal(p.section?.deadlineAt, T0 + 90 * 60_000);
    assert.equal(p.section?.durationSec, 5400);
    assert.equal(p.entitlementSource, 'free_first');
  });

  it('quantitative comparison items get the blueprint fixed options in the variant language', () => {
    const p = buildSessionPayload({ attemptId: 'a1', attempt, blueprint: bp, questions: bank.questions, passages: new Map(), nowMs: T0 });
    const qc = p.section!.questions[0]!;
    assert.equal(qc.type, 'quantitative_comparison');
    assert.deepEqual(qc.options.map((o) => o.id), ['A', 'B', 'C', 'D']);
    assert.equal(qc.options[2]!.text, 'Чоңдуктар барабар');
    assert.equal(qc.columnA, '2+2');
    const problem = p.section!.questions[30]!;
    assert.equal(problem.partId, 'math_problems');
    assert.equal(problem.options.length, 5);
  });

  it('includes passages referenced by the current section only', () => {
    let a = attempt;
    for (const id of ['math', 'verbal']) a = applySectionSubmit(a, bp, id, T0 + 60_000).attempt;
    const passages = new Map([
      ['reading_p0', { id: 'reading_p0', title: 'T0', text: 'text 0' }],
      ['other', { id: 'other', title: 'X', text: 'unrelated' }],
    ]);
    const p = buildSessionPayload({ attemptId: 'a1', attempt: a, blueprint: bp, questions: bank.questions, passages, nowMs: T0 });
    assert.equal(p.section?.sectionId, 'reading');
    assert.deepEqual(Object.keys(p.section!.passages), ['reading_p0']);
  });

  it('completed attempts carry no section', () => {
    const done = { ...attempt, status: 'completed' as const };
    const p = buildSessionPayload({ attemptId: 'a1', attempt: done, blueprint: bp, questions: bank.questions, passages: new Map(), nowMs: T0 });
    assert.equal(p.section, null);
  });

  describe('question tables (D2: Firestore {cells} rows -> wire string[][])', () => {
    const stored = { headers: ['Колонка А', 'Колонка Б'], rows: [{ cells: ['$2^{10}$', '$10^3$'] }] };

    it('normalizeTable accepts the stored {cells} shape and the legacy nested-array shape', () => {
      const wire = { headers: ['Колонка А', 'Колонка Б'], rows: [['$2^{10}$', '$10^3$']] };
      assert.deepEqual(normalizeTable(stored), wire);
      assert.deepEqual(normalizeTable({ headers: ['Колонка А', 'Колонка Б'], rows: [['$2^{10}$', '$10^3$']] }), wire);
      assert.deepEqual(normalizeTable({ headers: ['a'], rows: [{ cells: [1, true, null] }, 'junk'] }), { headers: ['a'], rows: [['1', 'true', '']] });
      assert.equal(normalizeTable(null), null);
      assert.equal(normalizeTable({}), null);
      assert.equal(normalizeTable([['a']]), null);
    });

    it('the exam payload always carries rows as string[][]', () => {
      const q = parseQuestion('math_q1', { ...bank.questions.get('math_q1'), table: stored });
      const questions = new Map(bank.questions);
      questions.set('math_q1', q);
      const p = buildSessionPayload({ attemptId: 'a1', attempt, blueprint: bp, questions, passages: new Map(), nowMs: T0 });
      const table = p.section!.questions[0]!.table!;
      assert.ok(Array.isArray(table.rows[0]), 'rows[0] must be a list in the callable response');
      assert.deepEqual(table.rows, [['$2^{10}$', '$10^3$']]);
      assert.ok(!JSON.stringify(p).includes('"cells"'));
    });

    it('the tutor context includes the compared quantities from the table (CP-07)', () => {
      const q = parseQuestion('math_q1', { stem: 'Сравните величины в колонках А и Б.', table: stored });
      const stem = examContextStem(q);
      assert.match(stem, /Сравните/);
      assert.match(stem, /Колонка А \| Колонка Б/);
      assert.ok(stem.includes('$2^{10}$ | $10^3$'));
      assert.equal(examContextStem({ stem: 's', column_a: '1', column_b: '2', table: null }), ['s', 'Column A: 1', 'Column B: 2'].join('\n'));
    });
  });
});
