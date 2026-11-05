import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  applyAdminDelta,
  applyClawback,
  applyPurchaseGrant,
  applyStartDecision,
  decideExamStart,
  EMPTY_ENTITLEMENT,
  FREE_EXAMS_PER_USER_DEFAULT,
  FREE_EXAMS_PER_USER_MAX,
  FREE_EXAMS_PER_USER_MIN,
  isValidFreeExamsPerUser,
  parseEntitlement,
  parseFreeExamsPerUser,
} from '../src/domain/entitlements';

const NOW = 1_762_000_000_000;

describe('decideExamStart', () => {
  it('gives the first exam for free', () => {
    const d = decideExamStart({ entitlement: parseEntitlement(undefined), inProgressAttemptId: null, freeExamsPerUser: 1 });
    assert.deepEqual(d, { kind: 'free_first' });
  });

  it('charges a credit once the free exam is used', () => {
    const ent = parseEntitlement({ free_exam_used: true, credits: 2 });
    assert.deepEqual(decideExamStart({ entitlement: ent, inProgressAttemptId: null, freeExamsPerUser: 1 }), { kind: 'credit' });
  });

  it('resumes an in-progress attempt of the same variant without charging', () => {
    const ent = parseEntitlement({ free_exam_used: true, credits: 0 });
    assert.deepEqual(decideExamStart({ entitlement: ent, inProgressAttemptId: 'att1', freeExamsPerUser: 1 }), { kind: 'resume', attemptId: 'att1' });
  });

  it('returns none without free exam or credits', () => {
    const ent = parseEntitlement({ free_exam_used: true, credits: 0 });
    assert.deepEqual(decideExamStart({ entitlement: ent, inProgressAttemptId: null, freeExamsPerUser: 1 }), { kind: 'none' });
  });

  it('respects freeExamsPerUser = 0 and > 1', () => {
    const fresh = parseEntitlement(undefined);
    assert.deepEqual(decideExamStart({ entitlement: fresh, inProgressAttemptId: null, freeExamsPerUser: 0 }), { kind: 'none' });
    const usedOne = parseEntitlement({ free_exam_used: true });
    assert.deepEqual(decideExamStart({ entitlement: usedOne, inProgressAttemptId: null, freeExamsPerUser: 2 }), { kind: 'free_first' });
  });
});

// adminUpdatePricing accepts exactly these values; the admin CMS and the
// student client must use the same range (ENT-FREE-01).
describe('free_exams_per_user range', () => {
  it('is an integer in [0, 5], default 1', () => {
    assert.equal(FREE_EXAMS_PER_USER_MIN, 0);
    assert.equal(FREE_EXAMS_PER_USER_MAX, 5);
    assert.equal(FREE_EXAMS_PER_USER_DEFAULT, 1);
    for (const ok of [0, 1, 2, 5, 3.0]) assert.equal(isValidFreeExamsPerUser(ok), true, String(ok));
    for (const bad of [-1, 6, 10, 1.5, '1', null, undefined, Number.NaN]) assert.equal(isValidFreeExamsPerUser(bad), false, String(bad));
  });

  it('stored values outside the range read as the default', () => {
    assert.equal(parseFreeExamsPerUser(0), 0);
    assert.equal(parseFreeExamsPerUser(5), 5);
    assert.equal(parseFreeExamsPerUser(6), 1);
    assert.equal(parseFreeExamsPerUser(10), 1);
    assert.equal(parseFreeExamsPerUser('3'), 1);
    assert.equal(parseFreeExamsPerUser(undefined), 1);
  });
});

describe('applyStartDecision', () => {
  it('marks the free exam used (once per account) with a zero-delta ledger entry', () => {
    const out = applyStartDecision({ ...EMPTY_ENTITLEMENT }, { kind: 'free_first' }, 'att1', NOW);
    assert.equal(out.entitlement.free_exam_used, true);
    assert.equal(out.entitlement.free_exam_attempt_id, 'att1');
    assert.equal(out.entitlement.free_exam_used_at, NOW);
    assert.equal(out.entitlement.free_exams_used_count, 1);
    assert.deepEqual(out.ledger, { delta: 0, balance_after: 0, reason: 'free_first' });
    assert.equal(out.entitlementSource, 'free_first');
  });

  it('decrements one credit', () => {
    const out = applyStartDecision({ ...EMPTY_ENTITLEMENT, free_exam_used: true, free_exams_used_count: 1, credits: 3 }, { kind: 'credit' }, 'att2', NOW);
    assert.equal(out.entitlement.credits, 2);
    assert.deepEqual(out.ledger, { delta: -1, balance_after: 2, reason: 'exam_start' });
  });

  it('refuses to apply resume/none', () => {
    assert.throws(() => applyStartDecision({ ...EMPTY_ENTITLEMENT }, { kind: 'none' }, 'x', NOW));
    assert.throws(() => applyStartDecision({ ...EMPTY_ENTITLEMENT, credits: 0 }, { kind: 'credit' }, 'x', NOW));
  });
});

describe('purchases, refunds and admin grants', () => {
  it('grants purchased credits and settles refund debt first', () => {
    const out = applyPurchaseGrant({ ...EMPTY_ENTITLEMENT, credits: 0, debt_credits: 2 }, 5);
    assert.equal(out.entitlement.credits, 3);
    assert.equal(out.debtSettled, 2);
    assert.equal(out.entitlement.debt_credits, 0);
    assert.equal(out.entitlement.lifetime_credits_purchased, 5);
    assert.equal(out.ledger.reason, 'purchase');
  });

  it('claws back credits but never below zero, recording debt', () => {
    const out = applyClawback({ ...EMPTY_ENTITLEMENT, credits: 1 }, 5);
    assert.equal(out.entitlement.credits, 0);
    assert.equal(out.clawedBack, 1);
    assert.equal(out.newDebt, 4);
    assert.equal(out.entitlement.debt_credits, 4);
    assert.deepEqual(out.ledger, { delta: -1, balance_after: 0, reason: 'refund' });
  });

  it('admin delta clamps at zero', () => {
    const out = applyAdminDelta({ ...EMPTY_ENTITLEMENT, credits: 2 }, -5);
    assert.equal(out.entitlement.credits, 0);
    assert.equal(out.applied, -2);
    assert.throws(() => applyAdminDelta({ ...EMPTY_ENTITLEMENT }, 0));
  });

  it('parses legacy/partial documents tolerantly', () => {
    const e = parseEntitlement({ credits: -3, free_exam_used: true, free_exam_used_at: { toMillis: () => 42 } });
    assert.equal(e.credits, 0);
    assert.equal(e.free_exams_used_count, 1);
    assert.equal(e.free_exam_used_at, 42);
  });
});
