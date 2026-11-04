import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { buildExamResult, percentOf, scoreAttempt, wrongOutcomes } from '../src/domain/scoring';

describe('scoreAttempt', () => {
  const sections = [
    { section_id: 'math', question_ids: ['m1', 'm2', 'm3', 'm4'] },
    { section_id: 'verbal', question_ids: ['v1', 'v2'] },
  ];
  const keys = { m1: 'A', m2: 'B', m3: 'C', m4: 'D', v1: 'A', v2: 'B' };
  const topics = { m1: 'math.algebra', m2: 'math.algebra', m3: 'math.geometry', m4: 'math.geometry', v1: 'verbal.analogy', v2: 'verbal.analogy' };

  it('counts correct answers per section, total and percent (1 decimal)', () => {
    const score = scoreAttempt({
      sections,
      answers: { math: { m1: 'A', m2: 'B', m3: 'A', m4: null }, verbal: { v1: 'A', v2: 'C' } },
      keys,
      topics,
    });
    assert.equal(score.correct, 3);
    assert.equal(score.total, 6);
    assert.equal(score.percent, 50);
    assert.equal(score.answered, 5);
    assert.deepEqual(score.sections, [
      { section_id: 'math', correct: 2, total: 4, percent: 50 },
      { section_id: 'verbal', correct: 1, total: 2, percent: 50 },
    ]);
  });

  it('is case/whitespace insensitive and treats missing answers as unanswered', () => {
    const score = scoreAttempt({ sections: [sections[0]!], answers: { math: { m1: ' a ' } }, keys, topics });
    assert.equal(score.correct, 1);
    assert.equal(score.answered, 1);
  });

  it('derives weak and strong topics (min 2 questions)', () => {
    const score = scoreAttempt({
      sections,
      answers: { math: { m1: 'A', m2: 'B', m3: 'A', m4: 'A' }, verbal: { v1: 'A', v2: 'B' } },
      keys,
      topics,
    });
    assert.deepEqual(score.weak_topics, ['math.geometry']);
    assert.deepEqual(score.strong_topics, ['math.algebra', 'verbal.analogy']);
    assert.deepEqual(
      score.topics.find((t) => t.topic_id === 'math.geometry'),
      { topic_id: 'math.geometry', correct: 0, total: 2 },
    );
  });

  it('excludes questions without a key from the total', () => {
    const score = scoreAttempt({ sections: [sections[1]!], answers: { verbal: { v1: 'A', v2: 'B' } }, keys: { v1: 'A' }, topics });
    assert.equal(score.total, 1);
    assert.equal(score.unscored, 1);
    assert.equal(score.percent, 100);
  });

  it('lists wrong (answered and incorrect) outcomes only', () => {
    const score = scoreAttempt({
      sections,
      answers: { math: { m1: 'B', m2: null }, verbal: {} },
      keys,
      topics,
    });
    assert.deepEqual(wrongOutcomes(score).map((o) => o.question_id), ['m1']);
  });

  it('builds the contract ExamResult with the unofficial disclaimer', () => {
    const score = scoreAttempt({ sections, answers: { math: { m1: 'A' }, verbal: {} }, keys, topics });
    const result = buildExamResult(score, 101, true);
    assert.equal(result.xp_awarded, 101);
    assert.equal(result.leaderboard_eligible, true);
    assert.equal(result.disclaimer_key, 'exam_result_unofficial');
    assert.ok(!('outcomes' in result), 'per-question keys must not be part of the stored result');
  });

  it('percentOf rounds to one decimal and handles zero totals', () => {
    assert.equal(percentOf(97, 150), 64.7);
    assert.equal(percentOf(0, 0), 0);
  });
});
