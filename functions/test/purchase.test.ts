import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { describe, it } from 'node:test';
import {
  adaptV1ToV2,
  anonymizedUid,
  creditsToClawBack,
  decidePurchase,
  DEFAULT_PRODUCTS,
  obfuscatedAccountIdFor,
  parseProducts,
  parseRtdn,
  purchaseTokenId,
  type ProductPurchaseV2Like,
} from '../src/domain/purchase';

const UID = 'user_123';
const sha = (s: string) => createHash('sha256').update(s).digest('hex');

function purchase(over: Partial<ProductPurchaseV2Like> = {}, productId = 'exam_single', quantity = 1): ProductPurchaseV2Like {
  return {
    orderId: 'GPA.1234-5678',
    obfuscatedExternalAccountId: sha(UID),
    purchaseCompletionTime: '2026-11-02T10:00:00Z',
    purchaseStateContext: { purchaseState: 'PURCHASED' },
    testPurchaseContext: null,
    productLineItem: [{ productId, productOfferDetails: { quantity, consumptionState: 'CONSUMPTION_STATE_YET_TO_BE_CONSUMED' } }],
    ...over,
  };
}

const base = { productId: 'exam_single', uid: UID, allowTestPurchases: false, creditsPerProduct: { ...DEFAULT_PRODUCTS }, existing: null };

describe('hashing helpers', () => {
  it('token id and obfuscated account id are hex sha256', () => {
    assert.equal(purchaseTokenId('tok'), sha('tok'));
    assert.equal(obfuscatedAccountIdFor(UID), sha(UID));
    assert.match(purchaseTokenId('tok'), /^[0-9a-f]{64}$/);
    assert.equal(anonymizedUid(UID), `deleted:${sha(UID)}`);
  });
});

describe('decidePurchase', () => {
  it('grants a purchased product with credits from the config map', () => {
    const d = decidePurchase({ ...base, purchase: purchase() });
    assert.equal(d.kind, 'grant');
    if (d.kind !== 'grant') return;
    assert.equal(d.credits, 1);
    assert.equal(d.orderId, 'GPA.1234-5678');
    assert.equal(d.accountBinding, 'matched');
    assert.equal(d.consumed, false);
    assert.equal(d.purchaseTimeMs, Date.parse('2026-11-02T10:00:00Z'));
  });

  it('multiplies credits by quantity for packs', () => {
    const d = decidePurchase({ ...base, productId: 'exam_pack_5', purchase: purchase({}, 'exam_pack_5', 2) });
    assert.equal(d.kind === 'grant' && d.credits, 10);
  });

  it('pending purchases are not granted', () => {
    const d = decidePurchase({ ...base, purchase: purchase({ purchaseStateContext: { purchaseState: 'PENDING' } }) });
    assert.deepEqual(d, { kind: 'pending' });
  });

  it('cancelled purchases are invalid', () => {
    const d = decidePurchase({ ...base, purchase: purchase({ purchaseStateContext: { purchaseState: 'CANCELLED' } }) });
    assert.deepEqual(d, { kind: 'invalid', reason: 'not_purchased' });
  });

  it('test purchases are granted only when allowed', () => {
    const p = purchase({ testPurchaseContext: { fopType: 'TEST' } });
    assert.deepEqual(decidePurchase({ ...base, purchase: p }), { kind: 'invalid', reason: 'test_purchase_not_allowed' });
    const d = decidePurchase({ ...base, purchase: p, allowTestPurchases: true });
    assert.equal(d.kind === 'grant' && d.isTest, true);
  });

  it('rejects a purchase bound to another account', () => {
    const d = decidePurchase({ ...base, purchase: purchase({ obfuscatedExternalAccountId: sha('someone_else') }) });
    assert.deepEqual(d, { kind: 'mismatch', reason: 'other_account' });
  });

  it('accepts a purchase without account binding but flags it', () => {
    const d = decidePurchase({ ...base, purchase: purchase({ obfuscatedExternalAccountId: null }) });
    assert.equal(d.kind === 'grant' && d.accountBinding, 'missing');
  });

  it('is replay-safe: an existing granted record of the same user is already processed', () => {
    const d = decidePurchase({ ...base, purchase: purchase(), existing: { uid: UID, state: 'granted', credits_granted: 1 } });
    assert.deepEqual(d, { kind: 'already_processed', state: 'granted', credits: 1 });
  });

  it('a token already claimed by another user is a mismatch', () => {
    const d = decidePurchase({ ...base, purchase: purchase(), existing: { uid: 'other', state: 'granted', credits_granted: 1 } });
    assert.deepEqual(d, { kind: 'mismatch', reason: 'already_claimed_by_other_user' });
  });

  it('re-evaluates a pending record once Play reports PURCHASED', () => {
    const d = decidePurchase({ ...base, purchase: purchase(), existing: { uid: UID, state: 'pending', credits_granted: 0 } });
    assert.equal(d.kind, 'grant');
  });

  it('a token voided before anyone claimed it is invalid', () => {
    const d = decidePurchase({ ...base, purchase: purchase(), existing: { uid: '', state: 'refunded', credits_granted: 0 } });
    assert.deepEqual(d, { kind: 'invalid', reason: 'not_purchased' });
  });

  it('unknown products and product mismatches are invalid', () => {
    assert.deepEqual(decidePurchase({ ...base, productId: 'gems_100', purchase: purchase() }), { kind: 'invalid', reason: 'unknown_product' });
    assert.deepEqual(decidePurchase({ ...base, productId: 'exam_pack_10', purchase: purchase() }), { kind: 'invalid', reason: 'product_mismatch' });
  });

  it('reports already consumed purchases so consume is skipped', () => {
    const p = purchase({ productLineItem: [{ productId: 'exam_single', productOfferDetails: { quantity: 1, consumptionState: 'CONSUMPTION_STATE_CONSUMED' } }] });
    const d = decidePurchase({ ...base, purchase: p });
    assert.equal(d.kind === 'grant' && d.consumed, true);
  });
});

describe('adaptV1ToV2', () => {
  it('maps the legacy products.get response', () => {
    const v2 = adaptV1ToV2({ purchaseState: 0, consumptionState: 0, purchaseType: 0, orderId: 'o', obfuscatedExternalAccountId: 'x', quantity: 2, purchaseTimeMillis: '1000' }, 'exam_single');
    assert.equal(v2.purchaseStateContext?.purchaseState, 'PURCHASED');
    assert.ok(v2.testPurchaseContext);
    assert.equal(v2.productLineItem?.[0]?.productOfferDetails?.quantity, 2);
    assert.equal(adaptV1ToV2({ purchaseState: 2 }, 'p').purchaseStateContext?.purchaseState, 'PENDING');
  });
});

describe('pricing and refunds helpers', () => {
  it('parseProducts accepts both map shapes and falls back to defaults', () => {
    assert.deepEqual(parseProducts({ exam_single: 1, exam_pack_5: { credits: 5 }, 'BAD ID': 3 }), { exam_single: 1, exam_pack_5: 5 });
    assert.deepEqual(parseProducts(null), { ...DEFAULT_PRODUCTS });
  });

  it('creditsToClawBack handles partial quantity refunds', () => {
    assert.equal(creditsToClawBack(10, 2, 1), 5);
    assert.equal(creditsToClawBack(5, 1, null), 5);
    assert.equal(creditsToClawBack(10, 2, 2), 10);
  });
});

describe('parseRtdn', () => {
  it('parses voided, one-time and test notifications', () => {
    assert.deepEqual(parseRtdn({ packageName: 'p', voidedPurchaseNotification: { purchaseToken: 't', orderId: 'o', productType: 2, refundType: 1 } }), {
      kind: 'voided',
      packageName: 'p',
      purchaseToken: 't',
      orderId: 'o',
      refundType: 1,
    });
    assert.equal((parseRtdn({ packageName: 'p', oneTimeProductNotification: { purchaseToken: 't', sku: 's', notificationType: 2 } }) as { type: string }).type, 'canceled');
    assert.equal(parseRtdn({ packageName: 'p', testNotification: { version: '1.0' } }).kind, 'test');
    assert.equal(parseRtdn({ packageName: 'p', voidedPurchaseNotification: { purchaseToken: 't', productType: 1 } }).kind, 'ignored');
    assert.equal(parseRtdn('junk').kind, 'ignored');
  });
});
