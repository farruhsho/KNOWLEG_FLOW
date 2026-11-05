/**
 * Google Play Billing (ARCHITECTURE §1.6, §5): billingVerifyPurchase,
 * billingRtdn (Pub/Sub `play-billing`) and billingSweepVoided (daily).
 *
 * Replay safety: purchases/{sha256(token)} is created in the same
 * transaction that adds the credits, so one token grants at most once. The
 * raw token is kept only in purchases/{id}/private/token (no client access)
 * so a failed consume can be retried later.
 *
 * Referral reward (ARCHITECTURE §9.1): the grant transaction also reads
 * users/{uid}.referred_by and, on the referred user's first non-test paid
 * grant, adds +1 credit to both accounts (ledger reason 'referral',
 * handlers/referral.ts) in the same transaction, so it is exactly-once. The
 * purchase records `referral_referrer_uid` / `referral_referrer_rewarded`;
 * a refund or void of that purchase claws both bonuses back in the revoke
 * transaction (ARCHITECTURE §9.7, ledger reason 'refund', item 'revoked').
 */
import '../config';
import type { DocumentData } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';
import { onMessagePublished } from 'firebase-functions/v2/pubsub';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { ALLOW_TEST_PURCHASES, PLAY_PACKAGE_NAME } from '../config';
import { parseEntitlement } from '../domain/entitlements';
import {
  creditsToClawBack,
  decidePurchase,
  isValidProductId,
  parseProducts,
  parseRtdn,
  purchaseTokenId,
  type ExistingPurchaseRecord,
} from '../domain/purchase';
import { DomainError, Reasons } from '../domain/reasons';
import { int, str } from '../domain/types';
import { callableOptions, db, FieldValue, mapLimit, optString, payload, requireActiveUser, Timestamp, wrap } from './common';
import { liveOwner, readPaidClawback, readPaidGrant, writePaidClawback, writePaidGrant } from './credit_grants';
import { consumePurchase, fetchPurchase, listVoided } from './play';

export type VerifyStatus = 'granted' | 'already_processed' | 'pending' | 'invalid';

function purchaseRef(tokenId: string) {
  return db().doc(`purchases/${tokenId}`);
}

function tokenRef(tokenId: string) {
  return db().doc(`purchases/${tokenId}/private/token`);
}

async function readProducts(): Promise<Record<string, number>> {
  const snap = await db().doc('config/pricing').get();
  return parseProducts(snap.get('products'));
}

async function currentCredits(uid: string): Promise<number> {
  const snap = await db().doc(`entitlements/${uid}`).get();
  return parseEntitlement(snap.data()).credits;
}

function existingRecord(data: DocumentData | undefined): ExistingPurchaseRecord | null {
  if (!data) return null;
  return { uid: str(data['uid']), state: str(data['state'], 'pending'), credits_granted: int(data['credits_granted']) };
}

async function consumeAndMark(tokenId: string, productId: string, token: string): Promise<void> {
  const ok = await consumePurchase(PLAY_PACKAGE_NAME.value(), productId, token);
  if (ok) {
    await purchaseRef(tokenId).set(
      { consumed: true, acknowledged: true, consumed_at: FieldValue.serverTimestamp(), updated_at: FieldValue.serverTimestamp() },
      { merge: true },
    );
  }
}

export interface ProcessInput {
  uid: string;
  productId: string;
  purchaseToken: string;
  orderId: string | null;
  priceDisplay: string | null;
  source: 'client' | 'rtdn';
}

export interface ProcessOutput {
  status: VerifyStatus;
  credits: number;
}

/** Verify with Play, then grant exactly once. Shared by the callable and RTDN. */
export async function processPurchase(input: ProcessInput): Promise<ProcessOutput> {
  const { uid, productId, purchaseToken } = input;
  const tokenId = purchaseTokenId(purchaseToken);
  const products = await readProducts();
  if (!products[productId]) throw new DomainError(Reasons.PURCHASE_INVALID, 'unknown product', { productId });

  const prior = await purchaseRef(tokenId).get();
  const priorRecord = existingRecord(prior.data());
  if (priorRecord && priorRecord.uid === uid && priorRecord.state === 'granted') {
    if (prior.get('consumed') !== true) await consumeAndMark(tokenId, productId, purchaseToken);
    return { status: 'already_processed', credits: await currentCredits(uid) };
  }
  if (priorRecord && priorRecord.uid !== '' && priorRecord.uid !== uid) {
    logger.warn('purchase token claimed by another account', { uid, tokenId });
    throw new DomainError(Reasons.PURCHASE_ACCOUNT_MISMATCH, 'purchase belongs to another account');
  }

  const fetched = await fetchPurchase(PLAY_PACKAGE_NAME.value(), productId, purchaseToken);
  if (!fetched.found) {
    logger.warn('purchase token unknown to Play', { uid, productId, tokenId });
    return { status: 'invalid', credits: await currentCredits(uid) };
  }

  const pre = decidePurchase({
    purchase: fetched.purchase,
    productId,
    uid,
    allowTestPurchases: ALLOW_TEST_PURCHASES.value(),
    creditsPerProduct: products,
    existing: priorRecord,
  });

  if (pre.kind === 'mismatch') {
    logger.warn('purchase account mismatch', { uid, tokenId, reason: pre.reason });
    throw new DomainError(Reasons.PURCHASE_ACCOUNT_MISMATCH, 'purchase belongs to another account');
  }
  if (pre.kind === 'already_processed') return { status: 'already_processed', credits: await currentCredits(uid) };
  if (pre.kind === 'pending' || pre.kind === 'invalid') {
    const state = pre.kind === 'pending' ? 'pending' : 'invalid';
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(purchaseRef(tokenId));
      const rec = existingRecord(snap.data());
      if (rec && (rec.state === 'granted' || rec.state === 'refunded' || rec.state === 'revoked')) return;
      tx.set(
        purchaseRef(tokenId),
        {
          uid,
          platform: 'google_play',
          product_id: productId,
          order_id: fetched.purchase.orderId ?? input.orderId,
          purchase_token_hash: tokenId,
          state,
          invalid_reason: pre.kind === 'invalid' ? pre.reason : null,
          credits_granted: 0,
          acknowledged: false,
          consumed: false,
          price_display: input.priceDisplay,
          refund: null,
          updated_at: FieldValue.serverTimestamp(),
          ...(snap.exists ? {} : { created_at: FieldValue.serverTimestamp() }),
        },
        { merge: true },
      );
      // Keep the token so RTDN "purchased" can finish a pending purchase.
      if (pre.kind === 'pending') tx.set(tokenRef(tokenId), { purchase_token: purchaseToken, product_id: productId });
    });
    logger.info('purchase not granted', { uid, productId, state, reason: pre.kind === 'invalid' ? pre.reason : 'pending' });
    return { status: pre.kind, credits: await currentCredits(uid) };
  }

  // pre.kind === 'grant'
  const entRef = db().doc(`entitlements/${uid}`);
  const granted = await db().runTransaction(async (tx) => {
    const snap = await tx.get(purchaseRef(tokenId));
    const decision = decidePurchase({
      purchase: fetched.purchase,
      productId,
      uid,
      allowTestPurchases: ALLOW_TEST_PURCHASES.value(),
      creditsPerProduct: products,
      existing: existingRecord(snap.data()),
    });
    if (decision.kind !== 'grant') {
      const entSnap = await tx.get(entRef);
      return { status: 'already_processed' as const, credits: parseEntitlement(entSnap.data()).credits, consumed: true };
    }
    // All reads (entitlement, referral item, referrer counter/profile/entitlement) before the first write.
    const reads = await readPaidGrant(tx, uid, { isTest: decision.isTest, nowMs: Date.now() });
    // Shared with web payments (credit_grants.ts): purchase ledger line + referral reward.
    const grant = writePaidGrant(tx, reads, decision.credits, { ref: tokenId, actorUid: uid, extra: { product_id: productId } });
    const applied = grant.applied;
    const referral = reads.referral;
    tx.set(purchaseRef(tokenId), {
      uid,
      platform: 'google_play',
      product_id: productId,
      order_id: decision.orderId ?? input.orderId,
      purchase_token_hash: tokenId,
      purchase_time: decision.purchaseTimeMs ? Timestamp.fromMillis(decision.purchaseTimeMs) : null,
      state: 'granted',
      credits_granted: decision.credits,
      credits_net: applied.netCredits,
      debt_settled: applied.debtSettled,
      quantity: decision.quantity,
      is_test: decision.isTest,
      account_binding: decision.accountBinding,
      acknowledged: decision.consumed,
      consumed: decision.consumed,
      price_display: input.priceDisplay,
      verified_via: fetched.api,
      source: input.source,
      refund: null,
      invalid_reason: null,
      // §9.7: which referral reward this purchase paid out, so a refund can claw it back.
      ...grant.recordFields,
      created_at: snap.exists ? (snap.get('created_at') ?? FieldValue.serverTimestamp()) : FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    });
    tx.set(tokenRef(tokenId), { purchase_token: purchaseToken, product_id: productId });
    if (referral.decision.kind === 'reward') {
      logger.info('referral rewarded', { uid, referrer: referral.decision.referrerUid, referrerRewarded: referral.decision.rewardReferrer });
    }
    return { status: 'granted' as const, credits: grant.entitlement.credits, consumed: decision.consumed };
  });

  if (granted.status === 'granted' && !granted.consumed) await consumeAndMark(tokenId, productId, purchaseToken);
  logger.info('purchase processed', { uid, productId, status: granted.status, source: input.source });
  return { status: granted.status, credits: granted.credits };
}

// ---------------------------------------------------------------------------
// billingVerifyPurchase {productId, purchaseToken, orderId?, priceDisplay?}

export const billingVerifyPurchase = onCall(
  callableOptions({ timeoutSeconds: 60 }),
  wrap('billingVerifyPurchase', async (req) => {
    // The Auth user must still exist (an ID token outlives accountDelete by up to 1 h).
    // Banned users may still record purchases they paid for.
    const { uid } = await requireActiveUser(req, { allowBanned: true });
    const data = payload(req);
    const productId = data['productId'];
    if (!isValidProductId(productId)) throw new DomainError(Reasons.PURCHASE_INVALID, 'productId is invalid');
    const token = data['purchaseToken'];
    if (typeof token !== 'string' || token.length < 10 || token.length > 4096) {
      throw new DomainError(Reasons.PURCHASE_INVALID, 'purchaseToken is invalid');
    }
    return processPurchase({
      uid,
      productId,
      purchaseToken: token,
      orderId: optString(data['orderId'], 'orderId', 128),
      priceDisplay: optString(data['priceDisplay'], 'priceDisplay', 40),
      source: 'client',
    });
  }),
);

// ---------------------------------------------------------------------------
// Revocation (refund / void / cancel)

export type RevokeSource = 'rtdn' | 'voided_api' | 'admin';

/**
 * Revokes the credits of a purchase and the referral bonuses it paid out
 * (§9.7: referee and, if rewarded, referrer; item -> 'revoked'). Credits
 * never go below zero; spent credits are recorded as entitlement debt.
 * Idempotent: an already refunded/revoked purchase is left alone. Unknown
 * tokens get a tombstone so they can never be granted later.
 */
export async function revokePurchase(
  tokenId: string,
  source: RevokeSource,
  opts: { cancelled?: boolean; orderId?: string | null; voidedQuantity?: number | null } = {},
): Promise<'revoked' | 'noop' | 'tombstone'> {
  return db().runTransaction(async (tx) => {
    const snap = await tx.get(purchaseRef(tokenId));
    const newState = opts.cancelled ? 'revoked' : 'refunded';
    if (!snap.exists) {
      tx.set(purchaseRef(tokenId), {
        uid: '',
        platform: 'google_play',
        purchase_token_hash: tokenId,
        order_id: opts.orderId ?? null,
        state: newState,
        credits_granted: 0,
        refund: { at: FieldValue.serverTimestamp(), source, credits_clawed_back: 0, before_grant: true },
        created_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      });
      return 'tombstone' as const;
    }
    const rec = existingRecord(snap.data())!;
    if (rec.state === 'refunded' || rec.state === 'revoked') return 'noop' as const;
    const actorUid = source === 'admin' ? 'admin' : 'system';
    const granted = rec.state === 'granted';
    // All reads before the first write: the referral reward this purchase paid (§9.7), then the entitlement.
    // Shared with web payments (credit_grants.ts).
    const reads = await readPaidClawback(tx, snap, liveOwner(rec.uid, granted), granted);
    const want = creditsToClawBack(rec.credits_granted, int(snap.get('quantity'), 1), opts.voidedQuantity ?? null);
    // Without a live owner (never granted, or the account was deleted) only a
    // referrer rewarded for this purchase still loses the bonus.
    const out = writePaidClawback(tx, reads, want, { ref: tokenId, actorUid, source });
    tx.set(
      purchaseRef(tokenId),
      {
        state: newState,
        refund: {
          at: FieldValue.serverTimestamp(),
          source,
          credits_clawed_back: out.clawedBack,
          ...(reads.ownerUid ? { debt_added: out.newDebt } : {}),
          ...(out.referralClawedBack ? { referral_clawed_back: out.referralClawedBack } : {}),
        },
        updated_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    if (!reads.ownerUid) return 'noop' as const;
    logger.info('purchase revoked', {
      tokenId,
      uid: rec.uid,
      source,
      clawedBack: out.clawedBack,
      debt: out.newDebt,
      ...(out.referralClawedBack ? { referralReferee: out.referralClawedBack.referee, referralReferrer: out.referralClawedBack.referrer } : {}),
    });
    return 'revoked' as const;
  });
}

// ---------------------------------------------------------------------------
// billingRtdn: Real-time developer notifications on Pub/Sub topic `play-billing`

export const billingRtdn = onMessagePublished({ topic: 'play-billing', retry: false, timeoutSeconds: 120 }, async (event) => {
  let json: unknown;
  try {
    json = event.data.message.json;
  } catch {
    logger.warn('RTDN: non-JSON message ignored');
    return;
  }
  const ev = parseRtdn(json);
  if (ev.packageName && ev.packageName !== PLAY_PACKAGE_NAME.value()) {
    logger.warn('RTDN for another package ignored', { packageName: ev.packageName });
    return;
  }
  switch (ev.kind) {
    case 'test':
      logger.info('RTDN test notification received');
      return;
    case 'ignored':
      logger.info('RTDN ignored', { why: ev.why });
      return;
    case 'voided': {
      if (ev.refundType === 2) {
        // REFUND_TYPE_QUANTITY_BASED_PARTIAL_REFUND: the notification carries no
        // quantity, so the daily Voided Purchases sweep (which has
        // voidedQuantity) revokes the proportional share instead.
        logger.info('RTDN partial refund deferred to billingSweepVoided', { orderId: ev.orderId });
        return;
      }
      const r = await revokePurchase(purchaseTokenId(ev.purchaseToken), 'rtdn', { orderId: ev.orderId });
      logger.info('RTDN voided handled', { result: r, refundType: ev.refundType });
      return;
    }
    case 'one_time': {
      const tokenId = purchaseTokenId(ev.purchaseToken);
      if (ev.type === 'canceled') {
        const r = await revokePurchase(tokenId, 'rtdn', { cancelled: true });
        logger.info('RTDN canceled handled', { result: r });
        return;
      }
      if (ev.type === 'purchased') {
        // Completes a purchase the client reported while it was PENDING.
        const snap = await db().doc(`purchases/${tokenId}`).get();
        const uid = snap.get('uid');
        if (snap.exists && snap.get('state') === 'pending' && typeof uid === 'string' && uid) {
          const productId = str(snap.get('product_id'), ev.sku);
          const out = await processPurchase({ uid, productId, purchaseToken: ev.purchaseToken, orderId: null, priceDisplay: null, source: 'rtdn' });
          logger.info('RTDN purchased handled', { status: out.status });
        }
      }
      return;
    }
  }
});

// ---------------------------------------------------------------------------
// billingSweepVoided: daily safety net for missed RTDNs + consume retries

export const billingSweepVoided = onSchedule(
  { schedule: 'every day 04:00', timeZone: 'Asia/Bishkek', timeoutSeconds: 540, retryCount: 1 },
  async () => {
    const packageName = PLAY_PACKAGE_NAME.value();
    const since = Date.now() - 2 * 24 * 60 * 60 * 1000;
    const voided = await listVoided(packageName, since);
    const results = await mapLimit(voided, 5, async (v) => {
      try {
        return await revokePurchase(purchaseTokenId(v.purchaseToken), 'voided_api', {
          orderId: v.orderId,
          voidedQuantity: v.voidedQuantity,
        });
      } catch (e) {
        logger.error('voided sweep item failed', { error: String(e) });
        return 'failed' as const;
      }
    });

    // Granted but never consumed (consume failed earlier): retry, or Google
    // auto-refunds unacknowledged purchases after 3 days.
    const unconsumed = await db().collection('purchases').where('state', '==', 'granted').where('consumed', '==', false).limit(100).get();
    let consumed = 0;
    for (const doc of unconsumed.docs) {
      const t = await tokenRef(doc.id).get();
      const token = t.get('purchase_token');
      const productId = str(doc.get('product_id'));
      if (typeof token !== 'string' || !productId) continue;
      if (await consumePurchase(packageName, productId, token)) {
        await doc.ref.set({ consumed: true, acknowledged: true, consumed_at: FieldValue.serverTimestamp() }, { merge: true });
        consumed++;
      }
    }
    logger.info('billingSweepVoided done', {
      voided: voided.length,
      revoked: results.filter((r) => r === 'revoked').length,
      failed: results.filter((r) => r === 'failed').length,
      consumeRetried: unconsumed.size,
      consumed,
    });
  },
);
