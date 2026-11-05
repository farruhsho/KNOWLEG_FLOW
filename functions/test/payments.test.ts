import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/domain/reasons';
import { noneAdapter } from '../src/payments/none';
import {
  BASE_PRICE_SOM,
  checkReturnUrl,
  decideWebhook,
  DEFAULT_WEB_PRODUCTS,
  isExpirable,
  MAX_ORDERS_PER_DAY,
  nextOrderCount,
  ORDER_TTL_MS,
  parseReturnOrigins,
  parseWebProducts,
  parseWebProductsUpdate,
  paymentEventId,
  requireWebProduct,
  returnUrlFor,
  type OrderState,
} from '../src/payments/orders';
import { adapterForOrder, projectIdOf, resolveAdapter, sandboxAllowed } from '../src/payments/registry';
import { buildSandboxWebhook, parseSandboxWebhook, sandboxAdapter, sandboxSignature, SANDBOX_SIGNATURE_HEADER } from '../src/payments/sandbox';
import { PaymentsDisabled, WebhookRejected } from '../src/payments/types';

function reasonOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    if (e instanceof DomainError) return [e.reason, e.extra?.['why']].filter(Boolean).join(':');
    return String(e);
  }
  return undefined;
}

const EMULATOR_DEMO = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-ort-e2e' };

describe('payment adapter registry: PAYMENTS_DISABLED and the sandbox guard', () => {
  it('none (the default) and an empty value disable payments', () => {
    for (const name of ['none', '', '  NONE ']) {
      const r = resolveAdapter(name, EMULATOR_DEMO);
      assert.equal(r.enabled, false);
      assert.equal(r.adapter, noneAdapter);
      assert.equal(r.why, 'none');
    }
  });

  it('sandbox only inside the emulator AND for a demo-* project', () => {
    assert.equal(resolveAdapter('sandbox', EMULATOR_DEMO).adapter, sandboxAdapter);
    assert.equal(resolveAdapter('sandbox', EMULATOR_DEMO).enabled, true);
    const blocked = [
      {},
      { GCLOUD_PROJECT: 'demo-ort-e2e' },
      { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'knowleg-33f36' },
      { FUNCTIONS_EMULATOR: 'false', GCLOUD_PROJECT: 'demo-ort-e2e' },
      { FUNCTIONS_EMULATOR: '1', GCLOUD_PROJECT: 'demo-x' },
      { FUNCTIONS_EMULATOR: 'true' },
    ];
    for (const env of blocked) {
      const r = resolveAdapter('sandbox', env);
      assert.equal(r.enabled, false, JSON.stringify(env));
      assert.equal(r.adapter.name, 'none');
      assert.equal(r.why, 'sandbox_outside_emulator');
      assert.equal(sandboxAllowed(env), false);
    }
  });

  it('project id from GCLOUD_PROJECT, GCP_PROJECT or FIREBASE_CONFIG', () => {
    assert.equal(projectIdOf({ GCP_PROJECT: 'demo-a' }), 'demo-a');
    assert.equal(projectIdOf({ FIREBASE_CONFIG: JSON.stringify({ projectId: 'demo-b' }) }), 'demo-b');
    assert.equal(projectIdOf({ FIREBASE_CONFIG: 'not json' }), '');
    assert.equal(sandboxAllowed({ FUNCTIONS_EMULATOR: 'true', FIREBASE_CONFIG: JSON.stringify({ projectId: 'demo-c' }) }), true);
  });

  it('an unknown provider (adapter not written yet) disables payments', () => {
    const r = resolveAdapter('elqr', {});
    assert.deepEqual([r.enabled, r.adapter.name, r.why], [false, 'none', 'unknown_provider']);
  });

  it('refunds go to the adapter of the order provider, only when it is active', () => {
    assert.equal(adapterForOrder('sandbox', EMULATOR_DEMO), sandboxAdapter);
    assert.equal(adapterForOrder('sandbox', {}), null);
    assert.equal(adapterForOrder('none', EMULATOR_DEMO), null);
  });

  it('the none adapter takes no payments and accepts no webhooks', async () => {
    await assert.rejects(noneAdapter.createCheckout({ id: 'o', product_id: 'exam_single', credits: 1, amount_som: 100, currency: 'KGS', provider_ref: null }, 'https://x', { functionsBaseUrl: '' }), PaymentsDisabled);
    assert.throws(() => noneAdapter.parseWebhook(Buffer.from('{}'), {}), WebhookRejected);
  });
});

describe('sandbox adapter', () => {
  it('checkout URL points at the emulator checkout page with the order and the return URL', async () => {
    const c = await sandboxAdapter.createCheckout(
      { id: 'ord1', product_id: 'exam_single', credits: 1, amount_som: 100, currency: 'KGS', provider_ref: null },
      'http://localhost:8088/pay/return?order=ord1',
      { functionsBaseUrl: 'http://127.0.0.1:5001/demo-ort-e2e/europe-west1' },
    );
    const url = new URL(c.checkoutUrl);
    assert.equal(url.origin + url.pathname, 'http://127.0.0.1:5001/demo-ort-e2e/europe-west1/paymentSandboxCheckout');
    assert.equal(url.searchParams.get('order'), 'ord1');
    assert.equal(url.searchParams.get('return'), 'http://localhost:8088/pay/return?order=ord1');
    assert.equal(c.providerRef, 'sbx_ord1');
    assert.deepEqual(await sandboxAdapter.refund({ id: 'ord1', product_id: 'exam_single', credits: 1, amount_som: 100, currency: 'KGS', provider_ref: 'sbx_ord1' }), { status: 'refunded' });
  });

  it('verifies the HMAC over the raw body', () => {
    const w = buildSandboxWebhook({ orderId: 'ord1', status: 'paid', amountSom: 100, eventId: 'evt_1' });
    const ev = sandboxAdapter.parseWebhook(Buffer.from(w.body), { [SANDBOX_SIGNATURE_HEADER]: w.signature });
    assert.deepEqual(ev, { eventId: 'evt_1', orderId: 'ord1', providerRef: 'sbx_ord1', status: 'paid', amountSom: 100, currency: 'KGS' });
    assert.equal(w.signature, sandboxSignature(w.body));
    assert.match(w.signature, /^sha256=[0-9a-f]{64}$/);
    // header arrays (node http) are accepted
    assert.equal(parseSandboxWebhook(Buffer.from(w.body), { [SANDBOX_SIGNATURE_HEADER]: [w.signature] }).eventId, 'evt_1');
  });

  it('rejects a bad or missing signature, a tampered body and malformed events', () => {
    const w = buildSandboxWebhook({ orderId: 'ord1', status: 'paid', amountSom: 100, eventId: 'evt_1' });
    assert.throws(() => parseSandboxWebhook(Buffer.from(w.body), {}), WebhookRejected);
    assert.throws(() => parseSandboxWebhook(Buffer.from(w.body), { [SANDBOX_SIGNATURE_HEADER]: 'sha256=00' }), WebhookRejected);
    assert.throws(() => parseSandboxWebhook(Buffer.from(w.body.replace('100', '1')), { [SANDBOX_SIGNATURE_HEADER]: w.signature }), WebhookRejected);
    assert.throws(() => parseSandboxWebhook(Buffer.from(w.body), { [SANDBOX_SIGNATURE_HEADER]: sandboxSignature(w.body, 'other-secret') }), WebhookRejected);
    const sign = (o: unknown) => {
      const body = JSON.stringify(o);
      return () => parseSandboxWebhook(Buffer.from(body), { [SANDBOX_SIGNATURE_HEADER]: sandboxSignature(body) });
    };
    assert.throws(sign({ event_id: 'e', order_id: 'o', status: 'chargeback', amount_som: 1 }), /status/);
    assert.throws(sign({ event_id: 'e/1', order_id: 'o', status: 'paid', amount_som: 1 }), /event_id/);
    assert.throws(sign({ event_id: 'e', order_id: 'o', status: 'paid', amount_som: '100' }), /amount/);
    assert.throws(sign([1, 2]), /object/);
  });
});

describe('web products (config/pricing.web_products)', () => {
  it('defaults: exam_single 1 credit = 100 som enabled; packs disabled', () => {
    const p = parseWebProducts(undefined);
    assert.deepEqual(p, { ...DEFAULT_WEB_PRODUCTS });
    assert.deepEqual(p['exam_single'], { credits: 1, amount_som: BASE_PRICE_SOM, enabled: true });
    assert.equal(p['exam_pack_5']!.enabled, false);
    assert.equal(p['exam_pack_10']!.enabled, false);
  });

  it('drops invalid stored entries', () => {
    assert.deepEqual(
      parseWebProducts({ exam_single: { credits: 1, amount_som: 100, enabled: true }, bad: { credits: 0, amount_som: 1, enabled: true }, 'Bad Id': { credits: 1, amount_som: 1, enabled: true } }),
      { exam_single: { credits: 1, amount_som: 100, enabled: true } },
    );
  });

  it('only enabled known products can be bought (PRODUCT_UNAVAILABLE)', () => {
    const p = parseWebProducts(undefined);
    assert.deepEqual(requireWebProduct(p, 'exam_single'), { id: 'exam_single', product: p['exam_single'] });
    assert.equal(reasonOf(() => requireWebProduct(p, 'exam_pack_5')), 'PRODUCT_UNAVAILABLE');
    assert.equal(reasonOf(() => requireWebProduct(p, 'unknown')), 'PRODUCT_UNAVAILABLE');
    assert.equal(reasonOf(() => requireWebProduct(p, '__proto__')), 'PRODUCT_UNAVAILABLE');
    assert.equal(reasonOf(() => requireWebProduct(p, 42)), 'PRODUCT_UNAVAILABLE');
  });

  it('adminUpdatePricing webProducts: ranges, enabled bool, camelCase amount', () => {
    assert.deepEqual(
      parseWebProductsUpdate({ exam_single: { credits: 1, amountSom: 100, enabled: true }, exam_pack_5: { credits: 5, amount_som: 450, enabled: true } }, undefined),
      { exam_single: { credits: 1, amount_som: 100, enabled: true }, exam_pack_5: { credits: 5, amount_som: 450, enabled: true } },
    );
    const base = { credits: 1, amount_som: 100, enabled: true };
    for (const bad of [
      { credits: 0, amount_som: 450, enabled: true },
      { credits: 51, amount_som: 450, enabled: true },
      { credits: 5, amount_som: 0, enabled: true },
      { credits: 5, amount_som: 100_001, enabled: true },
      { credits: 5, amount_som: 450.5, enabled: true },
      { credits: 5, amount_som: 450, enabled: 'yes' },
    ]) {
      assert.equal(reasonOf(() => parseWebProductsUpdate({ exam_single: base, exam_pack_5: bad }, undefined)), 'VALIDATION_FAILED', JSON.stringify(bad));
    }
    assert.equal(reasonOf(() => parseWebProductsUpdate({}, undefined)), 'VALIDATION_FAILED');
    assert.equal(reasonOf(() => parseWebProductsUpdate({ exam_pack_5: { credits: 5, amount_som: 450, enabled: true } }, undefined)), 'VALIDATION_FAILED:base_product_missing');
  });

  it('the 100 som base price changes only with confirmBasePriceChange', () => {
    assert.equal(reasonOf(() => parseWebProductsUpdate({ exam_single: { credits: 1, amount_som: 120, enabled: true } }, undefined)), 'VALIDATION_FAILED:base_price_change_unconfirmed');
    assert.equal(reasonOf(() => parseWebProductsUpdate({ exam_single: { credits: 2, amount_som: 100, enabled: true } }, false)), 'VALIDATION_FAILED:base_price_change_unconfirmed');
    assert.equal(parseWebProductsUpdate({ exam_single: { credits: 1, amount_som: 120, enabled: true } }, true)['exam_single']!.amount_som, 120);
    // Disabling the base product is not a price change.
    assert.equal(parseWebProductsUpdate({ exam_single: { credits: 1, amount_som: 100, enabled: false } }, undefined)['exam_single']!.enabled, false);
  });
});

describe('return URLs (PAYMENT_RETURN_ORIGINS)', () => {
  const origins = parseReturnOrigins(' http://localhost:8088 , http://127.0.0.1:8088/,https://knowleg-33f36.web.app, not a url');

  it('parses the comma separated origins', () => {
    assert.deepEqual(origins, ['http://localhost:8088', 'http://127.0.0.1:8088', 'https://knowleg-33f36.web.app']);
  });

  it('accepts only http(s) URLs on an allowed origin', () => {
    assert.equal(checkReturnUrl('http://localhost:8088/pay/return', origins), 'http://localhost:8088/pay/return');
    assert.equal(checkReturnUrl('https://knowleg-33f36.web.app/pay/return?x=1', origins), 'https://knowleg-33f36.web.app/pay/return?x=1');
    for (const bad of ['https://evil.example/pay/return', 'http://localhost:9999/pay', 'javascript:alert(1)', 'http://user:pw@localhost:8088/', 'nope', 42, 'https://knowleg-33f36.web.app.evil.example/']) {
      assert.equal(reasonOf(() => checkReturnUrl(bad, origins)), 'VALIDATION_FAILED', String(bad));
    }
    assert.equal(reasonOf(() => checkReturnUrl('http://localhost:8088/pay', [])), 'VALIDATION_FAILED');
  });

  it('appends the order id', () => {
    assert.equal(returnUrlFor('http://localhost:8088/pay/return', 'o1'), 'http://localhost:8088/pay/return?order=o1');
    assert.equal(returnUrlFor('http://localhost:8088/pay/return?order=old&x=1', 'o2'), 'http://localhost:8088/pay/return?order=o2&x=1');
  });
});

describe('order limits and expiry', () => {
  it('10 orders a day, then RATE_LIMITED', () => {
    let n = 0;
    for (let i = 0; i < MAX_ORDERS_PER_DAY; i++) n = nextOrderCount(n);
    assert.equal(n, 10);
    assert.equal(reasonOf(() => nextOrderCount(n)), 'RATE_LIMITED');
  });

  it('created / pending orders expire after 24 h', () => {
    const t = 1_762_000_000_000;
    assert.equal(isExpirable('pending', t, t + ORDER_TTL_MS + 1), true);
    assert.equal(isExpirable('created', t, t + ORDER_TTL_MS + 1), true);
    assert.equal(isExpirable('pending', t, t + ORDER_TTL_MS - 1), false);
    for (const s of ['paid', 'failed', 'refunded', 'expired']) assert.equal(isExpirable(s, t, t + 2 * ORDER_TTL_MS), false);
    assert.equal(isExpirable('pending', null, t), false);
  });

  it('payment_events ids: provider prefix, hashed when not id-safe', () => {
    assert.equal(paymentEventId('sandbox', 'evt_1', () => 'h'), 'sandbox_evt_1');
    assert.equal(paymentEventId('elqr', 'a/b c', (s) => `hash(${s})`.replace(/[^a-z]/g, 'x')), 'elqr_hashxaxbxcx');
  });
});

describe('decideWebhook', () => {
  const order = (o: Partial<OrderState> = {}): OrderState => ({ status: 'pending', granted: false, amount_som: 100, currency: 'KGS', credits: 1, ...o });
  const ev = (status: 'paid' | 'failed' | 'refunded', amountSom = 100, currency = 'KGS') => ({ status, amountSom, currency });

  it('paid with the exact amount and currency grants once', () => {
    assert.deepEqual(decideWebhook(order(), ev('paid')), { kind: 'grant', credits: 1 });
    assert.deepEqual(decideWebhook(order({ credits: 5, amount_som: 450 }), ev('paid', 450, 'kgs')), { kind: 'grant', credits: 5 });
    assert.deepEqual(decideWebhook(order({ status: 'paid', granted: true }), ev('paid')), { kind: 'noop', why: 'already_granted' });
    // money taken after the order expired (or after a failed attempt) is still credited
    assert.equal(decideWebhook(order({ status: 'expired' }), ev('paid')).kind, 'grant');
    assert.equal(decideWebhook(order({ status: 'failed' }), ev('paid')).kind, 'grant');
    assert.deepEqual(decideWebhook(order({ status: 'refunded' }), ev('paid')), { kind: 'noop', why: 'refunded' });
  });

  it('a different amount or currency never grants', () => {
    assert.deepEqual(decideWebhook(order(), ev('paid', 50)), {
      kind: 'amount_mismatch',
      expected: { amount_som: 100, currency: 'KGS' },
      got: { amount_som: 50, currency: 'KGS' },
    });
    assert.equal(decideWebhook(order(), ev('paid', 100, 'USD')).kind, 'amount_mismatch');
  });

  it('failed closes an ungranted order only', () => {
    assert.deepEqual(decideWebhook(order(), ev('failed')), { kind: 'fail' });
    assert.equal(decideWebhook(order({ status: 'created' }), ev('failed')).kind, 'fail');
    assert.deepEqual(decideWebhook(order({ status: 'paid', granted: true }), ev('failed')), { kind: 'noop', why: 'already_granted' });
    assert.deepEqual(decideWebhook(order({ status: 'failed' }), ev('failed')), { kind: 'noop', why: 'failed' });
  });

  it('refunded claws back a granted order; an ungranted one just closes; twice is a no-op', () => {
    assert.deepEqual(decideWebhook(order({ status: 'paid', granted: true, credits: 5 }), ev('refunded')), { kind: 'refund', credits: 5 });
    assert.deepEqual(decideWebhook(order(), ev('refunded')), { kind: 'refund_ungranted' });
    assert.deepEqual(decideWebhook(order({ status: 'refunded', granted: true }), ev('refunded')), { kind: 'noop', why: 'refunded' });
  });
});
