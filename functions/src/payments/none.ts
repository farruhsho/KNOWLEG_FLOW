/**
 * PAYMENT_PROVIDER=none (the default until the owner signs a provider
 * contract): nothing can be bought on the website. paymentCreateOrder
 * answers PAYMENTS_DISABLED; webhooks are rejected.
 */
import { PaymentsDisabled, WebhookRejected, type PaymentAdapter } from './types';

export const noneAdapter: PaymentAdapter = Object.freeze({
  name: 'none',
  async createCheckout(): Promise<never> {
    throw new PaymentsDisabled();
  },
  parseWebhook(): never {
    throw new WebhookRejected('payments are disabled');
  },
  async refund(): Promise<never> {
    throw new PaymentsDisabled();
  },
});
