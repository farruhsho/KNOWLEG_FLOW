import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { applyBonusCredits, applyClawback, applyPurchaseGrant, EMPTY_ENTITLEMENT } from '../src/domain/entitlements';
import { DomainError } from '../src/domain/reasons';
import {
  decideReferralApply,
  decideReferralClawback,
  decideReferralReward,
  parseReferrerCounter,
  REFERRAL_MONTHLY_CAP,
  REFERRAL_REWARD_CREDITS,
  referralRejection,
  type ReferralClawbackInput,
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

  it('a reward clawed back after a refund (item revoked) is never paid again', () => {
    assert.deepEqual(decideReferralReward({ ...base, itemStatus: 'revoked' }), { kind: 'none' });
  });
});

describe('referral reward clawback on refund / void (§9.7, P3-BE-02)', () => {
  const base: ReferralClawbackInput = {
    referrerUid: 'alice',
    referrerRewarded: true,
    refereeLive: true,
    referrerEntitlementExists: true,
    itemStatus: 'rewarded',
  };

  it('the rewarding purchase claws back both bonuses and revokes the item', () => {
    assert.deepEqual(decideReferralClawback(base), { referee: true, referrer: true, markItem: true });
  });

  it('a purchase that paid no reward (no referral_referrer_uid) changes nothing', () => {
    assert.equal(decideReferralClawback({ ...base, referrerUid: null }), null);
    assert.equal(decideReferralClawback({ ...base, referrerUid: '' }), null);
  });

  it('a capped referrer (no +1) keeps their balance; only the referee loses the bonus', () => {
    assert.deepEqual(decideReferralClawback({ ...base, referrerRewarded: false }), { referee: true, referrer: false, markItem: true });
  });

  it('deleted accounts are skipped: a deleted referee still costs the referrer the bonus', () => {
    assert.deepEqual(decideReferralClawback({ ...base, refereeLive: false, itemStatus: null }), { referee: false, referrer: true, markItem: false });
    assert.deepEqual(decideReferralClawback({ ...base, referrerEntitlementExists: false }), { referee: true, referrer: false, markItem: true });
    // The referrer deleted the account: the item went with it.
    assert.deepEqual(decideReferralClawback({ ...base, referrerEntitlementExists: false, itemStatus: null }), {
      referee: true,
      referrer: false,
      markItem: false,
    });
  });

  it('buy -> bonus -> refund leaves nobody with free credits; spent bonuses become debt', () => {
    // Referee buys exam_single (1 credit) and gets the referral +1; the referrer gets +1.
    const referee = applyBonusCredits(applyPurchaseGrant(EMPTY_ENTITLEMENT, 1).entitlement, REFERRAL_REWARD_CREDITS, 'referral').entitlement;
    const referrer = applyBonusCredits({ ...EMPTY_ENTITLEMENT, credits: 2 }, REFERRAL_REWARD_CREDITS, 'referral').entitlement;
    assert.deepEqual([referee.credits, referrer.credits], [2, 3]);
    // Refund: the purchase credit, then the referral credit (same applyClawback mechanism).
    const d = decideReferralClawback(base)!;
    const afterPurchase = applyClawback(referee, 1).entitlement;
    const refereeAfter = d.referee ? applyClawback(afterPurchase, REFERRAL_REWARD_CREDITS) : null;
    const referrerAfter = d.referrer ? applyClawback(referrer, REFERRAL_REWARD_CREDITS) : null;
    assert.deepEqual([refereeAfter!.entitlement.credits, refereeAfter!.entitlement.debt_credits], [0, 0]);
    assert.deepEqual(refereeAfter!.ledger, { delta: -1, balance_after: 0, reason: 'refund' });
    assert.deepEqual([referrerAfter!.entitlement.credits, referrerAfter!.entitlement.debt_credits], [2, 0]);
    // The referee already spent both credits on exams: the shortfall is recorded as debt.
    const spent = applyClawback(applyClawback({ ...referee, credits: 0 }, 1).entitlement, REFERRAL_REWARD_CREDITS);
    assert.deepEqual([spent.entitlement.credits, spent.entitlement.debt_credits, spent.newDebt], [0, 2, 1]);
    assert.equal(spent.clawedBack, 0);
    assert.equal(spent.ledger.reason, 'refund');
  });
});
