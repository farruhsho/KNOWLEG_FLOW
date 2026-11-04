import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/domain/reasons';
import {
  decideReferralApply,
  decideReferralReward,
  parseReferrerCounter,
  REFERRAL_MONTHLY_CAP,
  referralRejection,
  type RewardInput,
} from '../src/domain/referral';
import { bishkekMonthKey } from '../src/domain/time';
import { bishkek } from './fixtures';

const apply = (over: Partial<Parameters<typeof decideReferralApply>[0]> = {}) =>
  decideReferralApply({
    callerUid: 'bob',
    referrerUid: 'alice',
    currentReferredBy: null,
    examsCompleted: 0,
    lifetimeCreditsPurchased: 0,
    hasPurchaseRecords: false,
    ...over,
  });

describe('referralApply (ARCHITECTURE §9.1)', () => {
  it('applies once for a fresh account', () => {
    assert.deepEqual(apply(), { kind: 'apply' });
  });

  it('own code, a different earlier code, exams or purchases are REFERRAL_NOT_ALLOWED', () => {
    assert.deepEqual(apply({ referrerUid: 'bob' }), { kind: 'reject', why: 'own_code' });
    assert.deepEqual(apply({ currentReferredBy: 'carol' }), { kind: 'reject', why: 'already_referred' });
    assert.deepEqual(apply({ examsCompleted: 1 }), { kind: 'reject', why: 'has_exams' });
    assert.deepEqual(apply({ lifetimeCreditsPurchased: 1 }), { kind: 'reject', why: 'has_purchases' });
    assert.deepEqual(apply({ hasPurchaseRecords: true }), { kind: 'reject', why: 'has_purchases' });
    const e = referralRejection('has_exams');
    assert.ok(e instanceof DomainError);
    assert.equal(e.reason, 'REFERRAL_NOT_ALLOWED');
    assert.deepEqual(e.extra, { why: 'has_exams' });
  });

  it('re-applying the same code is an idempotent no-op (even after an exam)', () => {
    assert.deepEqual(apply({ currentReferredBy: 'alice', examsCompleted: 3 }), { kind: 'noop' });
  });
});

describe('referral reward (first paid grant, monthly cap)', () => {
  const now = bishkek(2026, 11, 15, 12);
  const month = bishkekMonthKey(now);
  const base: RewardInput = {
    referredBy: 'alice',
    refereeUid: 'bob',
    itemStatus: 'joined',
    referrerExists: true,
    counter: { month_key: month, month_rewarded: 3 },
    monthKey: month,
    isTestPurchase: false,
  };

  it('rewards both and bumps the referrer counter', () => {
    assert.deepEqual(decideReferralReward(base), {
      kind: 'reward',
      referrerUid: 'alice',
      rewardReferrer: true,
      capped: false,
      counter: { month_key: month, month_rewarded: 4 },
    });
  });

  it('is idempotent per referred uid (rewarded items never pay twice)', () => {
    assert.deepEqual(decideReferralReward({ ...base, itemStatus: 'rewarded' }), { kind: 'none' });
  });

  it('a missing item still rewards (referred_by is authoritative)', () => {
    assert.equal(decideReferralReward({ ...base, itemStatus: null }).kind, 'reward');
  });

  it('no referrer, self-referral or a test purchase: nothing', () => {
    assert.deepEqual(decideReferralReward({ ...base, referredBy: null }), { kind: 'none' });
    assert.deepEqual(decideReferralReward({ ...base, referredBy: 'bob' }), { kind: 'none' });
    assert.deepEqual(decideReferralReward({ ...base, isTestPurchase: true }), { kind: 'none' });
  });

  it('the referrer gets at most 20 rewards per Bishkek month; the referee is still rewarded', () => {
    const atCap = decideReferralReward({ ...base, counter: { month_key: month, month_rewarded: REFERRAL_MONTHLY_CAP } });
    assert.deepEqual(atCap, {
      kind: 'reward',
      referrerUid: 'alice',
      rewardReferrer: false,
      capped: true,
      counter: { month_key: month, month_rewarded: REFERRAL_MONTHLY_CAP },
    });
    const last = decideReferralReward({ ...base, counter: { month_key: month, month_rewarded: REFERRAL_MONTHLY_CAP - 1 } });
    assert.equal(last.kind === 'reward' && last.rewardReferrer, true);
  });

  it('the cap resets with the Bishkek month (not the UTC month)', () => {
    // 2026-11-30 19:00 UTC is already 2026-12-01 01:00 in Bishkek.
    const dec1 = Date.UTC(2026, 10, 30, 19);
    assert.equal(bishkekMonthKey(dec1), '2026-12');
    assert.equal(bishkekMonthKey(Date.UTC(2026, 10, 30, 17)), '2026-11');
    const r = decideReferralReward({ ...base, counter: { month_key: '2026-11', month_rewarded: 20 }, monthKey: bishkekMonthKey(dec1) });
    assert.deepEqual(r.kind === 'reward' && [r.rewardReferrer, r.counter], [true, { month_key: '2026-12', month_rewarded: 1 }]);
  });

  it('a deleted referrer is skipped without counting; the referee is rewarded', () => {
    const r = decideReferralReward({ ...base, referrerExists: false });
    assert.deepEqual(r.kind === 'reward' && [r.rewardReferrer, r.capped, r.counter.month_rewarded], [false, false, 3]);
  });

  it('parseReferrerCounter tolerates missing docs', () => {
    assert.deepEqual(parseReferrerCounter(undefined), { month_key: null, month_rewarded: 0 });
    assert.deepEqual(parseReferrerCounter({ month_key: '2026-11', month_rewarded: 5 }), { month_key: '2026-11', month_rewarded: 5 });
    assert.deepEqual(parseReferrerCounter({ month_rewarded: -2 }), { month_key: null, month_rewarded: 0 });
  });
});
