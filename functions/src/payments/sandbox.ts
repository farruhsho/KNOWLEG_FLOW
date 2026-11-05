/**
 * PAYMENT_PROVIDER=sandbox — EMULATOR ONLY (ARCHITECTURE §10.3). It exists
 * to exercise the whole web payment flow locally (order → checkout page →
 * signed webhook → credits), never to create payments: registry.ts loads it
 * only when FUNCTIONS_EMULATOR === 'true' AND the project id starts with
 * `demo-` (demo projects cannot reach real Firebase services).
 *
 * checkoutUrl -> the paymentSandboxCheckout HTTP function ("Тестовая оплата —
 * только эмулятор" with "Оплатить (тест)" / "Отменить"). Webhook bodies are
 * JSON `{event_id, order_id, status, amount_som, currency}` signed with
 * HMAC-SHA256 over the raw body using a fixed emulator-only secret, header
 * `x-sandbox-signature: sha256=<hex>`.
 */
import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { WebhookRejected, type CheckoutContext, type CheckoutOrder, type HeaderBag, type PaymentAdapter, type WebhookEvent, type WebhookStatus } from './types';

/** Fixed signing secret of the sandbox. Public on purpose: the sandbox never runs outside the emulator. */
export const SANDBOX_SECRET = 'ort-sandbox-emulator-only-secret';
export const SANDBOX_SIGNATURE_HEADER = 'x-sandbox-signature';

export function sandboxSignature(rawBody: Buffer | string, secret = SANDBOX_SECRET): string {
  return 'sha256=' + createHmac('sha256', secret).update(rawBody).digest('hex');
}

function header(headers: HeaderBag, name: string): string {
  const v = headers[name] ?? headers[name.toLowerCase()];
  return Array.isArray(v) ? (v[0] ?? '') : (v ?? '');
}

const STATUSES: readonly WebhookStatus[] = ['paid', 'failed', 'refunded'];
const EVENT_ID_RE = /^[A-Za-z0-9_-]{1,100}$/;

/** Verifies and parses a sandbox webhook; throws WebhookRejected. */
export function parseSandboxWebhook(rawBody: Buffer, headers: HeaderBag, secret = SANDBOX_SECRET): WebhookEvent {
  const got = Buffer.from(header(headers, SANDBOX_SIGNATURE_HEADER));
  const want = Buffer.from(sandboxSignature(rawBody, secret));
  if (got.length !== want.length || !timingSafeEqual(got, want)) throw new WebhookRejected('bad signature');
  let body: unknown;
  try {
    body = JSON.parse(rawBody.toString('utf8'));
  } catch {
    throw new WebhookRejected('body is not JSON');
  }
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw new WebhookRejected('body is not an object');
  const b = body as Record<string, unknown>;
  const eventId = b['event_id'];
  const orderId = b['order_id'];
  const status = b['status'];
  const amount = b['amount_som'];
  if (typeof eventId !== 'string' || !EVENT_ID_RE.test(eventId)) throw new WebhookRejected('event_id is invalid');
  if (typeof orderId !== 'string' || !EVENT_ID_RE.test(orderId)) throw new WebhookRejected('order_id is invalid');
  if (typeof status !== 'string' || !(STATUSES as readonly string[]).includes(status)) throw new WebhookRejected('status is invalid');
  if (typeof amount !== 'number' || !Number.isFinite(amount)) throw new WebhookRejected('amount_som is invalid');
  return {
    eventId,
    orderId,
    providerRef: `sbx_${orderId}`,
    status: status as WebhookStatus,
    amountSom: amount,
    currency: typeof b['currency'] === 'string' ? b['currency'] : '',
  };
}

/** A signed sandbox webhook body (used by the checkout page and by tests). */
export function buildSandboxWebhook(event: { orderId: string; status: WebhookStatus; amountSom: number; currency?: string; eventId?: string }): {
  body: string;
  signature: string;
} {
  const body = JSON.stringify({
    event_id: event.eventId ?? `sbx_evt_${randomBytes(8).toString('hex')}`,
    order_id: event.orderId,
    status: event.status,
    amount_som: event.amountSom,
    currency: event.currency ?? 'KGS',
  });
  return { body, signature: sandboxSignature(body) };
}

export const sandboxAdapter: PaymentAdapter = Object.freeze({
  name: 'sandbox',
  async createCheckout(order: CheckoutOrder, returnUrl: string, ctx: CheckoutContext) {
    const url = new URL(`${ctx.functionsBaseUrl}/paymentSandboxCheckout`);
    url.searchParams.set('order', order.id);
    url.searchParams.set('return', returnUrl);
    return { checkoutUrl: url.toString(), providerRef: `sbx_${order.id}` };
  },
  parseWebhook(rawBody: Buffer, headers: HeaderBag) {
    return parseSandboxWebhook(rawBody, headers);
  },
  async refund() {
    return { status: 'refunded' as const };
  },
});
