/**
 * Human-typed codes (ARCHITECTURE §9): referral codes (also used by
 * friendAdd), group join codes and promo codes. Pure: randomness is injected
 * so generation is deterministic in tests.
 *
 * - Referral / group join codes: 6 characters from CODE_ALPHABET (no 0/O,
 *   1/I to avoid misreading). 32^6 ≈ 1.07e9 combinations; uniqueness is
 *   guaranteed by the reservation documents `referral_codes/{code}` and
 *   `group_join_codes/{code}` created in a transaction.
 * - Promo codes: 4–20 characters `A-Z0-9`, stored upper-case as the
 *   `promo_codes/{CODE}` document id.
 */
import { DomainError, Reasons } from './reasons';

export const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const SHORT_CODE_LENGTH = 6;

const SHORT_CODE_RE = new RegExp(`^[${CODE_ALPHABET}]{${SHORT_CODE_LENGTH}}$`);
const PROMO_CODE_RE = /^[A-Z0-9]{4,20}$/;

/** Upper-cases and strips spaces / dashes a user may type around a code. */
export function normalizeCode(raw: unknown): string | null {
  if (typeof raw !== 'string' || raw.length > 64) return null;
  const t = raw.replace(/[\s-]+/g, '').toUpperCase();
  return t.length > 0 ? t : null;
}

/** A well-formed referral or group join code (after normalizeCode). */
export function isShortCode(code: unknown): code is string {
  return typeof code === 'string' && SHORT_CODE_RE.test(code);
}

/** A well-formed promo code id (after normalizeCode). */
export function isPromoCode(code: unknown): code is string {
  return typeof code === 'string' && PROMO_CODE_RE.test(code);
}

/**
 * Random 6-character code. `randomInt(n)` must return an integer in [0, n)
 * (crypto.randomInt in production).
 */
export function generateShortCode(randomInt: (n: number) => number): string {
  let out = '';
  for (let i = 0; i < SHORT_CODE_LENGTH; i++) {
    const k = randomInt(CODE_ALPHABET.length);
    if (!Number.isInteger(k) || k < 0 || k >= CODE_ALPHABET.length) throw new Error('randomInt out of range');
    out += CODE_ALPHABET[k];
  }
  return out;
}

/** Attempts at finding a free code before giving up (collisions are ~1e-9 each). */
export const MAX_CODE_ATTEMPTS = 8;

/**
 * Brute-force guard for typed 6-character codes (ARCHITECTURE §9.7):
 * groupJoin and friendAdd together allow CODE_DAILY_ATTEMPTS calls per user
 * per Bishkek day, failed ones included. Counter:
 * `code_attempts/{uid}_{yyyy-mm-dd}` = {uid, day, count} (server only).
 */
export const CODE_DAILY_ATTEMPTS = 30;

/** code_attempts document id for `uid` on Bishkek day `dayKey`. */
export function codeAttemptsId(uid: string, dayKey: string): string {
  return `${uid}_${dayKey}`;
}

/**
 * Checks the daily counter (`attemptsToday` = calls already counted today)
 * and returns the value to store for this call; RATE_LIMITED with
 * `details.what = 'code_attempts'` once the cap is reached (that call is
 * not counted).
 */
export function nextCodeAttemptCount(attemptsToday: number): number {
  const used = Math.max(0, Math.trunc(Number.isFinite(attemptsToday) ? attemptsToday : 0));
  if (used >= CODE_DAILY_ATTEMPTS) {
    throw new DomainError(Reasons.RATE_LIMITED, 'too many code attempts today', { what: 'code_attempts', limit: CODE_DAILY_ATTEMPTS });
  }
  return used + 1;
}
