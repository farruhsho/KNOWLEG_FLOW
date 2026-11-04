/**
 * Referrals and friends (ARCHITECTURE §9.1, §9.3):
 *   referralGetCode {}      -> {code}
 *   referralApply {code}    -> {ok}
 *   friendAdd {code}        -> {ok, friendUid, displayName}
 * The reward itself is granted inside billingVerifyPurchase (billing.ts,
 * applyReferralReward below).
 *
 * referral_codes/{code} = {uid, created_at}   (no client access)
 * users/{uid}.referral_code / .referred_by     (privileged, server-written)
 * referrals/{referrerUid} = {joined_total, rewarded_total, month_key, month_rewarded}
 * referrals/{referrerUid}/items/{uid} = {status: joined|rewarded, joined_at, rewarded_at?, display_name}
 * friends/{uid}/list/{friendUid} = {display_name, added_at}
 */
import '../config';
import { randomInt } from 'node:crypto';
import type { DocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';
import { generateShortCode, isShortCode, MAX_CODE_ATTEMPTS, normalizeCode } from '../domain/codes';
import { applyBonusCredits, parseEntitlement, type EntitlementState } from '../domain/entitlements';
import { decideFriendAdd, MAX_FRIENDS } from '../domain/groups';
import { DomainError, Reasons } from '../domain/reasons';
import {
  decideReferralApply,
  decideReferralReward,
  parseReferrerCounter,
  REFERRAL_REWARD_CREDITS,
  referralRejection,
  type RewardDecision,
} from '../domain/referral';
import { bishkekMonthKey } from '../domain/time';
import { int, str } from '../domain/types';
import { callableOptions, db, FieldValue, payload, requireActiveUser, wrap } from './common';
import { displayNameOf, statsRef } from './gamification';

const codeRef = (code: string) => db().doc(`referral_codes/${code}`);
const userRef = (uid: string) => db().doc(`users/${uid}`);
const referrerRef = (uid: string) => db().doc(`referrals/${uid}`);
const referralItemRef = (referrer: string, uid: string) => db().doc(`referrals/${referrer}/items/${uid}`);

function codeInvalid(): DomainError {
  return new DomainError(Reasons.CODE_INVALID, 'code is not valid');
}

function profileRequired(): DomainError {
  return new DomainError(Reasons.VALIDATION_FAILED, 'complete your profile first', { why: 'profile_missing' }, 'failed-precondition');
}

/** Owner uid of a referral code typed by a user, or CODE_INVALID. Deleted owners are invalid too. */
export async function resolveReferralCode(raw: unknown): Promise<{ code: string; uid: string; profile: DocumentSnapshot }> {
  const code = normalizeCode(raw);
  if (!isShortCode(code)) throw codeInvalid();
  const snap = await codeRef(code).get();
  const uid = snap.get('uid');
  if (typeof uid !== 'string' || !uid) throw codeInvalid();
  const profile = await userRef(uid).get();
  if (!profile.exists) throw codeInvalid();
  return { code, uid, profile };
}

// ---------------------------------------------------------------------------
// referralGetCode {} -> {code}

export const referralGetCode = onCall(
  callableOptions(),
  wrap('referralGetCode', async (req) => {
    const { uid, profile } = await requireActiveUser(req);
    const current = profile.get('referral_code');
    if (isShortCode(current) && (await codeRef(current).get()).get('uid') === uid) return { code: current };

    // Profile missing (or stale field): the reservation is the source of truth.
    const owned = await db().collection('referral_codes').where('uid', '==', uid).limit(1).get();
    if (!owned.empty) {
      const code = owned.docs[0]!.id;
      if (profile.exists) await userRef(uid).set({ referral_code: code }, { merge: true });
      return { code };
    }

    for (let i = 0; i < MAX_CODE_ATTEMPTS; i++) {
      const candidate = generateShortCode(randomInt);
      const code = await db().runTransaction(async (tx) => {
        const [codeSnap, userSnap] = await tx.getAll(codeRef(candidate), userRef(uid));
        const existing = userSnap!.get('referral_code');
        if (isShortCode(existing) && existing !== current) return existing; // a concurrent call won
        if (codeSnap!.exists) return null; // collision: try another code
        tx.set(codeRef(candidate), { uid, created_at: FieldValue.serverTimestamp() });
        // Never create users/{uid} here: the app creates the profile at sign-up.
        if (userSnap!.exists) tx.set(userRef(uid), { referral_code: candidate }, { merge: true });
        return candidate;
      });
      if (code) return { code };
    }
    throw new Error('could not allocate a referral code');
  }),
);

// ---------------------------------------------------------------------------
// referralApply {code} -> {ok}

export const referralApply = onCall(
  callableOptions(),
  wrap('referralApply', async (req) => {
    const { uid, profile } = await requireActiveUser(req);
    if (!profile.exists) throw profileRequired();
    const referrer = await resolveReferralCode(payload(req)['code']);
    // Any purchase record that ever granted credits blocks the referral.
    const purchases = await db().collection('purchases').where('uid', '==', uid).limit(20).get();
    const hasPurchaseRecords = purchases.docs.some((d) => ['granted', 'refunded', 'revoked'].includes(str(d.get('state'))));

    const decision = await db().runTransaction(async (tx) => {
      const [userSnap, statsSnap, entSnap] = await tx.getAll(userRef(uid), statsRef(uid), db().doc(`entitlements/${uid}`));
      const d = decideReferralApply({
        callerUid: uid,
        referrerUid: referrer.uid,
        currentReferredBy: str(userSnap!.get('referred_by')) || null,
        examsCompleted: int(statsSnap!.get('exams_completed')),
        lifetimeCreditsPurchased: parseEntitlement(entSnap!.data()).lifetime_credits_purchased,
        hasPurchaseRecords,
      });
      if (d.kind !== 'apply') return d;
      tx.set(userRef(uid), { referred_by: referrer.uid }, { merge: true });
      tx.set(referralItemRef(referrer.uid, uid), {
        status: 'joined',
        joined_at: FieldValue.serverTimestamp(),
        display_name: displayNameOf(userSnap!.data()),
      });
      tx.set(referrerRef(referrer.uid), { joined_total: FieldValue.increment(1), updated_at: FieldValue.serverTimestamp() }, { merge: true });
      return d;
    });
    if (decision.kind === 'reject') throw referralRejection(decision.why);
    if (decision.kind === 'apply') logger.info('referral applied', { uid, referrer: referrer.uid });
    return { ok: true };
  }),
);

// ---------------------------------------------------------------------------
// Reward hook (billingVerifyPurchase grant transaction)

export interface ReferralRewardReads {
  decision: RewardDecision;
  /** Referrer entitlement (read in the same transaction) when the referrer is rewarded. */
  referrerEntitlement: EntitlementState | null;
}

/**
 * Transaction READS for the referral reward of `refereeUid`. Must run before
 * any write of the transaction. `referredBy` comes from users/{referee}
 * read in the same transaction.
 */
export async function readReferralReward(
  tx: Transaction,
  refereeUid: string,
  referredBy: string | null,
  isTestPurchase: boolean,
  nowMs: number,
): Promise<ReferralRewardReads> {
  if (!referredBy || referredBy === refereeUid || isTestPurchase) return { decision: { kind: 'none' }, referrerEntitlement: null };
  const [item, counter, referrerUser, referrerEnt] = await tx.getAll(
    referralItemRef(referredBy, refereeUid),
    referrerRef(referredBy),
    userRef(referredBy),
    db().doc(`entitlements/${referredBy}`),
  );
  const decision = decideReferralReward({
    referredBy,
    refereeUid,
    itemStatus: item!.exists ? str(item!.get('status')) || 'joined' : null,
    referrerExists: referrerUser!.exists,
    counter: parseReferrerCounter(counter!.data()),
    monthKey: bishkekMonthKey(nowMs),
    isTestPurchase,
  });
  return { decision, referrerEntitlement: decision.kind === 'reward' && decision.rewardReferrer ? parseEntitlement(referrerEnt!.data()) : null };
}

/**
 * Transaction WRITES of the reward. `refereeEntitlement` is the referee's
 * state AFTER the purchase grant; returns the referee's state after the bonus.
 * The caller writes entitlements/{referee} itself (once, with the returned
 * state); this writes the referee's ledger line, the referrer's credit +
 * ledger, the item status and the monthly counter.
 */
export function writeReferralReward(
  tx: Transaction,
  refereeUid: string,
  refereeEntitlement: EntitlementState,
  reads: ReferralRewardReads,
  purchaseRef: string,
): EntitlementState {
  const d = reads.decision;
  if (d.kind !== 'reward') return refereeEntitlement;
  const refereeBonus = applyBonusCredits(refereeEntitlement, REFERRAL_REWARD_CREDITS, 'referral');
  const refereeEntRef = db().doc(`entitlements/${refereeUid}`);
  tx.set(refereeEntRef.collection('ledger').doc(), {
    ...refereeBonus.ledger,
    ref: `referral_${d.referrerUid}`,
    referral_role: 'referee',
    purchase_ref: purchaseRef,
    actor_uid: 'system',
    at: FieldValue.serverTimestamp(),
  });
  if (d.rewardReferrer && reads.referrerEntitlement) {
    const bonus = applyBonusCredits(reads.referrerEntitlement, REFERRAL_REWARD_CREDITS, 'referral');
    const ref = db().doc(`entitlements/${d.referrerUid}`);
    tx.set(ref, { credits: bonus.entitlement.credits, updated_at: FieldValue.serverTimestamp() }, { merge: true });
    tx.set(ref.collection('ledger').doc(), {
      ...bonus.ledger,
      ref: `referral_${refereeUid}`,
      referral_role: 'referrer',
      actor_uid: 'system',
      at: FieldValue.serverTimestamp(),
    });
  }
  tx.set(
    referralItemRef(d.referrerUid, refereeUid),
    {
      status: 'rewarded',
      rewarded_at: FieldValue.serverTimestamp(),
      referrer_rewarded: d.rewardReferrer,
      ...(d.capped ? { referrer_capped: true } : {}),
    },
    { merge: true },
  );
  if (d.rewardReferrer) {
    tx.set(
      referrerRef(d.referrerUid),
      {
        month_key: d.counter.month_key,
        month_rewarded: d.counter.month_rewarded,
        rewarded_total: FieldValue.increment(1),
        updated_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  return refereeBonus.entitlement;
}

// ---------------------------------------------------------------------------
// friendAdd {code} -> {ok, friendUid, displayName}

export const friendAdd = onCall(
  callableOptions(),
  wrap('friendAdd', async (req) => {
    const { uid } = await requireActiveUser(req);
    const friend = await resolveReferralCode(payload(req)['code']);
    const displayName = displayNameOf(friend.profile.data());
    const list = db().collection(`friends/${uid}/list`);
    const added = await db().runTransaction(async (tx) => {
      const [existing, current] = await Promise.all([tx.get(list.doc(friend.uid)), tx.get(list.select().limit(MAX_FRIENDS))]);
      const d = decideFriendAdd({ callerUid: uid, friendUid: friend.uid, alreadyFriend: existing.exists, friendCount: current.size });
      if (d.kind === 'add') tx.set(list.doc(friend.uid), { display_name: displayName, added_at: FieldValue.serverTimestamp() });
      return d.kind === 'add';
    });
    if (added) logger.info('friend added', { uid, friendUid: friend.uid });
    return { ok: true, friendUid: friend.uid, displayName };
  }),
);
