/**
 * Referrals (ARCHITECTURE §9.1). Pure decisions; the handlers persist them
 * in transactions.
 *
 * - referralApply {code}: once per account, never the caller's own code, and
 *   only while the caller has no completed exams and no purchases
 *   (REFERRAL_NOT_ALLOWED). Re-applying the code already applied is an
 *   idempotent success (a retry after a lost response).
 * - Reward: on the referred user's first paid credit grant
 *   (billingVerifyPurchase), the referred user gets +1 credit and the
 *   referrer +1 credit (ledger reason 'referral'), the item becomes
 *   `rewarded`. The referrer gets at most REFERRAL_MONTHLY_CAP rewards per
 *   Bishkek calendar month; past the cap only the referred user is rewarded.
 *   Idempotent per referred uid (the item status), test purchases never
 *   reward, and a deleted referrer is skipped.
 * - Refund / void of the rewarding purchase (§9.7): both bonuses are clawed
 *   back with the purchase (ledger reason 'refund', debt when spent) and the
 *   item becomes 'revoked' — terminal, the referee is never rewarded again.
 */
import { DomainError, Reasons } from './reasons';
import { int, isRecord, str } from './types';

export const REFERRAL_MONTHLY_CAP = 20;
export const REFERRAL_REWARD_CREDITS = 1;

export type ApplyBlock = 'own_code' | 'already_referred' | 'has_exams' | 'has_purchases';

export type ApplyDecision = { kind: 'apply' } | { kind: 'noop' } | { kind: 'reject'; why: ApplyBlock };

export interface ApplyInput {
  callerUid: string;
  /** Owner of the code (referral_codes/{code}.uid). */
  referrerUid: string;
  /** users/{caller}.referred_by, if set. */
  currentReferredBy: string | null;
  /** user_stats.exams_completed */
  examsCompleted: number;
  /** entitlements.lifetime_credits_purchased */
  lifetimeCreditsPurchased: number;
  /** Any purchases/{id} with uid == caller (granted or not). */
  hasPurchaseRecords: boolean;
}

export function decideReferralApply(input: ApplyInput): ApplyDecision {
  if (input.referrerUid === input.callerUid) return { kind: 'reject', why: 'own_code' };
  if (input.currentReferredBy) {
    return input.currentReferredBy === input.referrerUid ? { kind: 'noop' } : { kind: 'reject', why: 'already_referred' };
  }
  if (input.examsCompleted > 0) return { kind: 'reject', why: 'has_exams' };
  if (input.lifetimeCreditsPurchased > 0 || input.hasPurchaseRecords) return { kind: 'reject', why: 'has_purchases' };
  return { kind: 'apply' };
}

export function referralRejection(why: ApplyBlock): DomainError {
  return new DomainError(Reasons.REFERRAL_NOT_ALLOWED, `referral not allowed: ${why}`, { why });
}

/** Monthly reward counter on referrals/{referrerUid}. */
export interface ReferrerCounter {
  month_key: string | null;
  month_rewarded: number;
}

export function parseReferrerCounter(raw: unknown): ReferrerCounter {
  if (!isRecord(raw)) return { month_key: null, month_rewarded: 0 };
  return { month_key: str(raw['month_key']) || null, month_rewarded: Math.max(0, int(raw['month_rewarded'])) };
}

export interface RewardInput {
  /** users/{referee}.referred_by */
  referredBy: string | null;
  refereeUid: string;
  /** referrals/{referrer}/items/{referee}.status (null when the item is missing). */
  itemStatus: string | null;
  /** users/{referrer} still exists. */
  referrerExists: boolean;
  counter: ReferrerCounter;
  /** bishkekMonthKey(now) */
  monthKey: string;
  /** Play test (license tester) purchase. */
  isTestPurchase: boolean;
}

export type RewardDecision =
  | { kind: 'none' }
  | {
      kind: 'reward';
      referrerUid: string;
      rewardReferrer: boolean;
      /** The referrer was skipped because of the monthly cap. */
      capped: boolean;
      /** Counter value to store when rewardReferrer. */
      counter: ReferrerCounter;
    };

export function decideReferralReward(input: RewardInput): RewardDecision {
  const referrer = input.referredBy;
  if (!referrer || referrer === input.refereeUid || input.isTestPurchase) return { kind: 'none' };
  // One reward per referee: a reward clawed back after a refund ('revoked') is not paid again.
  if (input.itemStatus === 'rewarded' || input.itemStatus === 'revoked') return { kind: 'none' };
  const sameMonth = input.counter.month_key === input.monthKey;
  const used = sameMonth ? input.counter.month_rewarded : 0;
  const capped = input.referrerExists && used >= REFERRAL_MONTHLY_CAP;
  const rewardReferrer = input.referrerExists && !capped;
  return {
    kind: 'reward',
    referrerUid: referrer,
    rewardReferrer,
    capped,
    counter: { month_key: input.monthKey, month_rewarded: rewardReferrer ? used + 1 : used },
  };
}

export interface ReferralClawbackInput {
  /** purchases/{id}.referral_referrer_uid: set when this purchase paid out the reward. */
  referrerUid: string | null;
  /** purchases/{id}.referral_referrer_rewarded: the referrer got +1 (not capped / not deleted). */
  referrerRewarded: boolean;
  /** The purchase owner (referee) still has an account (purchase uid not anonymized). */
  refereeLive: boolean;
  /** entitlements/{referrer} exists (the reward wrote it; missing = the referrer deleted the account). */
  referrerEntitlementExists: boolean;
  /** referrals/{referrer}/items/{referee}.status, null when missing. */
  itemStatus: string | null;
}

export interface ReferralClawback {
  /** Take back the referee's +1. */
  referee: boolean;
  /** Take back the referrer's +1. */
  referrer: boolean;
  /** Set the item to status 'revoked'. */
  markItem: boolean;
}

/**
 * Refund / void of the purchase that paid the referral reward (ARCHITECTURE
 * §9.7): both bonuses are clawed back like the purchase itself (debt when
 * already spent), the item becomes 'revoked'. Null when the purchase paid
 * no reward. Deleted accounts are skipped (their entitlements are gone).
 */
export function decideReferralClawback(input: ReferralClawbackInput): ReferralClawback | null {
  if (!input.referrerUid) return null;
  return {
    referee: input.refereeLive,
    referrer: input.referrerRewarded && input.referrerEntitlementExists,
    markItem: input.refereeLive && input.itemStatus !== null && input.itemStatus !== 'revoked',
  };
}
