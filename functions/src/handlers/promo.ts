/**
 * Promo codes (ARCHITECTURE §9.2):
 *   promoRedeem {code}  -> {credits, balance}
 *   adminUpsertPromoCode {code, credits, maxRedemptions?, expiresAt? (ms), active, note} -> {ok, code}
 *
 * promoRedeem runs one transaction that always counts the attempt in
 * promo_attempts/{uid}_{yyyy-mm-dd} (Bishkek day, ≤ 10/day) and, when the
 * code is valid, writes the redemption, the counter and the credits. The
 * rejection is thrown only after the transaction committed, so failed
 * attempts are counted too. A promo code is not a payment method and works
 * in both BILLING_MODEs.
 */
import '../config';
import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';
import { isPromoCode, normalizeCode } from '../domain/codes';
import { applyBonusCredits, parseEntitlement } from '../domain/entitlements';
import { decidePromoRedeem, parsePromoCode, parsePromoUpsert, promoAttemptsId, promoRejection } from '../domain/promo';
import { bishkekDayKey } from '../domain/time';
import { int } from '../domain/types';
import { adminCallableOptions, callableOptions, db, FieldValue, msToTs, payload, requireActiveUser, requirePermission, wrap, writeAdminLog } from './common';

// ---------------------------------------------------------------------------
// promoRedeem {code} -> {credits, balance}

export const promoRedeem = onCall(
  callableOptions(),
  wrap('promoRedeem', async (req) => {
    const { uid } = await requireActiveUser(req);
    const code = normalizeCode(payload(req)['code']);
    const wellFormed = isPromoCode(code);
    const nowMs = Date.now();
    const attemptsRef = db().doc(`promo_attempts/${promoAttemptsId(uid, bishkekDayKey(nowMs))}`);
    const entRef = db().doc(`entitlements/${uid}`);
    // Malformed input never touches promo_codes (ids could contain anything).
    const promoRef = wellFormed ? db().doc(`promo_codes/${code}`) : null;

    const outcome = await db().runTransaction(async (tx) => {
      const refs = promoRef ? [attemptsRef, entRef, promoRef, promoRef.collection('redemptions').doc(uid)] : [attemptsRef, entRef];
      const [attemptsSnap, entSnap, promoSnap, redemptionSnap] = await tx.getAll(...refs);
      const attemptsToday = int(attemptsSnap!.get('count'));
      const decision = decidePromoRedeem({
        wellFormed,
        promo: promoSnap ? parsePromoCode(promoSnap.data()) : null,
        alreadyRedeemed: redemptionSnap?.exists ?? false,
        attemptsToday,
        nowMs,
      });
      if (decision.kind === 'reject' && !decision.countAttempt) return decision;
      tx.set(
        attemptsRef,
        { uid, day: bishkekDayKey(nowMs), count: attemptsToday + 1, updated_at: FieldValue.serverTimestamp() },
        { merge: true },
      );
      if (decision.kind === 'reject') return decision;

      const applied = applyBonusCredits(parseEntitlement(entSnap!.data()), decision.credits, 'promo');
      tx.set(promoRef!.collection('redemptions').doc(uid), { at: FieldValue.serverTimestamp() });
      tx.update(promoRef!, { redemptions: FieldValue.increment(1), last_redeemed_at: FieldValue.serverTimestamp() });
      tx.set(entRef, { credits: applied.entitlement.credits, updated_at: FieldValue.serverTimestamp() }, { merge: true });
      tx.set(entRef.collection('ledger').doc(), { ...applied.ledger, ref: `promo_${code}`, actor_uid: uid, at: FieldValue.serverTimestamp() });
      return { kind: 'redeemed' as const, credits: decision.credits, balance: applied.entitlement.credits };
    });

    if (outcome.kind === 'reject') {
      if (outcome.reason !== 'CODE_INVALID') logger.info('promo rejected', { uid, reason: outcome.reason });
      throw promoRejection(outcome.reason);
    }
    logger.info('promo redeemed', { uid, code, credits: outcome.credits });
    return { credits: outcome.credits, balance: outcome.balance };
  }),
);

// ---------------------------------------------------------------------------
// adminUpsertPromoCode {code, credits, maxRedemptions?, expiresAt?, active, note} -> {ok, code}

export const adminUpsertPromoCode = onCall(
  adminCallableOptions(),
  wrap('adminUpsertPromoCode', async (req) => {
    const actor = await requirePermission(req, 'grant_credits');
    const p = parsePromoUpsert(payload(req));
    const ref = db().doc(`promo_codes/${p.code}`);
    const created = await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const fields = {
        credits: p.credits,
        max_redemptions: p.maxRedemptions,
        expires_at: msToTs(p.expiresAtMs),
        active: p.active,
        note: p.note,
        updated_at: FieldValue.serverTimestamp(),
        updated_by: actor.uid,
      };
      if (snap.exists) {
        tx.update(ref, fields);
        return false;
      }
      tx.set(ref, { ...fields, redemptions: 0, created_by: actor.uid, created_at: FieldValue.serverTimestamp() });
      return true;
    });
    await writeAdminLog(actor, created ? 'create_promo_code' : 'update_promo_code', { promo_code: p.code }, {
      credits: p.credits,
      max_redemptions: p.maxRedemptions,
      expires_at_ms: p.expiresAtMs,
      active: p.active,
    });
    return { ok: true, code: p.code, created };
  }),
);
