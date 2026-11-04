import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { applySectionSubmit, buildInitialAttempt } from '../src/domain/exam_session';
import { buildSessionPayload } from '../src/domain/payload';
import { parseQuestion } from '../src/domain/types';
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
});
