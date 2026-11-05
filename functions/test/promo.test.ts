import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { applyBonusCredits, EMPTY_ENTITLEMENT } from '../src/domain/entitlements';
import {
  decidePromoRedeem,
  decidePromoUpsert,
  parsePromoCode,
  parsePromoUpsert,
  PROMO_DAILY_ATTEMPTS,
  promoAttemptsId,
  promoRejection,
  type PromoCodeState,
} from '../src/domain/promo';
import { DomainError } from '../src/domain/reasons';

const now = Date.UTC(2026, 10, 5, 6);
const promo = (over: Partial<PromoCodeState> = {}): PromoCodeState => ({
  credits: 2,
  max_redemptions: null,
  redemptions: 0,
  expires_at: null,
  active: true,
  ...over,
});
const input = (over: Partial<Parameters<typeof decidePromoRedeem>[0]> = {}) => ({
  wellFormed: true,
  promo: promo(),
  alreadyRedeemed: false,
  attemptsToday: 0,
  nowMs: now,
  ...over,
});

describe('promoRedeem decision (ARCHITECTURE §9.2)', () => {
  it('redeems a valid code for its credits', () => {
    assert.deepEqual(decidePromoRedeem(input()), { kind: 'redeem', credits: 2 });
    assert.deepEqual(decidePromoRedeem(input({ promo: promo({ max_redemptions: 5, redemptions: 4, expires_at: now + 1 }) })), {
      kind: 'redeem',
      credits: 2,
    });
  });

  it('the 11th attempt of the day is RATE_LIMITED and is not counted again', () => {
    assert.equal(decidePromoRedeem(input({ attemptsToday: PROMO_DAILY_ATTEMPTS - 1 })).kind, 'redeem');
    assert.deepEqual(decidePromoRedeem(input({ attemptsToday: PROMO_DAILY_ATTEMPTS })), { kind: 'reject', reason: 'RATE_LIMITED', countAttempt: false });
    // Even a valid, unredeemed code is refused once the cap is reached.
    assert.equal(decidePromoRedeem(input({ attemptsToday: 99 })).kind, 'reject');
  });

  it('unknown, malformed, inactive or misconfigured codes are CODE_INVALID (and count as attempts)', () => {
    for (const over of [
      { wellFormed: false },
      { promo: null },
      { promo: promo({ active: false }) },
      { promo: promo({ credits: 0 }) },
      { promo: promo({ credits: 11 }) },
    ]) {
      assert.deepEqual(decidePromoRedeem(input(over)), { kind: 'reject', reason: 'CODE_INVALID', countAttempt: true }, JSON.stringify(over));
    }
  });

  it('order: already redeemed beats expired and exhausted', () => {
    const r = decidePromoRedeem(input({ alreadyRedeemed: true, promo: promo({ expires_at: now - 1, max_redemptions: 1, redemptions: 1 }) }));
    assert.deepEqual(r, { kind: 'reject', reason: 'ALREADY_REDEEMED', countAttempt: true });
  });

  it('expired at exactly expires_at; exhausted at max_redemptions', () => {
    assert.equal((decidePromoRedeem(input({ promo: promo({ expires_at: now }) })) as { reason: string }).reason, 'CODE_EXPIRED');
    assert.equal((decidePromoRedeem(input({ promo: promo({ max_redemptions: 3, redemptions: 3 }) })) as { reason: string }).reason, 'CODE_EXHAUSTED');
  });

  it('parsePromoCode tolerates Timestamps and missing fields', () => {
    assert.equal(parsePromoCode(undefined), null);
    const p = parsePromoCode({ credits: 3, max_redemptions: null, expires_at: { toMillis: () => 123 }, active: true });
    assert.deepEqual(p, { credits: 3, max_redemptions: null, redemptions: 0, expires_at: 123, active: true });
    assert.equal(parsePromoCode({ credits: 1 })!.active, false, 'active must be explicit');
  });

  it('attempt counter ids are per uid and Bishkek day', () => {
    assert.equal(promoAttemptsId('u1', '2026-11-05'), 'u1_2026-11-05');
  });

  it('rejections carry details.reason codes', () => {
    const e = promoRejection('ALREADY_REDEEMED');
    assert.ok(e instanceof DomainError);
    assert.equal(e.reason, 'ALREADY_REDEEMED');
    assert.equal(e.code, 'already-exists');
    assert.equal(promoRejection('RATE_LIMITED').code, 'resource-exhausted');
    assert.equal(promoRejection('CODE_INVALID').code, 'not-found');
  });

  it('promo credits are a ledger "promo" bonus, not a purchase', () => {
    const r = applyBonusCredits({ ...EMPTY_ENTITLEMENT, credits: 1, debt_credits: 2 }, 3, 'promo');
    assert.equal(r.entitlement.credits, 4);
    assert.equal(r.entitlement.lifetime_credits_purchased, 0);
    assert.equal(r.entitlement.debt_credits, 2);
    assert.deepEqual(r.ledger, { delta: 3, balance_after: 4, reason: 'promo' });
    assert.throws(() => applyBonusCredits(EMPTY_ENTITLEMENT, 0, 'promo'));
  });
});

describe('adminUpsertPromoCode validation', () => {
  const ok = { code: ' welcome-2026 ', credits: 2, maxRedemptions: 100, expiresAt: Date.UTC(2027, 0, 1), active: true, note: ' launch ' };

  it('normalizes the code and accepts the full shape', () => {
    assert.deepEqual(parsePromoUpsert(ok), {
      code: 'WELCOME2026',
      credits: 2,
      maxRedemptions: 100,
      expiresAtMs: Date.UTC(2027, 0, 1),
      active: true,
      note: 'launch',
      createOnly: false,
    });
  });

  it('createOnly (§9.7): optional boolean; on an existing code it refuses with why "exists"', () => {
    assert.equal(parsePromoUpsert({ ...ok, createOnly: true }).createOnly, true);
    assert.equal(parsePromoUpsert({ ...ok, createOnly: false }).createOnly, false);
    assert.equal(parsePromoUpsert({ ...ok, createOnly: null }).createOnly, false);
    for (const bad of ['yes', 1, {}]) {
      assert.throws(() => parsePromoUpsert({ ...ok, createOnly: bad }), (e: unknown) => e instanceof DomainError && e.reason === 'VALIDATION_FAILED');
    }
    assert.equal(decidePromoUpsert(false, true), 'create');
    assert.equal(decidePromoUpsert(false, false), 'create');
    assert.equal(decidePromoUpsert(true, false), 'update', 'the edit dialog still updates');
    let err: unknown;
    try {
      decidePromoUpsert(true, true);
    } catch (e) {
      err = e;
    }
    assert.ok(err instanceof DomainError);
    assert.equal(err.reason, 'VALIDATION_FAILED');
    assert.equal(err.extra?.['why'], 'exists');
    assert.equal(err.code, 'already-exists');
  });

  it('optional fields may be omitted or null', () => {
    const p = parsePromoUpsert({ code: 'ABCD', credits: 1, active: false });
    assert.equal(p.maxRedemptions, null);
    assert.equal(p.expiresAtMs, null);
    assert.equal(p.note, '');
    assert.equal(parsePromoUpsert({ ...ok, maxRedemptions: null, expiresAt: null, note: null }).maxRedemptions, null);
  });

  it('rejects bad codes, credits, limits, dates, flags and notes', () => {
    const bad: Array<Record<string, unknown>> = [
      { ...ok, code: 'AB' },
      { ...ok, code: 'ORT_2026' },
      { ...ok, code: 7 },
      { ...ok, credits: 0 },
      { ...ok, credits: 11 },
      { ...ok, credits: 1.5 },
      { ...ok, credits: '2' },
      { ...ok, maxRedemptions: 0 },
      { ...ok, maxRedemptions: 2.5 },
      { ...ok, expiresAt: 'tomorrow' },
      { ...ok, expiresAt: 1000 },
      { ...ok, active: 'yes' },
      { code: 'ABCD', credits: 1 },
      { ...ok, note: 'x'.repeat(201) },
      { ...ok, note: 5 },
    ];
    for (const b of bad) {
      assert.throws(() => parsePromoUpsert(b), (e: unknown) => e instanceof DomainError && e.reason === 'VALIDATION_FAILED', JSON.stringify(b));
    }
  });
});
