/**
 * Google Play one-time purchase verification decisions (ARCHITECTURE §1.6,
 * §5). Pure: takes a ProductPurchaseV2-like object (as returned by
 * purchases.productsv2.getproductpurchasev2) and decides what to do.
 *
 * Replay safety does not live here: the handler creates
 * `purchases/{purchaseTokenId(token)}` inside the same transaction that adds
 * the credits, so a token can be granted at most once.
 */
import { sha256Hex } from './hash';
import { isRecord, num, str, strOrNull } from './types';

/** Document id for a purchase token (never store the raw token as an id). */
export function purchaseTokenId(purchaseToken: string): string {
  return sha256Hex(purchaseToken);
}

/**
 * What the client must pass as `applicationUserName` (Play stores it as
 * obfuscatedExternalAccountId): hex SHA-256 of the Firebase uid.
 */
export function obfuscatedAccountIdFor(uid: string): string {
  return sha256Hex(uid);
}

/** Uid replacement used when an account is deleted (purchases are kept). */
export function anonymizedUid(uid: string): string {
  return `deleted:${sha256Hex(uid)}`;
}

/** Minimal subset of androidpublisher_v3.Schema$ProductPurchaseV2. */
export interface ProductPurchaseV2Like {
  orderId?: string | null;
  obfuscatedExternalAccountId?: string | null;
  purchaseCompletionTime?: string | null;
  acknowledgementState?: string | null;
  purchaseStateContext?: { purchaseState?: string | null } | null;
  testPurchaseContext?: Record<string, unknown> | null;
  productLineItem?: Array<{
    productId?: string | null;
    productOfferDetails?: {
      quantity?: number | null;
      consumptionState?: string | null;
      refundableQuantity?: number | null;
    } | null;
  }> | null;
}

/** Minimal subset of androidpublisher_v3.Schema$ProductPurchase (v1 API). */
export interface ProductPurchaseV1Like {
  purchaseState?: number | null; // 0 purchased, 1 canceled, 2 pending
  consumptionState?: number | null; // 0 yet to be consumed, 1 consumed
  purchaseType?: number | null; // 0 test, 1 promo, 2 rewarded
  acknowledgementState?: number | null;
  orderId?: string | null;
  obfuscatedExternalAccountId?: string | null;
  purchaseTimeMillis?: string | null;
  quantity?: number | null;
  productId?: string | null;
}

/** Adapts the legacy purchases.products.get response to the V2 shape. */
export function adaptV1ToV2(v1: ProductPurchaseV1Like, productId: string): ProductPurchaseV2Like {
  const state = v1.purchaseState === 0 ? 'PURCHASED' : v1.purchaseState === 2 ? 'PENDING' : v1.purchaseState === 1 ? 'CANCELLED' : null;
  const ms = v1.purchaseTimeMillis ? Number(v1.purchaseTimeMillis) : NaN;
  return {
    orderId: v1.orderId ?? null,
    obfuscatedExternalAccountId: v1.obfuscatedExternalAccountId ?? null,
    purchaseCompletionTime: Number.isFinite(ms) ? new Date(ms).toISOString() : null,
    acknowledgementState: v1.acknowledgementState === 1 ? 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' : 'ACKNOWLEDGEMENT_STATE_PENDING',
    purchaseStateContext: { purchaseState: state },
    testPurchaseContext: v1.purchaseType === 0 ? { fopType: 'TEST' } : null,
    productLineItem: [
      {
        productId: v1.productId ?? productId,
        productOfferDetails: {
          quantity: v1.quantity ?? 1,
          consumptionState: v1.consumptionState === 1 ? 'CONSUMPTION_STATE_CONSUMED' : 'CONSUMPTION_STATE_YET_TO_BE_CONSUMED',
        },
      },
    ],
  };
}

export type PurchaseState = 'pending' | 'granted' | 'refunded' | 'revoked' | 'invalid';

export interface ExistingPurchaseRecord {
  uid: string;
  state: PurchaseState | string;
  credits_granted: number;
}

export type PurchaseDecision =
  | {
      kind: 'grant';
      credits: number;
      quantity: number;
      orderId: string | null;
      isTest: boolean;
      consumed: boolean;
      accountBinding: 'matched' | 'missing';
      purchaseTimeMs: number | null;
    }
  | { kind: 'already_processed'; state: string; credits: number }
  | { kind: 'pending' }
  | { kind: 'invalid'; reason: InvalidReason }
  | { kind: 'mismatch'; reason: 'other_account' | 'already_claimed_by_other_user' };

export type InvalidReason =
  | 'unknown_product'
  | 'product_mismatch'
  | 'not_purchased'
  | 'test_purchase_not_allowed'
  | 'state_unknown';

export interface PurchaseDecisionInput {
  purchase: ProductPurchaseV2Like;
  /** productId the client claims it bought. */
  productId: string;
  uid: string;
  allowTestPurchases: boolean;
  /** config/pricing.products: productId -> credits. */
  creditsPerProduct: Record<string, number>;
  existing: ExistingPurchaseRecord | null;
}

const FINAL_STATES = new Set(['granted', 'refunded', 'revoked']);

/** Decides whether to existing-check, grant, wait (pending) or reject. */
export function decidePurchase(input: PurchaseDecisionInput): PurchaseDecision {
  const { purchase, productId, uid, existing } = input;

  if (existing) {
    // Tombstone: voided/cancelled before anyone claimed it.
    if (existing.uid === '' && (existing.state === 'refunded' || existing.state === 'revoked')) {
      return { kind: 'invalid', reason: 'not_purchased' };
    }
    if (existing.uid !== uid) return { kind: 'mismatch', reason: 'already_claimed_by_other_user' };
    if (FINAL_STATES.has(existing.state)) {
      return { kind: 'already_processed', state: existing.state, credits: existing.credits_granted };
    }
    // pending/invalid records are re-evaluated against the fresh Play state.
  }

  const perUnit = input.creditsPerProduct[productId];
  if (!perUnit || perUnit <= 0) return { kind: 'invalid', reason: 'unknown_product' };

  const items = purchase.productLineItem ?? [];
  const line = items.find((li) => li?.productId === productId);
  if (!line) return { kind: 'invalid', reason: 'product_mismatch' };

  const expected = obfuscatedAccountIdFor(uid);
  const actual = purchase.obfuscatedExternalAccountId ?? null;
  if (actual !== null && actual !== '' && actual !== expected) return { kind: 'mismatch', reason: 'other_account' };

  const state = purchase.purchaseStateContext?.purchaseState ?? null;
  if (state === 'PENDING') return { kind: 'pending' };
  if (state === 'CANCELLED') return { kind: 'invalid', reason: 'not_purchased' };
  if (state !== 'PURCHASED') return { kind: 'invalid', reason: 'state_unknown' };

  const isTest = purchase.testPurchaseContext != null;
  if (isTest && !input.allowTestPurchases) return { kind: 'invalid', reason: 'test_purchase_not_allowed' };

  const quantity = Math.max(1, Math.min(100, Math.trunc(num(line.productOfferDetails?.quantity, 1)) || 1));
  const completion = purchase.purchaseCompletionTime ? Date.parse(purchase.purchaseCompletionTime) : NaN;
  return {
    kind: 'grant',
    credits: perUnit * quantity,
    quantity,
    orderId: purchase.orderId ?? null,
    isTest,
    consumed: line.productOfferDetails?.consumptionState === 'CONSUMPTION_STATE_CONSUMED',
    accountBinding: actual ? 'matched' : 'missing',
    purchaseTimeMs: Number.isFinite(completion) ? completion : null,
  };
}

/**
 * Credits to revoke for a voided purchase. Quantity-based partial refunds
 * revoke proportionally (rounded up); otherwise everything granted.
 */
export function creditsToClawBack(creditsGranted: number, quantity: number | null, voidedQuantity: number | null): number {
  const granted = Math.max(0, Math.trunc(creditsGranted));
  if (!quantity || quantity <= 1 || !voidedQuantity || voidedQuantity >= quantity) return granted;
  return Math.min(granted, Math.ceil((granted * voidedQuantity) / quantity));
}

/** Default product -> credits map (ARCHITECTURE §1.6) when config/pricing is absent. */
export const DEFAULT_PRODUCTS: Readonly<Record<string, number>> = Object.freeze({
  exam_single: 1,
  exam_pack_5: 5,
  exam_pack_10: 10,
});

const PRODUCT_ID_RE = /^[a-z0-9][a-z0-9_.]{0,63}$/;

export function isValidProductId(id: unknown): id is string {
  return typeof id === 'string' && PRODUCT_ID_RE.test(id);
}

/**
 * Parses config/pricing.products. Accepts `{id: credits}` and the tolerant
 * `{id: {credits}}` form; drops invalid entries.
 */
export function parseProducts(raw: unknown): Record<string, number> {
  if (!isRecord(raw)) return { ...DEFAULT_PRODUCTS };
  const out: Record<string, number> = {};
  for (const [id, v] of Object.entries(raw)) {
    const credits = isRecord(v) ? num(v['credits']) : num(v);
    if (isValidProductId(id) && Number.isInteger(credits) && credits >= 1 && credits <= 1000) out[id] = credits;
  }
  return Object.keys(out).length > 0 ? out : { ...DEFAULT_PRODUCTS };
}

// ---------------------------------------------------------------------------
// Real-time developer notifications (Pub/Sub topic `play-billing`)

export type RtdnEvent =
  | { kind: 'voided'; packageName: string; purchaseToken: string; orderId: string | null; refundType: number | null }
  | { kind: 'one_time'; packageName: string; purchaseToken: string; sku: string; type: 'purchased' | 'canceled' | 'other' }
  | { kind: 'test'; packageName: string }
  | { kind: 'ignored'; packageName: string; why: string };

/** Parses the JSON payload of an RTDN Pub/Sub message. */
export function parseRtdn(payload: unknown): RtdnEvent {
  if (!isRecord(payload)) return { kind: 'ignored', packageName: '', why: 'not an object' };
  const packageName = str(payload['packageName']);
  const voided = payload['voidedPurchaseNotification'];
  if (isRecord(voided)) {
    const token = strOrNull(voided['purchaseToken']);
    if (!token) return { kind: 'ignored', packageName, why: 'voided without token' };
    // productType 1 = subscription; we only sell one-time products.
    if (num(voided['productType'], 2) === 1) return { kind: 'ignored', packageName, why: 'subscription voided' };
    return {
      kind: 'voided',
      packageName,
      purchaseToken: token,
      orderId: strOrNull(voided['orderId']),
      refundType: voided['refundType'] === undefined ? null : num(voided['refundType']),
    };
  }
  const oneTime = payload['oneTimeProductNotification'];
  if (isRecord(oneTime)) {
    const token = strOrNull(oneTime['purchaseToken']);
    if (!token) return { kind: 'ignored', packageName, why: 'one-time without token' };
    const t = num(oneTime['notificationType']);
    return {
      kind: 'one_time',
      packageName,
      purchaseToken: token,
      sku: str(oneTime['sku']),
      type: t === 1 ? 'purchased' : t === 2 ? 'canceled' : 'other',
    };
  }
  if (isRecord(payload['testNotification'])) return { kind: 'test', packageName };
  return { kind: 'ignored', packageName, why: 'unsupported notification' };
}
