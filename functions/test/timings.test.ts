import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { leaderboardBoards, leagueGroupIds } from '../src/domain/leaderboard';
import { DomainError } from '../src/domain/reasons';
import { buildExamResult, scoreAttempt } from '../src/domain/scoring';
import { groupWeeklyBoardId, regionWeeklyBoardId } from '../src/domain/time';
import { aggregateTopicTimes, median, parseActivitySeconds, sanitizeTimings, storedTimings } from '../src/domain/timings';
import { applyStudySeconds, emptyStats, parseStats, statsView } from '../src/domain/xp';
import { bishkek } from './fixtures';

const isValidation = (e: unknown) => e instanceof DomainError && e.reason === 'VALIDATION_FAILED';

describe('exam timings (ARCHITECTURE §9.5)', () => {
  const qids = ['q1', 'q2', 'q3'];

  it('keeps only current-section questions with whole seconds in [0, duration]', () => {
    const t = sanitizeTimings({ q1: 30, q2: 12.6, q3: -1, other: 10, q4: 5 }, qids, 1800);
    assert.deepEqual(t, { q1: 30, q2: 13 });
    assert.deepEqual(sanitizeTimings({ q1: 1800, q2: 1801, q3: 'x' }, qids, 1800), { q1: 1800 });
    assert.deepEqual(sanitizeTimings({ q1: Number.NaN, q2: Infinity }, qids, 1800), {});
    assert.deepEqual(sanitizeTimings(undefined, qids, 1800), {});
    assert.deepEqual(sanitizeTimings(null, qids, 1800), {});
  });

  it('a non-object timings payload is VALIDATION_FAILED', () => {
    for (const bad of [[1, 2], 'q1=3', 5, true]) assert.throws(() => sanitizeTimings(bad, qids, 60), isValidation);
  });

  it('storedTimings reads back what the server wrote', () => {
    assert.deepEqual(storedTimings({ q1: 3, q2: 'x', q3: -1 }), { q1: 3 });
    assert.deepEqual(storedTimings(undefined), {});
  });

  it('median of odd and even lists', () => {
    assert.equal(median([]), 0);
    assert.equal(median([5, 1, 3]), 3);
    assert.equal(median([4, 1, 3, 2]), 2.5);
  });

  it('topic_time_avg is the mean per topic; slow_topics exceed 1.5 × the attempt median', () => {
    const questions = [
      { question_id: 'a1', topic_id: 'algebra' },
      { question_id: 'a2', topic_id: 'algebra' },
      { question_id: 'g1', topic_id: 'geometry' },
      { question_id: 'g2', topic_id: 'geometry' },
      { question_id: 'r1', topic_id: 'reading' },
      { question_id: 'x1', topic_id: null },
      { question_id: 'u1', topic_id: 'untimed' },
    ];
    const r = aggregateTopicTimes(questions, { a1: 40, a2: 50, g1: 100, g2: 140, r1: 60, x1: 30 });
    // median of [40, 50, 100, 140, 60, 30] = (50 + 60) / 2 = 55; 1.5 × 55 = 82.5
    assert.deepEqual(r.topic_time_avg, { algebra: 45, geometry: 120, reading: 60 });
    assert.deepEqual(r.slow_topics, ['geometry']);
  });

  it('without timings both fields are empty; equal times are never slow', () => {
    assert.deepEqual(aggregateTopicTimes([{ question_id: 'q', topic_id: 't' }], {}), { topic_time_avg: {}, slow_topics: [] });
    const even = aggregateTopicTimes(
      [
        { question_id: 'a', topic_id: 't1' },
        { question_id: 'b', topic_id: 't2' },
      ],
      { a: 20, b: 20 },
    );
    assert.deepEqual(even.slow_topics, []);
    assert.deepEqual(aggregateTopicTimes([{ question_id: 'a', topic_id: 't' }], { a: 0 }).slow_topics, []);
  });

  it('ExamResult carries topic_time_avg and slow_topics (empty by default)', () => {
    const score = scoreAttempt({ sections: [{ section_id: 's', question_ids: ['q1'] }], answers: { s: { q1: 'A' } }, keys: { q1: 'A' }, topics: { q1: 't' } });
    const plain = buildExamResult(score, 101, true);
    assert.deepEqual([plain.topic_time_avg, plain.slow_topics], [{}, []]);
    const timed = buildExamResult(score, 101, true, aggregateTopicTimes(score.outcomes, { q1: 42 }));
    assert.deepEqual(timed.topic_time_avg, { t: 42 });
  });
});

describe('recordActivity study seconds (ARCHITECTURE §9.5)', () => {
  it('seconds must be an integer in [0, 3600] when given', () => {
    assert.equal(parseActivitySeconds(undefined), 0);
    assert.equal(parseActivitySeconds(null), 0);
    assert.equal(parseActivitySeconds(0), 0);
    assert.equal(parseActivitySeconds(3600), 3600);
    for (const bad of [-1, 3601, 1.5, '60', true]) assert.throws(() => parseActivitySeconds(bad), isValidation, String(bad));
  });

  it('adds to the total and today (Bishkek day), resetting today at Bishkek midnight', () => {
    const day1 = bishkek(2026, 11, 5, 23, 50);
    const a = applyStudySeconds(emptyStats(), 600, day1);
    assert.equal(a.added, 600);
    assert.deepEqual([a.stats.study_seconds_total, a.stats.study_seconds_today, a.stats.study_day], [600, 600, '2026-11-05']);
    const b = applyStudySeconds(a.stats, 300, day1 + 20 * 60_000); // 00:10 next Bishkek day
    assert.deepEqual([b.stats.study_seconds_total, b.stats.study_seconds_today, b.stats.study_day], [900, 300, '2026-11-06']);
  });

  it('today is capped at 24 h and a call at 3600 s', () => {
    const t = bishkek(2026, 11, 5, 12);
    let s = emptyStats();
    for (let i = 0; i < 25; i++) s = applyStudySeconds(s, 3600, t).stats;
    assert.equal(s.study_seconds_today, 86_400);
    assert.equal(s.study_seconds_total, 86_400);
    assert.equal(applyStudySeconds(emptyStats(), 99_999, t).added, 3600);
  });

  it('persists through parseStats and appears in statsView', () => {
    const s = applyStudySeconds(emptyStats(), 120, bishkek(2026, 11, 5, 9)).stats;
    const round = parseStats({ study_seconds_total: 120, study_seconds_today: 120, study_day: '2026-11-05' });
    assert.deepEqual([round.study_seconds_total, round.study_seconds_today, round.study_day], [120, 120, '2026-11-05']);
    assert.equal(statsView(s)['study_seconds_total'], 120);
    assert.equal(parseStats({ study_day: 'yesterday' }).study_day, null);
  });
});

describe('league fan-out (ARCHITECTURE §9.3)', () => {
  const t = bishkek(2026, 11, 4, 12);

  it('weekly XP also goes to the region league and every group league', () => {
    assert.deepEqual(leaderboardBoards(t, null, { regionId: 'chuy', groupIds: ['g1', 'g2'] }), [
      'weekly_2026-W45',
      'all_time',
      'region_chuy_weekly_2026-W45',
      'group_g1_weekly_2026-W45',
      'group_g2_weekly_2026-W45',
    ]);
    assert.deepEqual(leaderboardBoards(t, 'main', { regionId: null, groupIds: [] }), ['weekly_2026-W45', 'all_time', 'subject_main_weekly_2026-W45']);
    assert.equal(regionWeeklyBoardId('osh_city', t), 'region_osh_city_weekly_2026-W45');
    assert.equal(groupWeeklyBoardId('abc', t), 'group_abc_weekly_2026-W45');
  });

  it('ignores invalid region ids and group ids, at most 5 groups', () => {
    assert.deepEqual(leaderboardBoards(t, null, { regionId: 'Чуй', groupIds: ['../x', '', 'ok'] }), ['weekly_2026-W45', 'all_time', 'group_ok_weekly_2026-W45']);
    assert.deepEqual(leagueGroupIds(['a', 'b', 'c', 'd', 'e', 'f', 'a']), ['a', 'b', 'c', 'd', 'e']);
    assert.deepEqual(leagueGroupIds('a'), []);
  });
});
