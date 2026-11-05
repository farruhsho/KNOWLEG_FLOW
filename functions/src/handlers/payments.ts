/**
 * Web payments (ARCHITECTURE §10.3), provider-agnostic (src/payments/):
 *   paymentCreateOrder {productId, returnUrl} -> {orderId, checkoutUrl, amountSom, credits, expiresAt}
 *   paymentGetOrder {orderId}                 -> {status, credits, balance, ...}
 *   adminRefundOrder {orderId, reason}        -> {status, creditsClawedBack}   (super_admin)
 *   paymentWebhook        onRequest POST: provider notifications (signature over the raw body)
 *   paymentSandboxCheckout onRequest: emulator-only test checkout page (404 everywhere else)
 *   paymentExpireOrders   hourly: created/pending orders older than 24 h -> expired
 *
 * payment_orders/{orderId} = {uid, product_id, credits, amount_som, currency: 'KGS',
 *   provider, status: created|pending|paid|failed|expired|refunded, provider_ref,
 *   checkout_url, return_url, created_at, updated_at, expires_at, paid_at, granted,
 *   refund: null|{at, source: provider|admin, credits_clawed_back, ...}, failure?}
 * payment_events/{provider}_{eventId} = {provider, provider_event_id, order_id,
 *   status, amount_som, currency, result, received_at}  (no uid; idempotency)
 * payment_attempts/{uid}_{yyyy-mm-dd} = {uid, day, count}  (≤ 10 orders a day)
 *
 * A paid event with the order's exact amount and currency grants in ONE
 * transaction: order paid + granted, credits +N (debt first),
 * lifetime_credits_purchased +N, ledger {reason: 'purchase', ref: 'web_' + orderId}
 * and the referral reward — the same code as Google Play (credit_grants.ts).
 * A refund uses the same clawback (debt if spent, referral bonuses too).
 */
import '../config';
import type { DocumentReference, DocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { HttpsError, onCall, onRequest, type CallableRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FUNCTIONS_REGION, PAYMENT_PROVIDER, PAYMENT_PROVIDER_SECRET, PAYMENT_RETURN_ORIGINS } from '../config';
import { parseEntitlement } from '../domain/entitlements';
import { sha256Hex } from '../domain/hash';
import { DomainError, Reasons } from '../domain/reasons';
import { bishkekDayKey } from '../domain/time';
import { bool, int, num, str } from '../domain/types';
import {
  checkReturnUrl,
  decideWebhook,
  isExpirable,
  nextOrderCount,
  ORDER_CURRENCY,
  ORDER_TTL_MS,
  parseReturnOrigins,
  parseWebProducts,
  paymentAttemptsId,
  paymentEventId,
  requireWebProduct,
  returnUrlFor,
  type OrderState,
} from '../payments/orders';
import { adapterForOrder, projectIdOf, resolveAdapter, sandboxAllowed, type Resolution } from '../payments/registry';
import { buildSandboxWebhook, SANDBOX_SIGNATURE_HEADER } from '../payments/sandbox';
import { PaymentsDisabled, WebhookRejected, type CheckoutOrder, type HeaderBag, type WebhookEvent } from '../payments/types';
import {
  adminCallableOptions,
  callableOptions,
  db,
  FieldValue,
  mapLimit,
  payload,
  reqId,
  reqString,
  requireActiveUser,
  requireAuth,
  requirePermission,
  Timestamp,
  tsToMs,
  wrap,
  writeAdminLog,
} from './common';
import { liveOwner, readPaidClawback, readPaidGrant, writePaidClawback, writePaidGrant } from './credit_grants';

const ORDER_ID_RE = /^[A-Za-z0-9_-]{1,64}$/;

const orderRef = (id: string) => db().doc(`payment_orders/${id}`);

function activeAdapter(): Resolution {
  return resolveAdapter(PAYMENT_PROVIDER.value(), process.env);
}

function disabled(r: Resolution): DomainError {
  return new DomainError(Reasons.PAYMENTS_DISABLED, 'payments are not available', { why: r.why ?? 'none' });
}

function orderNotFound(): DomainError {
  return new DomainError(Reasons.ORDER_NOT_FOUND, 'order not found');
}

interface StoredOrder extends OrderState {
  id: string;
  uid: string;
  product_id: string;
  provider: string;
  provider_ref: string | null;
  return_url: string | null;
}

function parseOrder(snap: DocumentSnapshot): StoredOrder | null {
  if (!snap.exists) return null;
  const d = snap.data() ?? {};
  return {
    id: snap.id,
    uid: str(d['uid']),
    product_id: str(d['product_id']),
    provider: str(d['provider']),
    provider_ref: typeof d['provider_ref'] === 'string' ? d['provider_ref'] : null,
    return_url: typeof d['return_url'] === 'string' ? d['return_url'] : null,
    status: str(d['status'], 'created'),
    granted: bool(d['granted']),
    amount_som: num(d['amount_som']),
    currency: str(d['currency'], ORDER_CURRENCY),
    credits: int(d['credits']),
  };
}

function checkoutOrder(o: StoredOrder): CheckoutOrder {
  return { id: o.id, product_id: o.product_id, credits: o.credits, amount_som: o.amount_som, currency: ORDER_CURRENCY, provider_ref: o.provider_ref };
}

/** http(s)://host/project/region of the functions the caller reached (adapter-hosted pages; sandbox only). */
function functionsBaseUrl(req: CallableRequest<unknown>): string {
  const raw = req.rawRequest?.headers?.host;
  const host = typeof raw === 'string' && /^[A-Za-z0-9.-]{1,253}(:\d{1,5})?$/.test(raw) ? raw : '127.0.0.1:5001';
  const local = /^(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$/.test(host);
  return `${local ? 'http' : 'https'}://${host}/${projectIdOf(process.env)}/${FUNCTIONS_REGION}`;
}

// ---------------------------------------------------------------------------
// paymentCreateOrder {productId, returnUrl}

export const paymentCreateOrder = onCall(
  callableOptions({ secrets: [PAYMENT_PROVIDER_SECRET] }),
  wrap('paymentCreateOrder', async (req) => {
    // Deleted accounts and banned users cannot buy.
    const { uid } = await requireActiveUser(req);
    const resolution = activeAdapter();
    if (!resolution.enabled) throw disabled(resolution);
    const adapter = resolution.adapter;
    const data = payload(req);
    const returnUrl = checkReturnUrl(data['returnUrl'], parseReturnOrigins(PAYMENT_RETURN_ORIGINS.value()));
    const pricing = await db().doc('config/pricing').get();
    const { id: productId, product } = requireWebProduct(parseWebProducts(pricing.get('web_products')), data['productId']);

    const nowMs = Date.now();
    const day = bishkekDayKey(nowMs);
    const ref = db().collection('payment_orders').doc();
    const attemptsRef = db().doc(`payment_attempts/${paymentAttemptsId(uid, day)}`);
    const expiresAt = nowMs + ORDER_TTL_MS;
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(attemptsRef);
      const count = nextOrderCount(int(snap.get('count')));
      tx.set(attemptsRef, { uid, day, count, updated_at: FieldValue.serverTimestamp() }, { merge: true });
      tx.set(ref, {
        uid,
        product_id: productId,
        credits: product.credits,
        amount_som: product.amount_som,
        currency: ORDER_CURRENCY,
        provider: adapter.name,
        status: 'created',
        provider_ref: null,
        checkout_url: null,
        return_url: returnUrl,
        granted: false,
        paid_at: null,
        refund: null,
        created_at: Timestamp.fromMillis(nowMs),
        expires_at: Timestamp.fromMillis(expiresAt),
        updated_at: FieldValue.serverTimestamp(),
      });
    });

    const order: CheckoutOrder = { id: ref.id, product_id: productId, credits: product.credits, amount_som: product.amount_som, currency: ORDER_CURRENCY, provider_ref: null };
    let checkout;
    try {
      checkout = await adapter.createCheckout(order, returnUrlFor(returnUrl, ref.id), { functionsBaseUrl: functionsBaseUrl(req) });
    } catch (e) {
      await ref.set({ status: 'failed', failure: { code: 'checkout_failed', at: FieldValue.serverTimestamp() }, updated_at: FieldValue.serverTimestamp() }, { merge: true });
      if (e instanceof PaymentsDisabled) throw disabled({ adapter, enabled: false, why: 'none' });
      logger.error('payment checkout failed', { orderId: ref.id, provider: adapter.name, error: String(e) });
      throw new HttpsError('unavailable', 'The payment provider is unavailable, please retry.');
    }
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      // A webhook may already have moved the order on: never step it back.
      if (snap.get('status') !== 'created') return;
      tx.set(
        ref,
        { status: 'pending', provider_ref: checkout.providerRef, checkout_url: checkout.checkoutUrl, updated_at: FieldValue.serverTimestamp() },
        { merge: true },
      );
    });
    logger.info('payment order created', { uid, orderId: ref.id, productId, provider: adapter.name });
    return { orderId: ref.id, checkoutUrl: checkout.checkoutUrl, amountSom: product.amount_som, credits: product.credits, productId, currency: ORDER_CURRENCY, expiresAt };
  }),
);

// ---------------------------------------------------------------------------
// paymentGetOrder {orderId} -> {status, credits, balance}

export const paymentGetOrder = onCall(
  callableOptions(),
  wrap('paymentGetOrder', async (req) => {
    const uid = requireAuth(req);
    const orderId = payload(req)['orderId'];
    // Same answer for malformed, missing and foreign orders (ids cannot be probed).
    if (typeof orderId !== 'string' || !ORDER_ID_RE.test(orderId)) throw orderNotFound();
    const [snap, entSnap] = await Promise.all([orderRef(orderId).get(), db().doc(`entitlements/${uid}`).get()]);
    const order = parseOrder(snap);
    if (!order || order.uid !== uid) throw orderNotFound();
    return {
      orderId,
      status: order.status,
      credits: order.credits,
      balance: parseEntitlement(entSnap.data()).credits,
      productId: order.product_id,
      amountSom: order.amount_som,
      currency: order.currency,
      granted: order.granted,
      paidAt: tsToMs(snap.get('paid_at')),
      expiresAt: tsToMs(snap.get('expires_at')),
    };
  }),
);

// ---------------------------------------------------------------------------
// Refund clawback of a granted order (webhook `refunded` and adminRefundOrder)

/**
 * Inside a transaction, BEFORE any other write: claws back a granted order
 * (debt if spent, referral bonuses too) and marks it refunded.
 */
async function refundOrderInTx(
  tx: Transaction,
  snap: DocumentSnapshot,
  order: StoredOrder,
  source: 'provider' | 'admin',
  actorUid: string,
): Promise<{ clawedBack: number; newDebt: number }> {
  const reads = await readPaidClawback(tx, snap, liveOwner(order.uid, order.granted), order.granted);
  const out = writePaidClawback(tx, reads, order.credits, {
    ref: `web_${order.id}`,
    actorUid,
    source,
    extra: { product_id: order.product_id, order_id: order.id },
  });
  tx.set(
    snap.ref,
    {
      status: 'refunded',
      refund: {
        at: FieldValue.serverTimestamp(),
        source,
        credits_clawed_back: out.clawedBack,
        debt_added: out.newDebt,
        ...(out.referralClawedBack ? { referral_clawed_back: out.referralClawedBack } : {}),
      },
      updated_at: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { clawedBack: out.clawedBack, newDebt: out.newDebt };
}

// ---------------------------------------------------------------------------
// Webhook processing (shared by paymentWebhook and the sandbox checkout page)

export interface WebhookOutcome {
  httpStatus: number;
  body: Record<string, unknown>;
}

async function findOrderRef(provider: string, event: WebhookEvent): Promise<DocumentReference | null> {
  if (event.orderId && ORDER_ID_RE.test(event.orderId)) return orderRef(event.orderId);
  if (event.providerRef) {
    const q = await db().collection('payment_orders').where('provider', '==', provider).where('provider_ref', '==', event.providerRef).limit(1).get();
    return q.docs[0]?.ref ?? null;
  }
  return null;
}

/** Applies one verified event exactly once (payment_events/{provider}_{eventId}). */
export async function processPaymentEvent(provider: string, event: WebhookEvent): Promise<string> {
  const ref = await findOrderRef(provider, event);
  const eventRef = db().doc(`payment_events/${paymentEventId(provider, event.eventId, sha256Hex)}`);
  const nowMs = Date.now();
  const outcome = await db().runTransaction(async (tx) => {
    const [evSnap, orderSnap] = await tx.getAll(eventRef, ...(ref ? [ref] : []));
    if (evSnap!.exists) return { result: 'duplicate' } as const;
    const record = (result: string) =>
      tx.set(eventRef, {
        provider,
        provider_event_id: event.eventId.slice(0, 200),
        order_id: ref?.id ?? null,
        status: event.status,
        amount_som: event.amountSom,
        currency: event.currency,
        result,
        received_at: FieldValue.serverTimestamp(),
      });
    const order = orderSnap ? parseOrder(orderSnap) : null;
    if (!order || !orderSnap) {
      record('order_not_found');
      return { result: 'order_not_found' } as const;
    }
    if (order.provider !== provider || (event.providerRef && order.provider_ref && event.providerRef !== order.provider_ref)) {
      record('provider_mismatch');
      return { result: 'provider_mismatch', orderId: order.id } as const;
    }
    const decision = decideWebhook(order, event);
    switch (decision.kind) {
      case 'grant': {
        if (!liveOwner(order.uid, true)) {
          // Paid after the account was deleted: nothing to credit; ops refunds manually.
          tx.set(orderSnap.ref, { status: 'paid', granted: false, paid_at: Timestamp.fromMillis(nowMs), failure: { code: 'account_deleted' }, updated_at: FieldValue.serverTimestamp() }, { merge: true });
          record('paid_account_deleted');
          return { result: 'paid_account_deleted', orderId: order.id, mismatch: null } as const;
        }
        const reads = await readPaidGrant(tx, order.uid, { isTest: event.test === true, nowMs });
        const grant = writePaidGrant(tx, reads, decision.credits, {
          ref: `web_${order.id}`,
          actorUid: order.uid,
          extra: { product_id: order.product_id, order_id: order.id, provider },
        });
        tx.set(
          orderSnap.ref,
          {
            status: 'paid',
            granted: true,
            paid_at: Timestamp.fromMillis(nowMs),
            credits_net: grant.applied.netCredits,
            debt_settled: grant.applied.debtSettled,
            is_test: event.test === true,
            failure: FieldValue.delete(),
            ...grant.recordFields,
            updated_at: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        record('granted');
        return { result: 'granted', orderId: order.id, uid: order.uid, referral: grant.referralRewarded } as const;
      }
      case 'amount_mismatch':
        tx.set(
          orderSnap.ref,
          { status: 'failed', failure: { code: 'amount_mismatch', expected: decision.expected, got: decision.got }, updated_at: FieldValue.serverTimestamp() },
          { merge: true },
        );
        record('amount_mismatch');
        return { result: 'amount_mismatch', orderId: order.id, mismatch: { expected: decision.expected, got: decision.got } } as const;
      case 'fail':
        tx.set(orderSnap.ref, { status: 'failed', failure: { code: 'provider_failed' }, updated_at: FieldValue.serverTimestamp() }, { merge: true });
        record('failed');
        return { result: 'failed', orderId: order.id } as const;
      case 'refund': {
        await refundOrderInTx(tx, orderSnap, order, 'provider', 'system');
        record('refunded');
        return { result: 'refunded', orderId: order.id } as const;
      }
      case 'refund_ungranted':
        tx.set(
          orderSnap.ref,
          { status: 'refunded', refund: { at: FieldValue.serverTimestamp(), source: 'provider', credits_clawed_back: 0 }, updated_at: FieldValue.serverTimestamp() },
          { merge: true },
        );
        record('refunded_ungranted');
        return { result: 'refunded_ungranted', orderId: order.id } as const;
      case 'noop':
        record(`noop_${decision.why}`);
        return { result: `noop_${decision.why}`, orderId: order.id } as const;
    }
  });
  if (outcome.result === 'amount_mismatch' && 'mismatch' in outcome && outcome.mismatch) {
    logger.warn('payment amount mismatch', { orderId: outcome.orderId, provider });
    await writeAdminLog({ uid: 'system', role: 'system' }, 'payment_amount_mismatch', { orderId: outcome.orderId }, { provider, ...outcome.mismatch });
  } else if (outcome.result === 'order_not_found' || outcome.result === 'provider_mismatch' || outcome.result === 'paid_account_deleted') {
    logger.warn('payment event not applied', { provider, result: outcome.result, orderId: 'orderId' in outcome ? outcome.orderId : null });
  } else {
    logger.info('payment event', { provider, status: event.status, result: outcome.result, orderId: 'orderId' in outcome ? outcome.orderId : null });
  }
  return outcome.result;
}

/** Verifies (raw body signature) and applies a provider notification. */
export async function handlePaymentWebhook(rawBody: Buffer, headers: HeaderBag): Promise<WebhookOutcome> {
  const resolution = activeAdapter();
  if (!resolution.enabled) return { httpStatus: 404, body: { error: 'payments are disabled' } };
  let event: WebhookEvent;
  try {
    event = resolution.adapter.parseWebhook(rawBody, headers);
  } catch (e) {
    if (e instanceof WebhookRejected) {
      logger.warn('payment webhook rejected', { provider: resolution.adapter.name, why: e.message });
      return { httpStatus: 401, body: { error: 'rejected' } };
    }
    throw e;
  }
  const result = await processPaymentEvent(resolution.adapter.name, event);
  return { httpStatus: 200, body: { ok: true, result } };
}

export const paymentWebhook = onRequest({ secrets: [PAYMENT_PROVIDER_SECRET], timeoutSeconds: 60, memory: '256MiB' }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'POST only' });
    return;
  }
  try {
    const out = await handlePaymentWebhook(req.rawBody ?? Buffer.alloc(0), req.headers);
    res.status(out.httpStatus).json(out.body);
  } catch (e) {
    // 5xx: the provider retries; the event id keeps the retry idempotent.
    logger.error('payment webhook failed', { error: e instanceof Error ? e.message : String(e) });
    res.status(500).json({ error: 'internal' });
  }
});

// ---------------------------------------------------------------------------
// adminRefundOrder {orderId, reason} -> {status, creditsClawedBack}

export const adminRefundOrder = onCall(
  adminCallableOptions({ secrets: [PAYMENT_PROVIDER_SECRET] }),
  wrap('adminRefundOrder', async (req) => {
    const actor = await requirePermission(req, 'refund');
    const data = payload(req);
    const orderId = reqId(data['orderId'], 'orderId');
    const reason = reqString(data['reason'], 'reason', 3, 200);
    const order = parseOrder(await orderRef(orderId).get());
    if (!order) throw orderNotFound();
    if (order.status !== 'paid' || !order.granted) {
      throw new DomainError(Reasons.VALIDATION_FAILED, `order is ${order.status}`, { why: 'not_refundable', status: order.status }, 'failed-precondition');
    }
    const adapter = adapterForOrder(order.provider, process.env);
    if (!adapter) throw new DomainError(Reasons.PAYMENTS_DISABLED, 'the provider of this order is not configured', { why: 'provider_unavailable' });
    const r = await adapter.refund(checkoutOrder(order));
    let clawedBack = 0;
    let status: 'refunded' | 'pending' = 'pending';
    if (r.status === 'refunded') {
      const out = await db().runTransaction(async (tx) => {
        const snap = await tx.get(orderRef(orderId));
        const current = parseOrder(snap);
        if (!current || current.status === 'refunded' || !current.granted) return null; // a webhook was faster
        return refundOrderInTx(tx, snap, current, 'admin', actor.uid);
      });
      clawedBack = out?.clawedBack ?? 0;
      status = 'refunded';
    } else {
      // The provider confirms asynchronously: the `refunded` webhook claws back.
      await orderRef(orderId).set({ refund_requested: { at: FieldValue.serverTimestamp(), by: actor.uid, reason }, updated_at: FieldValue.serverTimestamp() }, { merge: true });
    }
    await writeAdminLog(actor, 'refund_order', { orderId }, { reason, provider: order.provider, status, credits_clawed_back: clawedBack, uid: order.uid });
    return { status, creditsClawedBack: clawedBack };
  }),
);

// ---------------------------------------------------------------------------
// paymentExpireOrders: hourly, created/pending orders older than 24 h -> expired

export const paymentExpireOrders = onSchedule(
  { schedule: 'every 60 minutes', timeZone: 'Asia/Bishkek', timeoutSeconds: 300, retryCount: 0 },
  async () => {
    const nowMs = Date.now();
    const cutoff = Timestamp.fromMillis(nowMs - ORDER_TTL_MS);
    let expired = 0;
    for (const status of ['created', 'pending']) {
      for (let page = 0; page < 5; page++) {
        const snap = await db().collection('payment_orders').where('status', '==', status).where('created_at', '<', cutoff).orderBy('created_at', 'asc').limit(200).get();
        if (snap.empty) break;
        const results = await mapLimit(snap.docs, 5, async (d) =>
          db().runTransaction(async (tx) => {
            const cur = await tx.get(d.ref);
            if (!isExpirable(str(cur.get('status')), tsToMs(cur.get('created_at')), Date.now())) return false;
            tx.set(d.ref, { status: 'expired', expired_at: FieldValue.serverTimestamp(), updated_at: FieldValue.serverTimestamp() }, { merge: true });
            return true;
          }),
        );
        expired += results.filter(Boolean).length;
        if (snap.size < 200) break;
      }
    }
    logger.info('paymentExpireOrders done', { expired });
  },
);

// ---------------------------------------------------------------------------
// paymentSandboxCheckout: the sandbox provider's checkout page (emulator + demo-* only)

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

function page(title: string, body: string): string {
  return `<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex"><title>${escapeHtml(title)}</title>
<style>body{font-family:system-ui,sans-serif;max-width:28rem;margin:3rem auto;padding:0 1rem;color:#1b1b1f}.warn{background:#fff4e5;border:1px solid #f0b35b;border-radius:8px;padding:.75rem 1rem}dl{display:grid;grid-template-columns:auto 1fr;gap:.25rem 1rem}button{font-size:1rem;padding:.6rem 1.2rem;margin:.5rem .5rem 0 0;border-radius:8px;border:1px solid #888;cursor:pointer}button.pay{background:#1b5e20;color:#fff;border-color:#1b5e20}</style></head><body>${body}</body></html>`;
}

function first(v: unknown): string {
  if (Array.isArray(v)) return typeof v[0] === 'string' ? v[0] : '';
  return typeof v === 'string' ? v : '';
}

export const paymentSandboxCheckout = onRequest({ timeoutSeconds: 30, memory: '256MiB' }, async (req, res) => {
  // Inert outside the emulator: no fictitious payment can be made in a real project.
  if (!sandboxAllowed(process.env) || activeAdapter().adapter.name !== 'sandbox') {
    res.status(404).send('Not found');
    return;
  }
  res.set('Cache-Control', 'no-store');
  const form = req.method === 'POST' ? new URLSearchParams((req.rawBody ?? Buffer.alloc(0)).toString('utf8')) : null;
  const orderId = form ? (form.get('order') ?? '') : first(req.query['order']);
  const ret = form ? (form.get('return') ?? '') : first(req.query['return']);
  if (!ORDER_ID_RE.test(orderId)) {
    res.status(404).send(page('Заказ не найден', '<h1>Заказ не найден</h1>'));
    return;
  }
  const snap = await orderRef(orderId).get();
  const order = parseOrder(snap);
  if (!order || order.provider !== 'sandbox') {
    res.status(404).send(page('Заказ не найден', '<h1>Заказ не найден</h1>'));
    return;
  }
  const origins = parseReturnOrigins(PAYMENT_RETURN_ORIGINS.value());
  let target: string | null = null;
  try {
    target = returnUrlFor(checkReturnUrl(ret || order.return_url, origins), order.id);
  } catch {
    target = null;
  }

  if (req.method === 'POST') {
    const action = form?.get('action');
    if (action !== 'pay' && action !== 'cancel') {
      res.status(400).send(page('Ошибка', '<h1>Неизвестное действие</h1>'));
      return;
    }
    const signed = buildSandboxWebhook({ orderId: order.id, status: action === 'pay' ? 'paid' : 'failed', amountSom: order.amount_som, currency: order.currency });
    const out = await handlePaymentWebhook(Buffer.from(signed.body, 'utf8'), { [SANDBOX_SIGNATURE_HEADER]: signed.signature });
    if (target) {
      res.redirect(303, target);
      return;
    }
    res.status(200).send(page('Тестовая оплата', `<h1>Готово</h1><p>Результат: ${escapeHtml(String(out.body['result'] ?? out.httpStatus))}</p>`));
    return;
  }

  const payable = order.status === 'created' || order.status === 'pending' || order.status === 'expired';
  const fields = `<input type="hidden" name="order" value="${escapeHtml(order.id)}"><input type="hidden" name="return" value="${escapeHtml(ret)}">`;
  const body = `<h1>Тестовая оплата — только эмулятор</h1>
<p class="warn">Это страница тестового провайдера <b>sandbox</b>. Она работает только в Firebase Emulator (проект demo-*). Деньги не списываются.</p>
<dl><dt>Заказ</dt><dd>${escapeHtml(order.id)}</dd><dt>Товар</dt><dd>${escapeHtml(order.product_id)}</dd><dt>Кредиты</dt><dd>${order.credits}</dd><dt>Сумма</dt><dd>${order.amount_som} сом</dd><dt>Статус</dt><dd>${escapeHtml(order.status)}</dd></dl>
${
  payable
    ? `<form method="post">${fields}<button class="pay" name="action" value="pay" type="submit">Оплатить (тест)</button><button name="action" value="cancel" type="submit">Отменить</button></form>`
    : `<p>Заказ уже обработан.</p>${target ? `<p><a href="${escapeHtml(target)}">Вернуться в приложение</a></p>` : ''}`
}`;
  res.status(200).send(page('Тестовая оплата — только эмулятор', body));
});
