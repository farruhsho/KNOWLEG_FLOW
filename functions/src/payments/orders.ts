/**
 * Web payment rules (ARCHITECTURE §10.3), pure and unit-tested:
 * config/pricing.web_products, return-URL origins, the daily order limit,
 * order expiry and what a verified webhook event does to an order.
 *
 * Base price (owner decision): 1 credit = 1 full mock exam = 100 som —
 * `exam_single` stays {credits: 1, amount_som: 100} unless the super_admin
 * explicitly confirms a base price change.
 */
import { DomainError, Reasons } from '../domain/reasons';
import { isRecord } from '../domain/types';
import type { OrderStatus, WebhookEvent } from './types';

export interface WebProduct {
  credits: number;
  amount_som: number;
  enabled: boolean;
}

export const BASE_PRODUCT_ID = 'exam_single';
export const BASE_PRICE_SOM = 100;
export const ORDER_CURRENCY = 'KGS' as const;
/** paymentCreateOrder calls per user and Bishkek day. */
export const MAX_ORDERS_PER_DAY = 10;
/** created / pending orders older than this become `expired` (paymentExpireOrders). */
export const ORDER_TTL_MS = 24 * 60 * 60 * 1000;
export const WEB_CREDITS_MIN = 1;
export const WEB_CREDITS_MAX = 50;
export const WEB_AMOUNT_MIN = 1;
export const WEB_AMOUNT_MAX = 100_000;

/** Packs stay disabled until the owner approves their prices. */
export const DEFAULT_WEB_PRODUCTS: Readonly<Record<string, WebProduct>> = Object.freeze({
  exam_single: { credits: 1, amount_som: BASE_PRICE_SOM, enabled: true },
  exam_pack_5: { credits: 5, amount_som: 450, enabled: false },
  exam_pack_10: { credits: 10, amount_som: 800, enabled: false },
});

const PRODUCT_ID_RE = /^[a-z0-9_.]{1,64}$/;

export function isWebProductId(v: unknown): v is string {
  return typeof v === 'string' && PRODUCT_ID_RE.test(v);
}

function validProduct(v: unknown): WebProduct | null {
  if (!isRecord(v)) return null;
  const { credits, amount_som: amount, enabled } = v as Record<string, unknown>;
  if (typeof credits !== 'number' || !Number.isInteger(credits) || credits < WEB_CREDITS_MIN || credits > WEB_CREDITS_MAX) return null;
  if (typeof amount !== 'number' || !Number.isInteger(amount) || amount < WEB_AMOUNT_MIN || amount > WEB_AMOUNT_MAX) return null;
  if (typeof enabled !== 'boolean') return null;
  return { credits, amount_som: amount, enabled };
}

/** Stored config/pricing.web_products -> products (invalid entries dropped; missing map = defaults). */
export function parseWebProducts(raw: unknown): Record<string, WebProduct> {
  if (!isRecord(raw)) return structuredClone({ ...DEFAULT_WEB_PRODUCTS });
  const out: Record<string, WebProduct> = {};
  for (const [id, v] of Object.entries(raw)) {
    const p = validProduct(v);
    if (isWebProductId(id) && p) out[id] = p;
  }
  return out;
}

/** The product a user may buy now, or PRODUCT_UNAVAILABLE. */
export function requireWebProduct(products: Record<string, WebProduct>, productId: unknown): { id: string; product: WebProduct } {
  if (!isWebProductId(productId)) throw new DomainError(Reasons.PRODUCT_UNAVAILABLE, 'unknown product');
  const product = Object.prototype.hasOwnProperty.call(products, productId) ? products[productId] : undefined;
  if (!product || !product.enabled) throw new DomainError(Reasons.PRODUCT_UNAVAILABLE, 'product is not available', { productId });
  return { id: productId, product };
}

/**
 * adminUpdatePricing `webProducts` (`{id: {credits, amountSom|amount_som, enabled}}`):
 * credits 1..50, amount 1..100000 som, enabled boolean; `exam_single` is
 * required and stays {credits: 1, amount_som: 100} unless
 * `confirmBasePriceChange === true`. VALIDATION_FAILED otherwise.
 */
export function parseWebProductsUpdate(raw: unknown, confirmBasePriceChange: unknown): Record<string, WebProduct> {
  if (!isRecord(raw) || Object.keys(raw).length === 0) {
    throw new DomainError(Reasons.VALIDATION_FAILED, 'webProducts must be a non-empty map', { field: 'webProducts' });
  }
  if (Object.keys(raw).length > 20) throw new DomainError(Reasons.VALIDATION_FAILED, 'too many web products', { field: 'webProducts' });
  const out: Record<string, WebProduct> = {};
  for (const [id, v] of Object.entries(raw)) {
    const r = isRecord(v) ? { ...v, amount_som: v['amount_som'] ?? v['amountSom'] } : v;
    const p = validProduct(r);
    if (!isWebProductId(id) || !p) {
      throw new DomainError(Reasons.VALIDATION_FAILED, `invalid web product ${id}: credits 1..50, amount_som 1..100000, enabled boolean`, {
        field: 'webProducts',
        productId: id,
      });
    }
    out[id] = p;
  }
  const base = out[BASE_PRODUCT_ID];
  if (!base) throw new DomainError(Reasons.VALIDATION_FAILED, `${BASE_PRODUCT_ID} is required`, { field: 'webProducts', why: 'base_product_missing' });
  if ((base.amount_som !== BASE_PRICE_SOM || base.credits !== 1) && confirmBasePriceChange !== true) {
    throw new DomainError(Reasons.VALIDATION_FAILED, `the base price (1 credit = ${BASE_PRICE_SOM} som) changes only with confirmBasePriceChange`, {
      field: 'webProducts',
      why: 'base_price_change_unconfirmed',
    });
  }
  return out;
}

/**
 * admin_logs details of an adminUpdatePricing call with `webProducts`.
 * Fields the call did not send are `null`, never `undefined` (Firestore
 * rejects undefined values and the log entry would be lost).
 */
export function webPricingLogDetails(
  before: Record<string, unknown> | null,
  after: { products: Record<string, number> | null; freeExamsPerUser: number | null; webProducts: Record<string, WebProduct> },
): Record<string, unknown> {
  const base = after.webProducts[BASE_PRODUCT_ID];
  return {
    before: before
      ? { products: before['products'] ?? null, free_exams_per_user: before['free_exams_per_user'] ?? null, web_products: before['web_products'] ?? null }
      : null,
    after: { products: after.products ?? null, free_exams_per_user: after.freeExamsPerUser ?? null, web_products: after.webProducts },
    base_price_changed: !base || base.amount_som !== BASE_PRICE_SOM || base.credits !== 1,
  };
}

/** PAYMENT_RETURN_ORIGINS (comma separated) -> normalized origins. */
export function parseReturnOrigins(raw: string): string[] {
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
    .map((s) => {
      try {
        return new URL(s).origin;
      } catch {
        return '';
      }
    })
    .filter((o) => o !== '' && o !== 'null');
}

/** returnUrl must be an http(s) URL on an allowed origin (no credentials). */
export function checkReturnUrl(raw: unknown, origins: readonly string[]): string {
  const invalid = () => new DomainError(Reasons.VALIDATION_FAILED, 'returnUrl is not allowed', { field: 'returnUrl' });
  if (typeof raw !== 'string' || raw.length > 500) throw invalid();
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw invalid();
  }
  if ((url.protocol !== 'https:' && url.protocol !== 'http:') || url.username || url.password) throw invalid();
  if (!origins.includes(url.origin)) throw invalid();
  return url.toString();
}

/** The return URL with `order={id}` (the client's /pay/return page polls paymentGetOrder). */
export function returnUrlFor(returnUrl: string, orderId: string): string {
  const url = new URL(returnUrl);
  url.searchParams.set('order', orderId);
  return url.toString();
}

export const paymentAttemptsId = (uid: string, day: string): string => `${uid}_${day}`;

/** Next value of the daily order counter, or RATE_LIMITED. */
export function nextOrderCount(current: number): number {
  if (current >= MAX_ORDERS_PER_DAY) {
    throw new DomainError(Reasons.RATE_LIMITED, 'too many payment orders today', { what: 'payment_orders', limit: MAX_ORDERS_PER_DAY });
  }
  return current + 1;
}

export function isExpirable(status: string, createdAtMs: number | null, nowMs: number): boolean {
  return (status === 'created' || status === 'pending') && createdAtMs !== null && nowMs - createdAtMs > ORDER_TTL_MS;
}

/** The parts of a payment_orders document the webhook decision needs. */
export interface OrderState {
  status: OrderStatus | string;
  granted: boolean;
  amount_som: number;
  currency: string;
  credits: number;
}

export type WebhookDecision =
  | { kind: 'grant'; credits: number }
  | { kind: 'amount_mismatch'; expected: { amount_som: number; currency: string }; got: { amount_som: number; currency: string } }
  | { kind: 'fail' }
  | { kind: 'refund'; credits: number }
  | { kind: 'refund_ungranted' }
  | { kind: 'noop'; why: string };

/**
 * What a verified event does to an order:
 *  - paid with the order's exact amount and currency → grant (once:
 *    a granted order is never granted again; a refunded one never re-opens);
 *    any other amount/currency → amount_mismatch (order failed, no credits);
 *  - failed → the order fails unless it was already granted;
 *  - refunded → clawback of a granted order; an ungranted one just closes.
 */
export function decideWebhook(order: OrderState, event: Pick<WebhookEvent, 'status' | 'amountSom' | 'currency'>): WebhookDecision {
  switch (event.status) {
    case 'paid': {
      if (order.granted) return { kind: 'noop', why: 'already_granted' };
      if (order.status === 'refunded') return { kind: 'noop', why: 'refunded' };
      if (event.amountSom !== order.amount_som || event.currency.toUpperCase() !== order.currency.toUpperCase()) {
        return {
          kind: 'amount_mismatch',
          expected: { amount_som: order.amount_som, currency: order.currency },
          got: { amount_som: event.amountSom, currency: event.currency },
        };
      }
      return { kind: 'grant', credits: order.credits };
    }
    case 'failed':
      if (order.granted || order.status === 'paid') return { kind: 'noop', why: 'already_granted' };
      if (order.status === 'failed' || order.status === 'refunded') return { kind: 'noop', why: order.status };
      return { kind: 'fail' };
    case 'refunded':
      if (order.status === 'refunded') return { kind: 'noop', why: 'refunded' };
      if (order.granted) return { kind: 'refund', credits: order.credits };
      return { kind: 'refund_ungranted' };
  }
}

/**
 * A refund reservation older than this is stale (the function died during the
 * provider call, or the provider never answered): it may be taken again. The
 * provider call is idempotent by orderId, so a retry cannot refund twice.
 */
export const REFUND_RESERVATION_STALE_MS = 10 * 60 * 1000;

/** The parts of a payment_orders document an admin refund needs. */
export interface RefundableOrder {
  status: OrderStatus | string;
  granted: boolean;
  /** payment_orders.refund_requested is set (a refund is in flight or was asked of the provider). */
  refund_requested: boolean;
  /** refund_requested.at in ms; null when unknown (treated as fresh). */
  refund_requested_at_ms?: number | null;
  /** payment_orders.failure.code */
  failure_code?: string | null;
}

export type AdminRefundPlan =
  /** Provider refund, then the credits are clawed back (debt if spent). */
  | { kind: 'clawback' }
  /** Paid but never granted (paid after the account was deleted): provider refund only. */
  | { kind: 'provider_only' };

/**
 * adminRefundOrder: only a `paid` order without a refund in flight.
 * A second request while `refund_requested` is set is VALIDATION_FAILED
 * {why: 'refund_in_progress'}; any other status is VALIDATION_FAILED
 * {why: 'not_refundable', status}.
 */
export function planAdminRefund(order: RefundableOrder, nowMs = Date.now()): AdminRefundPlan {
  if (order.status !== 'paid') {
    throw new DomainError(Reasons.VALIDATION_FAILED, `order is ${order.status}`, { why: 'not_refundable', status: order.status }, 'failed-precondition');
  }
  if (order.refund_requested) {
    const at = order.refund_requested_at_ms;
    const stale = typeof at === 'number' && nowMs - at > REFUND_RESERVATION_STALE_MS;
    if (!stale) {
      throw new DomainError(Reasons.VALIDATION_FAILED, 'a refund of this order is already in progress', { why: 'refund_in_progress', status: order.status }, 'failed-precondition');
    }
  }
  if (order.granted) return { kind: 'clawback' };
  // Only the known case: paid after the account was deleted (no credits were given).
  if (order.failure_code === 'account_deleted') return { kind: 'provider_only' };
  throw new DomainError(Reasons.VALIDATION_FAILED, 'paid order without granted credits', { why: 'not_refundable', status: order.status }, 'failed-precondition');
}

/** payment_events document id: provider prefix + the provider's event id (hashed when not id-safe). */
export function paymentEventId(provider: string, eventId: string, hash: (s: string) => string): string {
  const safe = /^[A-Za-z0-9_-]{1,100}$/.test(eventId) ? eventId : hash(eventId).slice(0, 40);
  return `${provider}_${safe}`;
}
