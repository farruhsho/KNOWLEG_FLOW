/**
 * ORT Master KG — Cloud Functions (2nd gen) entry point.
 * Contract: docs/modernization/ARCHITECTURE.md §3 (phase 3: §9, phase 4: §10).
 * `./config` runs setGlobalOptions({region: 'europe-west1', maxInstances: 20})
 * before any function is defined.
 */
import './config';

export { examStart, examGetState, examSubmitSection, examGetReview, examExpireStale } from './handlers/exam';
export { billingVerifyPurchase, billingRtdn, billingSweepVoided } from './handlers/billing';
export { aiTutor, adminAiDraftQuestions } from './handlers/ai';
export { recordActivity } from './handlers/activity';
export { accountDelete } from './handlers/account';
export { adminSetRole, adminGrantCredits, adminPublishVariant, adminUpdatePricing } from './handlers/admin';
export { onUserBanChanged } from './handlers/moderation';
export { sendStudyReminders } from './handlers/reminders';
export { referralGetCode, referralApply, friendAdd } from './handlers/referral';
export { promoRedeem, adminUpsertPromoCode } from './handlers/promo';
export { groupCreate, groupJoin, groupLeave, groupRemoveMember } from './handlers/groups';
export { adminSendNotification } from './handlers/notifications';
// Phase 4 (ARCHITECTURE §10): fresh variant per attempt, web payments.
export { adminUpdateExamPool, adminExamPoolHealth } from './handlers/fresh';
export {
  paymentCreateOrder,
  paymentGetOrder,
  adminRefundOrder,
  paymentWebhook,
  paymentExpireOrders,
  // Emulator-only test checkout page: answers 404 unless FUNCTIONS_EMULATOR and a demo-* project.
  paymentSandboxCheckout,
} from './handlers/payments';
