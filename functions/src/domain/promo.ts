/**
 * Promo codes (ARCHITECTURE §9.2). Pure decisions; handlers/promo.ts runs
 * them inside one Firestore transaction.
 *
 * promo_codes/{CODE}: {credits: 1..10, max_redemptions: int|null,
 *   redemptions: int, expires_at: Timestamp|null, active: bool, note,
 *   created_by, created_at}
 * promo_codes/{CODE}/redemptions/{uid}: {at}
 * promo_attempts/{uid}_{yyyy-mm-dd}: {count} — every promoRedeem call counts
 *   (successful or not), at most PROMO_DAILY_ATTEMPTS per Bishkek day.
 */
import { isPromoCode, normalizeCode } from './codes';
import { DomainError, Reasons, validationError, type Reason } from './reasons';
import { bool, int, isRecord } from './types';

export const PROMO_DAILY_ATTEMPTS = 10;
export const PROMO_MIN_CREDITS = 1;
export const PROMO_MAX_CREDITS = 10;
export const PROMO_MAX_REDEMPTIONS = 1_000_000;
export const PROMO_NOTE_MAX = 200;

export interface PromoCodeState {
  credits: number;
  max_redemptions: number | null;
  redemptions: number;
  expires_at: number | null;
  active: boolean;
}

function msOrNull(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (isRecord(v) && typeof (v as { toMillis?: unknown }).toMillis === 'function') return (v as { toMillis: () => number }).toMillis();
  return null;
}

/** Tolerant parse of a promo_codes document (null when missing). */
export function parsePromoCode(raw: unknown): PromoCodeState | null {
  if (!isRecord(raw)) return null;
  const max = raw['max_redemptions'];
  return {
    credits: int(raw['credits']),
    max_redemptions: typeof max === 'number' && Number.isFinite(max) ? Math.trunc(max) : null,
    redemptions: Math.max(0, int(raw['redemptions'])),
    expires_at: msOrNull(raw['expires_at']),
    active: bool(raw['active'], false),
  };
}

export type PromoDecision =
  | { kind: 'redeem'; credits: number }
  | { kind: 'reject'; reason: Reason; countAttempt: boolean };

export interface PromoDecisionInput {
  /** normalizeCode + isPromoCode passed. */
  wellFormed: boolean;
  promo: PromoCodeState | null;
  alreadyRedeemed: boolean;
  /** Attempts already counted today (before this one). */
  attemptsToday: number;
  nowMs: number;
}

/**
 * Order: daily attempt cap -> unknown/inactive/misconfigured -> already
 * redeemed by this user -> expired -> exhausted -> redeem. Rejections after
 * the cap check still count as an attempt (brute-force protection).
 */
export function decidePromoRedeem(input: PromoDecisionInput): PromoDecision {
  if (input.attemptsToday >= PROMO_DAILY_ATTEMPTS) return { kind: 'reject', reason: Reasons.RATE_LIMITED, countAttempt: false };
  const p = input.promo;
  if (!input.wellFormed || !p || !p.active || p.credits < PROMO_MIN_CREDITS || p.credits > PROMO_MAX_CREDITS) {
    return { kind: 'reject', reason: Reasons.CODE_INVALID, countAttempt: true };
  }
  if (input.alreadyRedeemed) return { kind: 'reject', reason: Reasons.ALREADY_REDEEMED, countAttempt: true };
  if (p.expires_at !== null && input.nowMs >= p.expires_at) return { kind: 'reject', reason: Reasons.CODE_EXPIRED, countAttempt: true };
  if (p.max_redemptions !== null && p.redemptions >= p.max_redemptions) {
    return { kind: 'reject', reason: Reasons.CODE_EXHAUSTED, countAttempt: true };
  }
  return { kind: 'redeem', credits: p.credits };
}

/** promo_attempts document id for `uid` on Bishkek day `dayKey`. */
export function promoAttemptsId(uid: string, dayKey: string): string {
  return `${uid}_${dayKey}`;
}

export interface PromoUpsert {
  code: string;
  credits: number;
  maxRedemptions: number | null;
  expiresAtMs: number | null;
  active: boolean;
  note: string;
  /** §9.7: refuse to touch an existing code (the CMS sends it when creating). */
  createOnly: boolean;
}

/** Validates adminUpsertPromoCode {code, credits, maxRedemptions?, expiresAt? (ms), active, note, createOnly?}. */
export function parsePromoUpsert(data: Record<string, unknown>): PromoUpsert {
  const code = normalizeCode(data['code']);
  if (!isPromoCode(code)) throw validationError('code must be 4-20 characters A-Z0-9', { field: 'code' });
  const credits = data['credits'];
  if (typeof credits !== 'number' || !Number.isInteger(credits) || credits < PROMO_MIN_CREDITS || credits > PROMO_MAX_CREDITS) {
    throw validationError(`credits must be an integer in [${PROMO_MIN_CREDITS}, ${PROMO_MAX_CREDITS}]`, { field: 'credits' });
  }
  const maxRaw = data['maxRedemptions'];
  let maxRedemptions: number | null = null;
  if (maxRaw !== undefined && maxRaw !== null) {
    if (typeof maxRaw !== 'number' || !Number.isInteger(maxRaw) || maxRaw < 1 || maxRaw > PROMO_MAX_REDEMPTIONS) {
      throw validationError(`maxRedemptions must be null or an integer in [1, ${PROMO_MAX_REDEMPTIONS}]`, { field: 'maxRedemptions' });
    }
    maxRedemptions = maxRaw;
  }
  const expRaw = data['expiresAt'];
  let expiresAtMs: number | null = null;
  if (expRaw !== undefined && expRaw !== null) {
    // Epoch milliseconds between 2020 and 2100.
    if (typeof expRaw !== 'number' || !Number.isInteger(expRaw) || expRaw < 1_577_836_800_000 || expRaw > 4_102_444_800_000) {
      throw validationError('expiresAt must be null or epoch milliseconds', { field: 'expiresAt' });
    }
    expiresAtMs = expRaw;
  }
  if (typeof data['active'] !== 'boolean') throw validationError('active must be a boolean', { field: 'active' });
  const noteRaw = data['note'];
  if (noteRaw !== undefined && noteRaw !== null && (typeof noteRaw !== 'string' || noteRaw.length > PROMO_NOTE_MAX)) {
    throw validationError(`note must be a string of at most ${PROMO_NOTE_MAX} characters`, { field: 'note' });
  }
  const createOnly = data['createOnly'];
  if (createOnly !== undefined && createOnly !== null && typeof createOnly !== 'boolean') {
    throw validationError('createOnly must be a boolean', { field: 'createOnly' });
  }
  return {
    code,
    credits,
    maxRedemptions,
    expiresAtMs,
    active: data['active'],
    note: typeof noteRaw === 'string' ? noteRaw.trim() : '',
    createOnly: createOnly === true,
  };
}

/**
 * adminUpsertPromoCode on an existing / missing code (ARCHITECTURE §9.7):
 * with `createOnly` (the CMS "create" dialog) an existing code is refused
 * with VALIDATION_FAILED `why: 'exists'` and nothing changes; otherwise an
 * existing code is updated.
 */
export function decidePromoUpsert(exists: boolean, createOnly: boolean): 'create' | 'update' {
  if (!exists) return 'create';
  if (createOnly) {
    throw new DomainError(Reasons.VALIDATION_FAILED, 'promo code already exists', { why: 'exists', field: 'code' }, 'already-exists');
  }
  return 'update';
}

/** Throws the rejection as a DomainError (handlers call it after the transaction commits). */
export function promoRejection(reason: Reason): DomainError {
  const messages: Partial<Record<Reason, string>> = {
    RATE_LIMITED: 'too many promo code attempts today',
    CODE_INVALID: 'promo code is not valid',
    ALREADY_REDEEMED: 'promo code already redeemed',
    CODE_EXPIRED: 'promo code has expired',
    CODE_EXHAUSTED: 'promo code is no longer available',
  };
  return new DomainError(reason, messages[reason] ?? reason);
}
