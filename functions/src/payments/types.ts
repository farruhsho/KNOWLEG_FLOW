/**
 * Provider-agnostic payment adapter (ARCHITECTURE §10.3). One adapter per
 * payment provider; the active one is chosen by the PAYMENT_PROVIDER param
 * (registry.ts). Adapters never touch Firestore: the handlers own orders,
 * idempotency and credit grants.
 */

export type OrderStatus = 'created' | 'pending' | 'paid' | 'failed' | 'expired' | 'refunded';
export const ORDER_STATUSES: readonly OrderStatus[] = ['created', 'pending', 'paid', 'failed', 'expired', 'refunded'];

/** What an adapter sees of a payment_orders document. */
export interface CheckoutOrder {
  id: string;
  product_id: string;
  credits: number;
  amount_som: number;
  currency: 'KGS';
  provider_ref: string | null;
}

export interface CheckoutResult {
  checkoutUrl: string;
  providerRef: string;
}

export type WebhookStatus = 'paid' | 'failed' | 'refunded';

/** A verified provider notification. */
export interface WebhookEvent {
  /** Provider event id (idempotency key, payment_events/{provider}_{id}). */
  eventId: string;
  /** Our order id when the provider echoes it, else null (then providerRef is used). */
  orderId: string | null;
  providerRef: string | null;
  status: WebhookStatus;
  amountSom: number;
  currency: string;
  /** Provider test-mode payment (no referral reward, like Play license testers). */
  test?: boolean;
}

export interface RefundResult {
  /** refunded = done now (claw back now); pending = wait for the `refunded` webhook. */
  status: 'refunded' | 'pending';
}

export type HeaderBag = Record<string, string | string[] | undefined>;

/** Thrown by parseWebhook when the signature (or the payload) is not valid. */
export class WebhookRejected extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'WebhookRejected';
  }
}

/** Thrown by an adapter that cannot take payments (PAYMENTS_DISABLED). */
export class PaymentsDisabled extends Error {
  constructor(message = 'payments are disabled') {
    super(message);
    this.name = 'PaymentsDisabled';
  }
}

export interface CheckoutContext {
  /** Base URL of the functions (http(s)://host/project/region) for adapter-hosted pages. */
  functionsBaseUrl: string;
}

export interface PaymentAdapter {
  /** Stored as payment_orders.provider; also the payment_events id prefix. */
  readonly name: string;
  createCheckout(order: CheckoutOrder, returnUrl: string, ctx: CheckoutContext): Promise<CheckoutResult>;
  /** Verifies the signature over the RAW body; throws WebhookRejected. */
  parseWebhook(rawBody: Buffer, headers: HeaderBag): WebhookEvent;
  refund(order: CheckoutOrder): Promise<RefundResult>;
}
