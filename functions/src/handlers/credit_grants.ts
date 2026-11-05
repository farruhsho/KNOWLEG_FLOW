/**
 * Paid credit grants and their clawback, shared by Google Play
 * (billing.ts) and web payments (payments.ts) so both follow exactly the
 * same rules (ARCHITECTURE §1.5, §9.1, §9.7, §10.3):
 *  - a paid grant settles refund debt first, counts towards
 *    lifetime_credits_purchased, writes a ledger line {reason: 'purchase'};
 *  - the referred user's first paid, non-test grant pays the referral reward
 *    (+1 both, monthly cap) in the same transaction (handlers/referral.ts);
 *  - a refund claws the credits back (debt if spent) and undoes the referral
 *    reward that grant paid (ledger reason 'refund', item 'revoked').
 *
 * Each pair is split into READS (must run before any write of the
 * transaction) and WRITES. The record that paid the grant (purchases/{id} or
 * payment_orders/{id}) stores `referralPurchaseFields(...)` so the clawback
 * can find the reward.
 */
import type { DocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { applyClawback, applyPurchaseGrant, parseEntitlement, type EntitlementState, type GrantApplication } from '../domain/entitlements';
import { str } from '../domain/types';
import { db, FieldValue } from './common';
import {
  readReferralClawback,
  readReferralReward,
  referralPurchaseFields,
  writeReferralClawback,
  writeReferralReward,
  type ReferralClawbackReads,
  type ReferralRewardReads,
} from './referral';

const entRef = (uid: string) => db().doc(`entitlements/${uid}`);

export interface PaidGrantReads {
  uid: string;
  entitlement: EntitlementState;
  referral: ReferralRewardReads;
}

/** Transaction READS of a paid grant (entitlement, users/{uid}.referred_by, referral state). */
export async function readPaidGrant(tx: Transaction, uid: string, opts: { isTest: boolean; nowMs: number }): Promise<PaidGrantReads> {
  const [entSnap, userSnap] = await tx.getAll(entRef(uid), db().doc(`users/${uid}`));
  const referral = await readReferralReward(tx, uid, str(userSnap!.get('referred_by')) || null, opts.isTest, opts.nowMs);
  return { uid, entitlement: parseEntitlement(entSnap!.data()), referral };
}

export interface PaidGrantResult {
  applied: GrantApplication;
  /** State after the purchase AND the referral bonus. */
  entitlement: EntitlementState;
  /** Fields to store on the paying record (purchase / order) for a later clawback. */
  recordFields: Record<string, unknown>;
  referralRewarded: boolean;
}

/**
 * Transaction WRITES of a paid grant: entitlement, ledger line
 * `{reason: 'purchase', ref, ...ledgerExtra}` and the referral reward.
 */
export function writePaidGrant(
  tx: Transaction,
  reads: PaidGrantReads,
  credits: number,
  ledger: { ref: string; actorUid: string; extra?: Record<string, unknown> },
): PaidGrantResult {
  const applied = applyPurchaseGrant(reads.entitlement, credits);
  const finalEnt = writeReferralReward(tx, reads.uid, applied.entitlement, reads.referral, ledger.ref);
  const ref = entRef(reads.uid);
  tx.set(
    ref,
    {
      credits: finalEnt.credits,
      lifetime_credits_purchased: applied.entitlement.lifetime_credits_purchased,
      debt_credits: applied.entitlement.debt_credits,
      updated_at: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  tx.set(ref.collection('ledger').doc(), {
    ...applied.ledger,
    ref: ledger.ref,
    ...(ledger.extra ?? {}),
    actor_uid: ledger.actorUid,
    at: FieldValue.serverTimestamp(),
  });
  return {
    applied,
    entitlement: finalEnt,
    recordFields: referralPurchaseFields(reads.referral),
    referralRewarded: reads.referral.decision.kind === 'reward',
  };
}

export interface PaidClawbackReads {
  /** Live owner whose credits are clawed back; null = never granted / deleted account. */
  ownerUid: string | null;
  entitlement: EntitlementState | null;
  referral: ReferralClawbackReads | null;
}

/** Owner uid that may still lose credits (anonymized `deleted:*` accounts may not). */
export function liveOwner(uid: string, granted: boolean): string | null {
  return granted && !!uid && !uid.startsWith('deleted:') ? uid : null;
}

/**
 * Transaction READS of a clawback. `record` is the purchase / order that
 * paid the grant (its referral_referrer_* fields name the reward to undo);
 * `granted` false = nothing of the owner's to take back.
 */
export async function readPaidClawback(tx: Transaction, record: DocumentSnapshot, ownerUid: string | null, granted: boolean): Promise<PaidClawbackReads> {
  const owner = ownerUid && granted ? ownerUid : null;
  const referral = granted ? await readReferralClawback(tx, record, owner) : null;
  const entSnap = owner ? await tx.get(entRef(owner)) : null;
  return { ownerUid: owner, entitlement: entSnap ? parseEntitlement(entSnap.data()) : null, referral };
}

export interface PaidClawbackResult {
  clawedBack: number;
  newDebt: number;
  /** Present when the grant had paid a referral reward. */
  referralClawedBack?: { referee: number; referrer: number };
}

/**
 * Transaction WRITES of a clawback: the owner's entitlement + ledger line
 * `{reason: 'refund', ref, debt_added, ...}` and the referral clawback. With
 * no live owner only a rewarded referrer loses the bonus.
 */
export function writePaidClawback(
  tx: Transaction,
  reads: PaidClawbackReads,
  credits: number,
  ledger: { ref: string; actorUid: string; source: string; extra?: Record<string, unknown> },
): PaidClawbackResult {
  const actor = { actorUid: ledger.actorUid, source: ledger.source };
  if (!reads.ownerUid || !reads.entitlement) {
    const r = reads.referral ? writeReferralClawback(tx, reads.referral, null, ledger.ref, actor) : null;
    return { clawedBack: 0, newDebt: 0, ...(r ? { referralClawedBack: { referee: 0, referrer: r.referrerClawedBack } } : {}) };
  }
  const applied = applyClawback(reads.entitlement, credits);
  const r = reads.referral ? writeReferralClawback(tx, reads.referral, applied.entitlement, ledger.ref, actor) : null;
  const finalEnt = r?.refereeEntitlement ?? applied.entitlement;
  const ref = entRef(reads.ownerUid);
  tx.set(ref, { credits: finalEnt.credits, debt_credits: finalEnt.debt_credits, updated_at: FieldValue.serverTimestamp() }, { merge: true });
  tx.set(ref.collection('ledger').doc(), {
    ...applied.ledger,
    ref: ledger.ref,
    debt_added: applied.newDebt,
    ...(ledger.extra ?? {}),
    actor_uid: ledger.actorUid,
    source: ledger.source,
    at: FieldValue.serverTimestamp(),
  });
  return {
    clawedBack: applied.clawedBack,
    newDebt: applied.newDebt,
    ...(r ? { referralClawedBack: { referee: r.refereeClawedBack, referrer: r.referrerClawedBack } } : {}),
  };
}
