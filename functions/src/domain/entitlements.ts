/**
 * Entitlement rules (ARCHITECTURE §1.5): the first full mock exam is free
 * once per account, every further attempt costs one credit, resuming an
 * in-progress attempt of the same variant costs nothing. Credits never go
 * below zero; a refund of already-spent credits is recorded as debt and is
 * settled from the next purchase.
 */
import { bool, int, isRecord, strOrNull } from './types';

export interface EntitlementState {
  free_exam_used: boolean;
  free_exam_used_at: number | null;
  free_exam_attempt_id: string | null;
  /** Count of free exams consumed (supports config freeExamsPerUser > 1). */
  free_exams_used_count: number;
  credits: number;
  lifetime_credits_purchased: number;
  /** Credits refunded after they were already spent (clawback shortfall). */
  debt_credits: number;
}

export type LedgerReason = 'purchase' | 'exam_start' | 'refund' | 'admin_grant' | 'free_first';

export interface LedgerEntry {
  delta: number;
  balance_after: number;
  reason: LedgerReason;
}

export const EMPTY_ENTITLEMENT: EntitlementState = Object.freeze({
  free_exam_used: false,
  free_exam_used_at: null,
  free_exam_attempt_id: null,
  free_exams_used_count: 0,
  credits: 0,
  lifetime_credits_purchased: 0,
  debt_credits: 0,
});

/** `toMillis` duck-typing so Firestore Timestamps parse without importing them. */
function msOrNull(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (isRecord(v) && typeof (v as { toMillis?: unknown }).toMillis === 'function') {
    return (v as { toMillis: () => number }).toMillis();
  }
  return null;
}

export function parseEntitlement(raw: unknown): EntitlementState {
  if (!isRecord(raw)) return { ...EMPTY_ENTITLEMENT };
  const used = bool(raw['free_exam_used'], false);
  const count = Math.max(int(raw['free_exams_used_count'], used ? 1 : 0), used ? 1 : 0);
  return {
    free_exam_used: used || count > 0,
    free_exam_used_at: msOrNull(raw['free_exam_used_at']),
    free_exam_attempt_id: strOrNull(raw['free_exam_attempt_id']),
    free_exams_used_count: count,
    credits: Math.max(0, int(raw['credits'])),
    lifetime_credits_purchased: Math.max(0, int(raw['lifetime_credits_purchased'])),
    debt_credits: Math.max(0, int(raw['debt_credits'])),
  };
}

/**
 * `config/pricing.free_exams_per_user`: an integer in
 * [FREE_EXAMS_PER_USER_MIN, FREE_EXAMS_PER_USER_MAX] (0..5 inclusive).
 * adminUpdatePricing rejects anything else with VALIDATION_FAILED; on read a
 * missing or out-of-range value means the default. The admin CMS and the
 * student client (billing/domain/pricing_config.dart) mirror this range.
 */
export const FREE_EXAMS_PER_USER_MIN = 0;
export const FREE_EXAMS_PER_USER_MAX = 5;
export const FREE_EXAMS_PER_USER_DEFAULT = 1;

export function isValidFreeExamsPerUser(v: unknown): v is number {
  return typeof v === 'number' && Number.isInteger(v) && v >= FREE_EXAMS_PER_USER_MIN && v <= FREE_EXAMS_PER_USER_MAX;
}

/** Stored value -> effective number of free exams (default when invalid). */
export function parseFreeExamsPerUser(v: unknown): number {
  return isValidFreeExamsPerUser(v) ? v : FREE_EXAMS_PER_USER_DEFAULT;
}

export type StartDecision =
  | { kind: 'resume'; attemptId: string }
  | { kind: 'free_first' }
  | { kind: 'credit' }
  | { kind: 'none' };

export interface StartDecisionInput {
  entitlement: EntitlementState;
  /** Id of an in-progress attempt of the SAME variant, if any. */
  inProgressAttemptId: string | null;
  /** config/pricing.free_exams_per_user (default 1). */
  freeExamsPerUser: number;
}

export function decideExamStart(input: StartDecisionInput): StartDecision {
  if (input.inProgressAttemptId) return { kind: 'resume', attemptId: input.inProgressAttemptId };
  const freeAllowed = Math.max(0, Math.trunc(input.freeExamsPerUser));
  if (input.entitlement.free_exams_used_count < freeAllowed) return { kind: 'free_first' };
  if (input.entitlement.credits >= 1) return { kind: 'credit' };
  return { kind: 'none' };
}

export interface StartApplication {
  entitlement: EntitlementState;
  ledger: LedgerEntry;
  entitlementSource: 'free_first' | 'credit';
}

/** New entitlement state after starting an attempt with the given decision. */
export function applyStartDecision(
  ent: EntitlementState,
  decision: StartDecision,
  attemptId: string,
  nowMs: number,
): StartApplication {
  if (decision.kind === 'free_first') {
    const next: EntitlementState = {
      ...ent,
      free_exam_used: true,
      free_exam_used_at: ent.free_exam_used_at ?? nowMs,
      free_exam_attempt_id: ent.free_exam_attempt_id ?? attemptId,
      free_exams_used_count: ent.free_exams_used_count + 1,
    };
    return { entitlement: next, ledger: { delta: 0, balance_after: next.credits, reason: 'free_first' }, entitlementSource: 'free_first' };
  }
  if (decision.kind === 'credit') {
    if (ent.credits < 1) throw new Error('applyStartDecision: no credits');
    const next = { ...ent, credits: ent.credits - 1 };
    return { entitlement: next, ledger: { delta: -1, balance_after: next.credits, reason: 'exam_start' }, entitlementSource: 'credit' };
  }
  throw new Error(`applyStartDecision: cannot apply ${decision.kind}`);
}

export interface GrantApplication {
  entitlement: EntitlementState;
  /** Credits actually added to the balance (after settling debt). */
  netCredits: number;
  debtSettled: number;
  ledger: LedgerEntry;
}

/** Adds purchased credits; outstanding refund debt is settled first. */
export function applyPurchaseGrant(ent: EntitlementState, credits: number): GrantApplication {
  if (!Number.isInteger(credits) || credits <= 0) throw new Error('applyPurchaseGrant: credits must be > 0');
  const debtSettled = Math.min(ent.debt_credits, credits);
  const netCredits = credits - debtSettled;
  const next: EntitlementState = {
    ...ent,
    credits: ent.credits + netCredits,
    lifetime_credits_purchased: ent.lifetime_credits_purchased + credits,
    debt_credits: ent.debt_credits - debtSettled,
  };
  return { entitlement: next, netCredits, debtSettled, ledger: { delta: netCredits, balance_after: next.credits, reason: 'purchase' } };
}

export interface ClawbackApplication {
  entitlement: EntitlementState;
  clawedBack: number;
  /** Credits that could not be taken back because they were already spent. */
  newDebt: number;
  ledger: LedgerEntry;
}

/** Revokes credits of a refunded/voided purchase. Never goes below zero. */
export function applyClawback(ent: EntitlementState, creditsGranted: number): ClawbackApplication {
  const want = Math.max(0, Math.trunc(creditsGranted));
  const clawedBack = Math.min(ent.credits, want);
  const newDebt = want - clawedBack;
  const next: EntitlementState = {
    ...ent,
    credits: ent.credits - clawedBack,
    debt_credits: ent.debt_credits + newDebt,
  };
  return { entitlement: next, clawedBack, newDebt, ledger: { delta: -clawedBack, balance_after: next.credits, reason: 'refund' } };
}

export interface AdminAdjustment {
  entitlement: EntitlementState;
  applied: number;
  ledger: LedgerEntry;
}

/** Admin credit grant/correction; negative deltas clamp at zero. */
export function applyAdminDelta(ent: EntitlementState, delta: number): AdminAdjustment {
  if (!Number.isInteger(delta) || delta === 0) throw new Error('applyAdminDelta: delta must be a non-zero integer');
  const credits = Math.max(0, ent.credits + delta);
  const applied = credits - ent.credits;
  const next = { ...ent, credits };
  return { entitlement: next, applied, ledger: { delta: applied, balance_after: credits, reason: 'admin_grant' } };
}
