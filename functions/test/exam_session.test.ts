import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  applyExpiry,
  applySectionSubmit,
  assertOwner,
  buildInitialAttempt,
  isLate,
  isLeaderboardEligible,
  isStale,
  LATE_GRACE_MS,
  remainingSec,
  sanitizeAnswers,
  sanitizeFlags,
  STALE_AFTER_MS,
} from '../src/domain/exam_session';
import { classifySubmit } from '../src/domain/payload';
import { DomainError } from '../src/domain/reasons';
import { blueprint, buildBank } from './fixtures';

const T0 = 1_762_000_000_000;
const MIN = 60_000;
const bp = blueprint('ort_main_2026');
const { variant } = buildBank(bp);

function start() {
  return buildInitialAttempt({ uid: 'u1', variant, blueprint: bp, nowMs: T0, entitlementSource: 'credit', clientAppVersion: '1.0.0+1' });
}

function reasonOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    return e instanceof DomainError ? e.reason : 'other';
  }
  return undefined;
}

describe('buildInitialAttempt', () => {
  it('starts the first section with deadline = now + duration and snapshots question ids', () => {
    const a = start();
    assert.equal(a.status, 'in_progress');
    assert.equal(a.current_section_id, 'math');
    assert.equal(a.current_deadline_at, T0 + 90 * MIN);
    assert.deepEqual(a.sections.map((s) => s.section_id), ['math', 'verbal', 'reading', 'grammar']);
    assert.equal(a.sections[0]!.question_ids.length, 60);
    assert.equal(a.sections[1]!.started_at, null);
  });

  it('rejects a variant missing a section', () => {
    const broken = { ...variant, sections: variant.sections.slice(0, 2) };
    assert.equal(
      reasonOf(() => buildInitialAttempt({ uid: 'u', variant: broken, blueprint: bp, nowMs: T0, entitlementSource: 'credit', clientAppVersion: '' })),
      'VARIANT_NOT_AVAILABLE',
    );
  });
});

describe('section transitions (forward-only)', () => {
  it('advances to the next section and restarts its clock from the submit time', () => {
    const a = start();
    const t = T0 + 50 * MIN;
    const tr = applySectionSubmit(a, bp, 'math', t);
    assert.equal(tr.completed, false);
    assert.equal(tr.closed.late, false);
    assert.equal(tr.attempt.current_section_id, 'verbal');
    assert.equal(tr.attempt.current_section_index, 1);
    assert.equal(tr.attempt.current_deadline_at, t + 30 * MIN);
    assert.equal(tr.attempt.sections[0]!.submitted_at, t);
    // original state untouched (pure)
    assert.equal(a.current_section_id, 'math');
  });

  it('refuses to submit a future or a closed section', () => {
    const a = start();
    assert.equal(reasonOf(() => applySectionSubmit(a, bp, 'reading', T0)), 'WRONG_SECTION');
    const next = applySectionSubmit(a, bp, 'math', T0 + MIN).attempt;
    assert.equal(reasonOf(() => applySectionSubmit(next, bp, 'math', T0 + 2 * MIN)), 'WRONG_SECTION');
    assert.equal(classifySubmit(next, 'math'), 'already_submitted');
    assert.equal(classifySubmit(next, 'verbal'), 'current');
    assert.equal(classifySubmit(next, 'grammar'), 'wrong_section');
  });

  it('completes the attempt on the last section', () => {
    let a = start();
    let t = T0;
    for (const id of ['math', 'verbal', 'reading']) {
      t += 10 * MIN;
      a = applySectionSubmit(a, bp, id, t).attempt;
    }
    const tr = applySectionSubmit(a, bp, 'grammar', t + 5 * MIN);
    assert.equal(tr.completed, true);
    assert.equal(tr.attempt.status, 'completed');
    assert.equal(tr.attempt.current_section_id, null);
    assert.equal(isLeaderboardEligible(tr.attempt), true);
    assert.equal(reasonOf(() => applySectionSubmit(tr.attempt, bp, 'grammar', t + 6 * MIN)), 'ATTEMPT_NOT_IN_PROGRESS');
    assert.equal(classifySubmit(tr.attempt, 'grammar'), 'already_submitted');
  });
});

describe('late logic (120 s grace)', () => {
  it('is on time up to deadline + 120 s and late after', () => {
    const deadline = T0 + 90 * MIN;
    assert.equal(isLate(deadline, deadline + LATE_GRACE_MS), false);
    assert.equal(isLate(deadline, deadline + LATE_GRACE_MS + 1), true);
    assert.equal(isLate(null, deadline * 2), false);
  });

  it('a late section is accepted, counted, and makes the attempt leaderboard-ineligible', () => {
    const a = start();
    const tr = applySectionSubmit(a, bp, 'math', T0 + 90 * MIN + 121_000);
    assert.equal(tr.closed.late, true);
    assert.equal(tr.attempt.integrity.late_sections, 1);
    assert.equal(isLeaderboardEligible(tr.attempt), false);
  });
});

describe('expiry of abandoned attempts', () => {
  it('is stale only 15 min after the current deadline', () => {
    const a = start();
    assert.equal(isStale(a, T0 + 90 * MIN + STALE_AFTER_MS), false);
    assert.equal(isStale(a, T0 + 90 * MIN + STALE_AFTER_MS + 1), true);
  });

  it('closes current and unstarted sections late and completes', () => {
    const a = applySectionSubmit(start(), bp, 'math', T0 + 30 * MIN).attempt;
    const now = T0 + 300 * MIN;
    const ex = applyExpiry(a, now);
    assert.deepEqual(ex.closed.map((c) => c.section_id), ['verbal', 'reading', 'grammar']);
    assert.equal(ex.attempt.status, 'completed');
    assert.equal(ex.attempt.integrity.expired_by_server, true);
    assert.equal(ex.attempt.integrity.late_sections, 3);
    assert.equal(ex.attempt.sections[0]!.late, false);
    assert.equal(isLeaderboardEligible(ex.attempt), false);
  });
});

describe('input sanitizing and ownership', () => {
  it('keeps only answers for the section and normalizes values', () => {
    const out = sanitizeAnswers({ q1: 'b', q2: 'not an option!', q3: 'A', other: 'C' }, ['q1', 'q2', 'q4']);
    assert.deepEqual(out, { q1: 'B', q2: null, q4: null });
    assert.deepEqual(sanitizeFlags(['q1', 'q1', 'zzz', 5], ['q1', 'q2']), ['q1']);
  });

  it('hides attempts of other users as not found', () => {
    assert.equal(reasonOf(() => assertOwner(start(), 'intruder')), 'ATTEMPT_NOT_FOUND');
    assert.equal(reasonOf(() => assertOwner(null, 'u1')), 'ATTEMPT_NOT_FOUND');
  });

  it('remainingSec never goes negative', () => {
    const a = start();
    assert.equal(remainingSec(a, T0), 90 * 60);
    assert.equal(remainingSec(a, T0 + 200 * MIN), 0);
  });
});
